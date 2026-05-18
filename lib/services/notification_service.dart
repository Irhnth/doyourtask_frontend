import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart'; 

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Inisialisasi Database Zona Waktu
    tz.initializeTimeZones();

    // 2. PERBAIKAN: Ambil zona waktu asli dari HP (Mendukung flutter_timezone versi terbaru)
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    final String timeZoneName = timeZoneInfo.identifier; // Mengambil IANA identifier seperti 'Asia/Jakarta'
    
    tz.setLocalLocation(tz.getLocation(timeZoneName)); // Set ke waktu lokal!

    // 3. Pengaturan Ikon Notifikasi
    const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: initSettingsAndroid);

    await _notificationsPlugin.initialize(initSettings);
    
    // 4. Minta izin Notifikasi dan Alarm Akurat
    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  // Fungsi untuk menjadwalkan notifikasi
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    // Cegah error jika waktu alarm sudah lewat (di masa lalu)
    if (scheduledTime.isBefore(DateTime.now())) return;

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      // Sekarang TZDateTime akan mematuhi zona waktu lokal (WIB/WITA/WIT), bukan London lagi
      tz.TZDateTime.from(scheduledTime, tz.local), 
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'quest_reminder_channel',
          'Quest Reminders',
          channelDescription: 'Pengingat untuk menyelesaikan quest harian',
          importance: Importance.max, // Penting agar muncul pop-up di atas layar
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
  // Fungsi untuk membatalkan alarm jika tugas dihapus atau diedit
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}