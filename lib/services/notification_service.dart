import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const List<int> _healthReminderIds = [
    2001,
    2002,
    2003,
    2004,
    2005,
    2006,
    2007,
    2008
  ];

  Future<void> init() async {
    // 1. Inisialisasi Database Zona Waktu
    tz.initializeTimeZones();

    // 2. Ambil zona waktu asli dari HP
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // Default jika gagal mengambil zona waktu
    }

    // 3. Pengaturan Ikon Notifikasi
    const AndroidInitializationSettings initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: initSettingsAndroid);

    await _notificationsPlugin.initialize(initSettings);

    // 4. Minta izin Notifikasi dan Alarm Akurat
    await requestPermissions();
  }

  Future<void> requestPermissions() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  // Fungsi untuk menjadwalkan notifikasi tugas/quest tunggal
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'quest_reminder_channel',
          'Quest Reminders',
          channelDescription: 'Pengingat untuk menyelesaikan quest harian',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Menjadwalkan pengingat kesehatan berkala (default: setiap 6 jam mulai jam 6 pagi)
  Future<void> scheduleHealthReminders({
    int intervalHours = 6,
    int startHour = 6,
  }) async {
    await cancelHealthReminders();

    if (intervalHours <= 0 || intervalHours > 24) {
      intervalHours = 6;
    }

    final int remindersPerDay = (24 / intervalHours).floor();
    final List<int> scheduledHours = [];
    int currentHour = startHour % 24;

    for (int i = 0; i < remindersPerDay; i++) {
      scheduledHours.add(currentHour);
      currentHour = (currentHour + intervalHours) % 24;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'health_reminder_channel',
      'Target Kesehatan',
      channelDescription:
          'Pengingat berkala untuk mencapai target kesehatan harian',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    for (int i = 0; i < scheduledHours.length; i++) {
      final hour = scheduledHours[i];
      final id = _healthReminderIds[i % _healthReminderIds.length];

      String title;
      String body;

      if (hour >= 5 && hour < 11) {
        title = '🌅 Target Kesehatan Pagi';
        body = 'Awali harimu dengan minum segelas air dan cek misi kesehatanmu!';
      } else if (hour >= 11 && hour < 15) {
        title = '☀️ Waktunya Hidrasi & Istirahat';
        body = 'Sudah siang! Yuk minum air putih, regangkan badan, dan update targetmu.';
      } else if (hour >= 15 && hour < 20) {
        title = '🌇 Tetap Bugar Sore Ini';
        body = 'Sore yang produktif! Lengkapi olahraga dan target kesehatan untuk dapat XP!';
      } else {
        title = '🌙 Rehat & Istirahat Cukup';
        body = 'Waktunya meregangkan tubuh dan tidur berkualitas untuk memulihkan energimu.';
      }

      final scheduledDate = _nextInstanceOfTime(hour, 0);

      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        // Fallback jika exact alarm tidak diizinkan di perangkat
        try {
          await _notificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        } catch (_) {}
      }
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // Batalkan seluruh alarm pengingat kesehatan
  Future<void> cancelHealthReminders() async {
    for (int id in _healthReminderIds) {
      try {
        await _notificationsPlugin.cancel(id);
      } catch (_) {}
    }
  }

  // Tampilkan notifikasi instan (untuk tes)
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'health_reminder_channel',
      'Target Kesehatan',
      channelDescription:
          'Pengingat berkala untuk mencapai target kesehatan harian',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      9999,
      title,
      body,
      notificationDetails,
    );
  }

  // Fungsi untuk membatalkan alarm tugas
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  // Fungsi untuk menjadwalkan pengingat harian Tantangan 28 Hari
  Future<void> scheduleChallengeReminder({
    required int currentDay,
    int hour = 9,
    int minute = 0,
  }) async {
    const int challengeReminderId = 3001;
    final scheduledDate = _nextInstanceOfTime(hour, minute);

    try {
      await _notificationsPlugin.zonedSchedule(
        challengeReminderId,
        '🔥 Tantangan 28 Hari: Hari ke-$currentDay!',
        'Misi harianmu telah siap! Tuntaskan sekarang dan pertahankan streak apimu.',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'challenge_reminder_channel',
            'Tantangan 28 Hari',
            channelDescription: 'Pengingat harian untuk misi tantangan 28 hari',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }
}