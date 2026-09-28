import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'pomodoro_screen.dart';

enum HealthFilter { all, ongoing, completed }

class _HealthCategoryTheme {
  final IconData icon;
  final Color primaryColor;
  final Color backgroundColor;
  final Color accentColor;

  const _HealthCategoryTheme({
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
    required this.accentColor,
  });
}

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  List<dynamic> _healthTargets = [];
  bool _isLoading = true;
  HealthFilter _currentFilter = HealthFilter.all;

  // --- SETTINGS PENGINGAT ---
  bool _isReminderEnabled = true;
  int _reminderInterval = 6;
  int _reminderStartHour = 6;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
    _loadReminderSettings();
  }

  // --- STATS COMPUTATIONS ---
  int get _completedCount =>
      _healthTargets.where((t) => t['is_completed'] == true).length;
  int get _totalCount => _healthTargets.length;
  double get _overallProgress =>
      _totalCount == 0 ? 0.0 : (_completedCount / _totalCount);

  List<dynamic> get _filteredTargets {
    switch (_currentFilter) {
      case HealthFilter.ongoing:
        return _healthTargets.where((t) => t['is_completed'] != true).toList();
      case HealthFilter.completed:
        return _healthTargets.where((t) => t['is_completed'] == true).toList();
      case HealthFilter.all:
        return _healthTargets;
    }
  }

  String _formatDate(DateTime date) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  String _getMotivationalMessage() {
    if (_totalCount == 0) {
      return 'Mulai harimu dengan kebiasaan sehat!';
    }
    if (_completedCount == _totalCount) {
      return 'Luar biasa! Semua target hari ini tuntas! 🏆';
    }
    if (_completedCount >= (_totalCount / 2)) {
      return 'Bagus sekali! Sudah setengah jalan, lanjutkan! 🔥';
    }
    if (_completedCount > 0) {
      return 'Langkah awal mantap! Terus raih targetmu! 💪';
    }
    return 'Yuk selesaikan target pertamamu hari ini! ✨';
  }

  // --- PEMUATAN PENGATURAN PENGINGAT ---
  Future<void> _loadReminderSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool? savedEnabled = prefs.getBool('health_reminders_enabled');
      final int savedInterval =
          prefs.getInt('health_reminder_interval') ?? 6;
      final int savedStartHour =
          prefs.getInt('health_reminder_start_hour') ?? 6;

      final bool isEnabled = savedEnabled ?? true;

      if (mounted) {
        setState(() {
          _isReminderEnabled = isEnabled;
          _reminderInterval = savedInterval;
          _reminderStartHour = savedStartHour;
        });
      }

      if (isEnabled) {
        await _notificationService.scheduleHealthReminders(
          intervalHours: savedInterval,
          startHour: savedStartHour,
        );
        if (savedEnabled == null) {
          await prefs.setBool('health_reminders_enabled', true);
          await prefs.setInt('health_reminder_interval', 6);
          await prefs.setInt('health_reminder_start_hour', 6);
        }
      }
    } catch (_) {}
  }

  List<int> _calculateScheduledHours(int interval, int startHour) {
    if (interval <= 0) interval = 6;
    final int count = (24 / interval).floor();
    final List<int> hours = [];
    int h = startHour % 24;
    for (int i = 0; i < count; i++) {
      hours.add(h);
      h = (h + interval) % 24;
    }
    return hours;
  }

  _HealthCategoryTheme _getCategoryTheme(String title, String? type) {
    final lowerTitle = title.toLowerCase();
    final lowerType = type?.toLowerCase() ?? '';

    if (lowerType == 'exercise' ||
        lowerTitle.contains('olahraga') ||
        lowerTitle.contains('lari') ||
        lowerTitle.contains('jalan') ||
        lowerTitle.contains('workout') ||
        lowerTitle.contains('gym') ||
        lowerTitle.contains('senam') ||
        lowerTitle.contains('push up')) {
      return const _HealthCategoryTheme(
        icon: Icons.fitness_center_rounded,
        primaryColor: Color(0xFFFF7A00),
        backgroundColor: Color(0xFFFFF3E0),
        accentColor: Color(0xFFFF9E00),
      );
    }

    if (lowerTitle.contains('minum') ||
        lowerTitle.contains('air') ||
        lowerTitle.contains('water') ||
        lowerTitle.contains('aqua') ||
        lowerTitle.contains('hidrasi')) {
      return const _HealthCategoryTheme(
        icon: Icons.water_drop_rounded,
        primaryColor: Color(0xFF0091EA),
        backgroundColor: Color(0xFFE1F5FE),
        accentColor: Color(0xFF00B4D8),
      );
    }

    if (lowerTitle.contains('tidur') ||
        lowerTitle.contains('istirahat') ||
        lowerTitle.contains('sleep') ||
        lowerTitle.contains('nap') ||
        lowerTitle.contains('lelap')) {
      return const _HealthCategoryTheme(
        icon: Icons.bedtime_rounded,
        primaryColor: Color(0xFF7C4DFF),
        backgroundColor: Color(0xFFEDE7F6),
        accentColor: Color(0xFF651FFF),
      );
    }

    if (lowerTitle.contains('makan') ||
        lowerTitle.contains('sayur') ||
        lowerTitle.contains('buah') ||
        lowerTitle.contains('diet') ||
        lowerTitle.contains('kalori') ||
        lowerTitle.contains('salad') ||
        lowerTitle.contains('nutrisi')) {
      return const _HealthCategoryTheme(
        icon: Icons.eco_rounded,
        primaryColor: Color(0xFF10B981),
        backgroundColor: Color(0xFFE8F5E9),
        accentColor: Color(0xFF059669),
      );
    }

    if (lowerTitle.contains('meditasi') ||
        lowerTitle.contains('nafas') ||
        lowerTitle.contains('santai') ||
        lowerTitle.contains('fokus') ||
        lowerTitle.contains('rehat')) {
      return const _HealthCategoryTheme(
        icon: Icons.self_improvement_rounded,
        primaryColor: Color(0xFF14B8A6),
        backgroundColor: Color(0xFFE0F2F1),
        accentColor: Color(0xFF0D9488),
      );
    }

    return const _HealthCategoryTheme(
      icon: Icons.favorite_rounded,
      primaryColor: Color(0xFF3366FF),
      backgroundColor: Color(0xFFEEF2FF),
      accentColor: Color(0xFF5B8DEF),
    );
  }

  // --- DIALOG PERINGATAN KETIKA TARGET SELESAI ---
  void _showTargetCompletedDialog({required String title, int? earnedXp}) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC94D).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 56,
                  color: Color(0xFFFFC94D),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'TARGET HARIAN SUDAH SELESAI!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF222B45),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                earnedXp != null && earnedXp > 0
                    ? 'Keren! Kamu berhasil menyelesaikan target "$title" dan mendapatkan +$earnedXp XP!'
                    : 'Keren! Kamu telah berhasil menyelesaikan target "$title" hari ini.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8F9BB3),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3366FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Lanjut Berpetualang',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadHealthData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final healthData = await _apiService.getTodayHealthProgress();
      if (mounted) {
        setState(() {
          _healthTargets = healthData;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _incrementProgress(Map<String, dynamic> target) async {
    final int targetId = target['target_id'] ?? target['id'];
    final int currentValue = target['current_value'] ?? 0;
    final int targetValue = target['target_value'] ?? 1;
    final String title = target['title'] ?? 'Kesehatan';

    // Cek apakah dengan penambahan ini target akan selesai
    final bool willComplete = (currentValue + 1) >= targetValue;

    try {
      final result = await _apiService.updateHealthProgress(targetId, 1);

      final int earnedXp = result['earned_xp'] ?? 0;
      final bool isCompletedByApi = result['is_completed'] == true ||
          (result['target'] != null &&
              result['target']['is_completed'] == true) ||
          earnedXp > 0;

      // HANYA munculkan notifikasi/dialog jika target SUDAH terselesaikan!
      if (willComplete || isCompletedByApi) {
        if (mounted) {
          _showTargetCompletedDialog(
            title: title,
            earnedXp: earnedXp > 0 ? earnedXp : null,
          );
        }
      }

      _loadHealthData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // --- MODAL PENGATURAN PENGINGAT (NOTIFIKASI) ---
  void _showReminderSettingsModal() {
    bool tempEnabled = _isReminderEnabled;
    int tempInterval = _reminderInterval;
    int tempStartHour = _reminderStartHour;

    final intervalOptions = [
      {'label': 'Tiap 4 Jam', 'value': 4},
      {'label': 'Tiap 6 Jam (Default)', 'value': 6},
      {'label': 'Tiap 8 Jam', 'value': 8},
      {'label': 'Tiap 12 Jam', 'value': 12},
    ];

    final startHourOptions = [
      {'label': '06:00 Pagi (Default)', 'value': 6},
      {'label': '07:00 Pagi', 'value': 7},
      {'label': '08:00 Pagi', 'value': 8},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final scheduledHours =
                _calculateScheduledHours(tempInterval, tempStartHour);

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4E9F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.alarm_rounded,
                            color: Color(0xFF3366FF),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pengingat Target Sehat',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF222B45),
                                ),
                              ),
                              Text(
                                'Notifikasi berkala otomatis setiap hari',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8F9BB3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Switch Aktifkan Pengingat
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEDF1F7)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                tempEnabled
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_off_rounded,
                                color: tempEnabled
                                    ? const Color(0xFF3366FF)
                                    : const Color(0xFF8F9BB3),
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Aktifkan Pengingat',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF222B45),
                                    ),
                                  ),
                                  Text(
                                    tempEnabled
                                        ? 'Pengingat aktif berjalan'
                                        : 'Pengingat dimatikan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: tempEnabled
                                          ? const Color(0xFF00B377)
                                          : const Color(0xFF8F9BB3),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: tempEnabled,
                            activeThumbColor: const Color(0xFF3366FF),
                            activeTrackColor:
                                const Color(0xFF3366FF).withValues(alpha: 0.3),
                            onChanged: (val) {
                              setModalState(() {
                                tempEnabled = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    if (tempEnabled) ...[
                      const SizedBox(height: 20),

                      // Pilihan Interval
                      const Text(
                        'Frekuensi Pengingat',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF222B45),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: intervalOptions.map((opt) {
                          final isSelected = tempInterval == opt['value'];
                          return ChoiceChip(
                            label: Text(opt['label'] as String),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() {
                                  tempInterval = opt['value'] as int;
                                });
                              }
                            },
                            selectedColor:
                                const Color(0xFF3366FF).withValues(alpha: 0.12),
                            backgroundColor: const Color(0xFFF5F7FA),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF3366FF)
                                  : const Color(0xFF8F9BB3),
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF3366FF)
                                  : const Color(0xFFE4E9F2),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 18),

                      // Pilihan Jam Mulai
                      const Text(
                        'Dimulai Pukul',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF222B45),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: startHourOptions.map((opt) {
                          final isSelected = tempStartHour == opt['value'];
                          return ChoiceChip(
                            label: Text(opt['label'] as String),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() {
                                  tempStartHour = opt['value'] as int;
                                });
                              }
                            },
                            selectedColor:
                                const Color(0xFF3366FF).withValues(alpha: 0.12),
                            backgroundColor: const Color(0xFFF5F7FA),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF3366FF)
                                  : const Color(0xFF8F9BB3),
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF3366FF)
                                  : const Color(0xFFE4E9F2),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // Pratinjau Jadwal Harian
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF3366FF).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.schedule_rounded,
                                    size: 16, color: Color(0xFF3366FF)),
                                SizedBox(width: 6),
                                Text(
                                  'Jadwal Alarm Harian Kamu',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF222B45),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: scheduledHours.map((h) {
                                String timeString =
                                    '${h.toString().padLeft(2, '0')}:00';
                                String icon = '☀️';
                                if (h >= 5 && h < 11) icon = '🌅';
                                if (h >= 11 && h < 15) icon = '☀️';
                                if (h >= 15 && h < 20) icon = '🌇';
                                if (h >= 20 || h < 5) icon = '🌙';

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '$icon $timeString',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF222B45),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tombol Tes Notifikasi
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _notificationService.showInstantNotification(
                              title: '🔔 Uji Pengingat Target Sehat',
                              body:
                                  'Pengingat aktif! Target kesehatanmu siap dikerjakan untuk dapatkan XP.',
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                            'Notifikasi pengujian dikirim! Periksa bar status HP Anda.'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF1E293B),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('Uji Notifikasi Sekarang'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3366FF),
                            side: const BorderSide(color: Color(0xFF3366FF)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Tombol Simpan Pengaturan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3366FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final nav = Navigator.of(bottomSheetContext);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);

                          try {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(
                                'health_reminders_enabled', tempEnabled);
                            await prefs.setInt(
                                'health_reminder_interval', tempInterval);
                            await prefs.setInt(
                                'health_reminder_start_hour', tempStartHour);

                            if (tempEnabled) {
                              await _notificationService.scheduleHealthReminders(
                                intervalHours: tempInterval,
                                startHour: tempStartHour,
                              );
                            } else {
                              await _notificationService
                                  .cancelHealthReminders();
                            }

                            if (mounted) {
                              setState(() {
                                _isReminderEnabled = tempEnabled;
                                _reminderInterval = tempInterval;
                                _reminderStartHour = tempStartHour;
                              });
                            }

                            nav.pop();
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(tempEnabled
                                    ? 'Pengingat kesehatan dijadwalkan setiap $tempInterval jam (Mulai ${tempStartHour.toString().padLeft(2, '0')}:00)!'
                                    : 'Pengingat kesehatan berhasil dinonaktifkan.'),
                                backgroundColor: const Color(0xFF1E293B),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          } catch (e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text('Gagal menyimpan: $e')),
                            );
                          }
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Simpan Pengaturan',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAL UNTUK EDIT TARGET ---
  void _showEditTargetModal(Map<String, dynamic> target) {
    final titleController = TextEditingController(text: target['title']);
    final valueController =
        TextEditingController(text: target['target_value'].toString());
    final unitController = TextEditingController(text: target['unit'] ?? '');
    final quickUnits = ['Gelas', 'Menit', 'Langkah', 'Jam', 'Porsi', 'Kali'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (modalStateContext, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(modalStateContext).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E9F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit_note_rounded,
                          color: Color(0xFF3366FF),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sesuaikan Target',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF222B45),
                            ),
                          ),
                          Text(
                            'Atur target sesuai rutinitas harianmu',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8F9BB3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Nama Target',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222B45),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Minum Air Putih',
                      prefixIcon: const Icon(Icons.title_rounded,
                          color: Color(0xFF8F9BB3), size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: Color(0xFF3366FF), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Jumlah',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF222B45),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: valueController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '0',
                                prefixIcon: const Icon(Icons.pin_outlined,
                                    color: Color(0xFF8F9BB3), size: 18),
                                filled: true,
                                fillColor: const Color(0xFFF5F7FA),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF3366FF), width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Satuan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF222B45),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: unitController,
                              decoration: InputDecoration(
                                hintText: 'Gelas, Menit, dll',
                                prefixIcon: const Icon(
                                    Icons.straighten_rounded,
                                    color: Color(0xFF8F9BB3),
                                    size: 18),
                                filled: true,
                                fillColor: const Color(0xFFF5F7FA),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF3366FF), width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: quickUnits.map((u) {
                      final isSelected =
                          unitController.text.trim().toLowerCase() ==
                              u.toLowerCase();
                      return ChoiceChip(
                        label: Text(u),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            unitController.text = selected ? u : '';
                          });
                        },
                        selectedColor:
                            const Color(0xFF3366FF).withValues(alpha: 0.12),
                        backgroundColor: const Color(0xFFF5F7FA),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF3366FF)
                              : const Color(0xFF8F9BB3),
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF3366FF)
                              : const Color(0xFFE4E9F2),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3366FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty ||
                            valueController.text.trim().isEmpty) {
                          return;
                        }

                        final nav = Navigator.of(bottomSheetContext);
                        final scaffoldMessenger =
                            ScaffoldMessenger.of(context);

                        try {
                          int targetId = target['target_id'] ?? target['id'];
                          await _apiService.editHealthTarget(
                            targetId,
                            titleController.text.trim(),
                            int.parse(valueController.text.trim()),
                            unitController.text.trim(),
                          );

                          nav.pop();
                          _loadHealthData();
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Simpan Perubahan',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF222B45),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          children: [
            Text(
              'Target Kesehatan',
              style: TextStyle(
                color: Color(0xFF222B45),
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              'Jaga kebugaran & kumpulkan XP',
              style: TextStyle(
                color: Color(0xFF8F9BB3),
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          // TOMBOL PENGATURAN PENGINGAT (NOTIFIKASI)
          IconButton(
            icon: Icon(
              _isReminderEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_outlined,
              color: _isReminderEnabled
                  ? const Color(0xFF3366FF)
                  : const Color(0xFF8F9BB3),
              size: 22,
            ),
            tooltip: 'Pengaturan Pengingat',
            onPressed: _showReminderSettingsModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Color(0xFF222B45), size: 22),
            tooltip: 'Segarkan',
            onPressed: _loadHealthData,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF3366FF)))
            : RefreshIndicator(
                onRefresh: _loadHealthData,
                color: const Color(0xFF3366FF),
                child: _healthTargets.isEmpty
                    ? _buildEmptyState()
                    : _buildContentScrollView(),
              ),
      ),
    );
  }

  Widget _buildContentScrollView() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // 1. HERO PROGRESS CARD
        SliverToBoxAdapter(
          child: _buildHeroBanner(),
        ),

        // 2. FILTER TABS
        SliverToBoxAdapter(
          child: _buildFilterChips(),
        ),

        // 3. SECTION HEADER
        SliverToBoxAdapter(
          child: _buildSectionHeader(),
        ),

        // 4. GRID OR FILTER EMPTY STATE
        if (_filteredTargets.isEmpty)
          SliverToBoxAdapter(
            child: _buildEmptyFilterState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.67,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  var target = _filteredTargets[index];
                  int currentValue = target['current_value'] ?? 0;
                  int targetValue = target['target_value'] ?? 1;
                  double progress =
                      targetValue > 0 ? (currentValue / targetValue) : 0.0;
                  if (progress > 1.0) progress = 1.0;

                  return _buildHealthCard(
                      target, progress, currentValue, targetValue);
                },
                childCount: _filteredTargets.length,
              ),
            ),
          ),

        // BOTTOM SPACING
        const SliverToBoxAdapter(
          child: SizedBox(height: 36),
        ),
      ],
    );
  }

  // --- HERO BANNER ---
  Widget _buildHeroBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3366FF).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            left: 90,
            bottom: -40,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E096).withValues(alpha: 0.12),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Mission tag & current date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_rounded,
                            color: Color(0xFFFF5252), size: 13),
                        SizedBox(width: 5),
                        Text(
                          'Misi Kesehatan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDate(DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Gauge and stats
              Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: _overallProgress,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.12),
                          color: _overallProgress >= 1.0
                              ? const Color(0xFF00E096)
                              : const Color(0xFF3366FF),
                          strokeWidth: 7,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(_overallProgress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Tuntas',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getMotivationalMessage(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildHeroStatChip(
                              icon: Icons.check_circle_outline_rounded,
                              label: '$_completedCount/$_totalCount Selesai',
                              color: const Color(0xFF00E096),
                            ),
                            const SizedBox(width: 8),
                            _buildHeroStatChip(
                              icon: Icons.military_tech_rounded,
                              label: '${_completedCount * 15} XP',
                              color: const Color(0xFFFFC94D),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Chip Status Pengingat
              GestureDetector(
                onTap: _showReminderSettingsModal,
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isReminderEnabled
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_rounded,
                            size: 14,
                            color: _isReminderEnabled
                                ? const Color(0xFFFFC94D)
                                : const Color(0xFF8F9BB3),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isReminderEnabled
                                ? 'Pengingat: Tiap $_reminderInterval jam (Mulai ${_reminderStartHour.toString().padLeft(2, '0')}:00)'
                                : 'Pengingat nonaktif (Ketuk untuk menyalakan)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.tune_rounded,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- FILTER TABS ---
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _buildFilterOption(
            HealthFilter.all,
            'Semua ($_totalCount)',
          ),
          const SizedBox(width: 8),
          _buildFilterOption(
            HealthFilter.ongoing,
            'Berjalan (${_totalCount - _completedCount})',
          ),
          const SizedBox(width: 8),
          _buildFilterOption(
            HealthFilter.completed,
            'Selesai ($_completedCount)',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(HealthFilter filter, String label) {
    final isSelected = _currentFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentFilter = filter;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3366FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF3366FF)
                  : const Color(0xFFEDF1F7),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF3366FF).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFF8F9BB3).withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF8F9BB3),
            ),
          ),
        ),
      ),
    );
  }

  // --- SECTION HEADER ---
  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Target Kamu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222B45),
              letterSpacing: -0.3,
            ),
          ),
          Text(
            '${_filteredTargets.length} item',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8F9BB3),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- HEALTH CARD ---
  Widget _buildHealthCard(
    Map<String, dynamic> target,
    double progress,
    int currentValue,
    int targetValue,
  ) {
    bool isCompleted = target['is_completed'] ?? false;
    String unit = target['unit'] ?? '';
    bool isExercise = target['type'] == 'exercise';
    final categoryTheme =
        _getCategoryTheme(target['title'] ?? '', target['type']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF00E096).withValues(alpha: 0.3)
              : const Color(0xFFEDF1F7),
          width: isCompleted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: categoryTheme.primaryColor
                .withValues(alpha: isCompleted ? 0.08 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: categoryTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  categoryTheme.icon,
                  color: categoryTheme.primaryColor,
                  size: 19,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isExercise && !isCompleted)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3D6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 10, color: Color(0xFFFFAA00)),
                          SizedBox(width: 3),
                          Text(
                            'Timer',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFAA00),
                            ),
                          ),
                        ],
                      ),
                    ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showEditTargetModal(target),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 17,
                        color: const Color(0xFF8F9BB3).withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            target['title'] ?? 'Target',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF222B45),
              letterSpacing: -0.2,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),

          // Progress text & percentage badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$currentValue/$targetValue',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF222B45),
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (unit.isNotEmpty)
                      Text(
                        unit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF8F9BB3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFFE5F9F1)
                      : categoryTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isCompleted
                        ? const Color(0xFF00B377)
                        : categoryTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 5,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFEDF1F7),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted
                      ? const Color(0xFF00E096)
                      : categoryTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: isCompleted
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F9F1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00E096).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 15, color: Color(0xFF00B377)),
                        SizedBox(width: 5),
                        Text(
                          'Selesai',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00B377),
                          ),
                        ),
                      ],
                    ),
                  )
                : ElevatedButton(
                    onPressed: () async {
                      if (isExercise) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PomodoroScreen(target: target),
                          ),
                        );
                        if (result == true) {
                          _loadHealthData();
                          if (mounted) {
                            _showTargetCompletedDialog(
                              title: target['title'] ?? 'Olahraga',
                              earnedXp: null,
                            );
                          }
                        }
                      } else {
                        _incrementProgress(target);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isExercise
                          ? const Color(0xFFFFAA00)
                          : const Color(0xFF3366FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isExercise
                              ? Icons.play_arrow_rounded
                              : Icons.add_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            isExercise ? 'Mulai' : '+1 $unit',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- EMPTY STATES ---
  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF8F9BB3).withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.health_and_safety_outlined,
                    size: 52,
                    color: Color(0xFF3366FF),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Belum Ada Target Kesehatan',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222B45),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Target kesehatan harianmu masih kosong.\nSilakan tambahkan melalui panel Admin untuk memulai petualanganmu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8F9BB3),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _loadHealthData,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Muat Ulang Data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3366FF),
                    side: const BorderSide(color: Color(0xFF3366FF)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFilterState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDF1F7)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _currentFilter == HealthFilter.completed
                  ? Icons.emoji_events_outlined
                  : Icons.task_alt_outlined,
              size: 36,
              color: const Color(0xFF8F9BB3),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _currentFilter == HealthFilter.completed
                ? 'Belum Ada Target Selesai'
                : 'Semua Target Sudah Selesai!',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222B45),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currentFilter == HealthFilter.completed
                ? 'Ayo selesaikan target pertamamu hari ini untuk mengumpulkan XP!'
                : 'Hebat! Kamu telah menuntaskan seluruh target kesehatan hari ini.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8F9BB3),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}