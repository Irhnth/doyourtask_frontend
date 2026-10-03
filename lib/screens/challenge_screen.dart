import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _hasActiveChallenge = false;
  Map<String, dynamic>? _challengeInfo;
  Map<String, dynamic>? _progressInfo;
  List<dynamic> _days = [];
  Map<String, dynamic>? _availableChallenge;
  int _selectedWeek = 1;

  @override
  void initState() {
    super.initState();
    _loadChallengeData();
  }

  Future<void> _loadChallengeData() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getActiveChallenge();
      if (!mounted) return;

      if (response['has_active_challenge'] == true) {
        final progress = response['progress'] as Map<String, dynamic>;
        final currentDay = progress['current_day'] ?? 1;
        final week = ((currentDay - 1) ~/ 7) + 1;

        // Jadwalkan pengingat tantangan harian jam 09:00 pagi
        NotificationService().scheduleChallengeReminder(currentDay: currentDay);

        setState(() {
          _hasActiveChallenge = true;
          _challengeInfo = response['challenge'];
          _progressInfo = progress;
          _days = response['days'] ?? [];
          _selectedWeek = week.clamp(1, 4);
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasActiveChallenge = false;
          _availableChallenge = response['available_challenge'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _joinChallenge(int challengeId) async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.joinChallenge(challengeId);
      if (mounted) {
        // Jadwalkan pengingat tantangan untuk Hari 1
        NotificationService().scheduleChallengeReminder(currentDay: 1);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Berhasil memulai tantangan!'),
            backgroundColor: const Color(0xFF00E096),
          ),
        );
        _loadChallengeData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _completeDay(int dayNumber, {String notes = ''}) async {
    try {
      final res = await _apiService.completeDayChallenge(dayNumber: dayNumber, notes: notes);
      if (!mounted) return;

      final data = res['data'] ?? {};
      final earnedXp = data['earned_xp'] ?? 25;
      final newStreak = data['current_streak'] ?? 1;
      final isLevelUp = data['is_level_up'] == true;
      final newLevel = data['new_level'];
      final unlockedBadge = data['unlocked_badge'];
      final isChallengeCompleted = data['is_challenge_completed'] == true;

      // Jadwalkan pengingat untuk hari berikutnya
      final nextDay = dayNumber < 28 ? dayNumber + 1 : 28;
      NotificationService().scheduleChallengeReminder(currentDay: nextDay);

      _showCelebrationDialog(
        dayNumber: dayNumber,
        earnedXp: earnedXp,
        newStreak: newStreak,
        isLevelUp: isLevelUp,
        newLevel: newLevel,
        unlockedBadge: unlockedBadge,
        isChallengeCompleted: isChallengeCompleted,
      );

      _loadChallengeData();
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(cleanMsg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              ],
            ),
            backgroundColor: const Color(0xFFFF3D71),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showCelebrationDialog({
    required int dayNumber,
    required int earnedXp,
    required int newStreak,
    required bool isLevelUp,
    String? newLevel,
    Map<String, dynamic>? unlockedBadge,
    required bool isChallengeCompleted,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFC94D).withOpacity(0.15),
                  ),
                  child: const Center(
                    child: Icon(Icons.stars_rounded, color: Color(0xFFFFC94D), size: 50),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isChallengeCompleted
                      ? '🏆 GRAND FINALE CHAMPION!'
                      : 'Misi Hari ke-$dayNumber Selesai!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF222B45)),
                ),
                const SizedBox(height: 12),
                Text(
                  isChallengeCompleted
                      ? 'Luar biasa! Kamu telah menuntaskan seluruh 28 hari tantangan pembentukan kebiasaan baru!'
                      : 'Kerja kerasmu hari ini membuahkan hasil. Konsistensi adalah kunci kebiasaan abadi!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF8F9BB3)),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3366FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: Color(0xFF3366FF), size: 20),
                          const SizedBox(width: 6),
                          Text('+$earnedXp XP', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3366FF))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Colors.deepOrange, size: 20),
                          const SizedBox(width: 6),
                          Text('$newStreak Hari', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (unlockedBadge != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E096).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00E096).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.military_tech_rounded, color: Color(0xFF00E096), size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('LENCANA BARU DIRAIH!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00E096))),
                              Text(unlockedBadge['name'] ?? 'Milestone Badge', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF222B45))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isLevelUp) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC94D).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFC94D).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_upward_rounded, color: Color(0xFFFFC94D), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SELAMAT NAIK LEVEL!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                              Text('Tingkat Baru: $newLevel', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF222B45))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3366FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Lanjutkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reset Tantangan?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'Apakah Anda yakin ingin membatalkan dan memulai ulang tantangan ini dari Hari ke-1? Progres XP yang sudah Anda dapatkan sebelumnya akan tetap tersimpan di akun Anda.',
            style: TextStyle(fontSize: 14, color: Color(0xFF8F9BB3)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF8F9BB3))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await _apiService.abandonChallenge();
                  _loadChallengeData();
                } catch (e) {
                  setState(() => _isLoading = false);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  void _openDayMissionModal(Map<String, dynamic> day) {
    final TextEditingController notesController = TextEditingController(text: day['notes'] ?? '');
    final isCompleted = day['is_completed'] == true;
    final isLocked = day['status'] == 'locked';
    final dayNum = day['day_number'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4E9F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: day['is_milestone'] == true
                          ? const Color(0xFFFFC94D).withOpacity(0.2)
                          : const Color(0xFF3366FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      day['is_milestone'] == true ? '🌟 Milestone Pekan' : 'Hari ke-$dayNum',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: day['is_milestone'] == true ? const Color(0xFFD97706) : const Color(0xFF3366FF),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF00E096).withOpacity(0.12)
                          : isLocked
                              ? Colors.grey.withOpacity(0.15)
                              : Colors.blue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCompleted
                          ? '✅ Selesai'
                          : isLocked
                              ? '🔒 Terkunci'
                              : '⚡ Misi Aktif',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? const Color(0xFF00E096)
                            : isLocked
                                ? Colors.grey
                                : const Color(0xFF3366FF),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                day['title'] ?? 'Misi Harian',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF222B45)),
              ),
              const SizedBox(height: 10),
              Text(
                day['description'] ?? '',
                style: const TextStyle(fontSize: 14, color: Color(0xFF8F9BB3), height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E9F2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard_rounded, color: Color(0xFF3366FF), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Hadiah Penyelesaian', style: TextStyle(fontSize: 12, color: Color(0xFF8F9BB3))),
                          Text(
                            '+${day['total_xp']} XP${day['milestone_bonus_xp'] > 0 ? ' (Termasuk Bonus Milestone +${day['milestone_bonus_xp']} XP)' : ''}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF222B45)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (!isCompleted && !isLocked) ...[
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Catatan Refleksi (Opsional)',
                    hintText: 'Tuliskan pencapaian atau kendalamu hari ini...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4E9F2))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4E9F2))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3366FF), width: 2)),
                    filled: true,
                    fillColor: const Color(0xFFF7F9FC),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3366FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _completeDay(dayNum, notes: notesController.text);
                    },
                    child: const Text('Selesaikan Misi Ini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else if (isCompleted) ...[
                if (day['notes'] != null && day['notes'].toString().isNotEmpty) ...[
                  const Text('Catatan Refleksimu:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF222B45))),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(day['notes'], style: const TextStyle(fontSize: 13, color: Color(0xFF8F9BB3), fontStyle: FontStyle.italic)),
                  ),
                  const SizedBox(height: 16),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E096).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('🎉 Misi ini telah berhasil kamu selesaikan!', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E096))),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('🔒 Misi ini akan terbuka saat harinya tiba.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Tantangan 28 Hari', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222B45))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF222B45), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_hasActiveChallenge)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF222B45)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                if (value == 'reset') {
                  _showResetConfirmation();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: 10),
                      Text('Ulangi Tantangan', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3366FF)))
          : !_hasActiveChallenge
              ? _buildJoinChallengeView()
              : _buildActiveChallengeView(),
    );
  }

  Widget _buildJoinChallengeView() {
    final challenge = _availableChallenge ?? {};
    final title = challenge['title'] ?? 'Tantangan 28 Hari: Bangun Kebiasaan Produktif & Sehat';
    final desc = challenge['description'] ?? 'Program intensif 4 minggu untuk membentuk kebiasaan kerja produktif, disiplin waktu, dan pola hidup seimbang.';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF222B45), Color(0xFF192038)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF222B45).withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3366FF).withOpacity(0.2),
                  border: Border.all(color: const Color(0xFF3366FF).withOpacity(0.4), width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.rocket_launch_rounded, color: Color(0xFF3366FF), size: 48),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
              ),
              const SizedBox(height: 12),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF8F9BB3), height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('28 Hari', 'Durasi', Icons.calendar_today_rounded),
                  _buildStatItem('+1400 XP', 'Total Hadiah', Icons.bolt_rounded),
                  _buildStatItem('4 Lencana', 'Milestone', Icons.emoji_events_rounded),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Mengapa Tantangan 28 Hari?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF222B45)),
        ),
        const SizedBox(height: 16),
        _buildFeatureRow('🌱 Minggu 1: Inisiasi & Pondasi', 'Mulai kebiasaan kecil seperti minum air, to-do list terencana, dan pomodoro awal.'),
        _buildFeatureRow('⚡ Minggu 2: Membangun Ritme', 'Tingkatkan durasi fokus dan langkah kaki tanpa tergoda distraksi.'),
        _buildFeatureRow('🛡️ Minggu 3: Menembus Resistensi', 'Fase terpenting di mana otak mengunci jalur saraf kebiasaan baru (21 hari).'),
        _buildFeatureRow('👑 Minggu 4: Habit Mastery', 'Jadikan produktivitas dan hidup seimbang sebagai gaya hidup alamimu.'),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3366FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            onPressed: () {
              final challengeId = challenge['id'] ?? 1;
              _joinChallenge(challengeId);
            },
            child: const Text('Mulai Tantangan Sekarang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFFFC94D), size: 24),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Color(0xFF8F9BB3), fontSize: 11)),
      ],
    );
  }

  Widget _buildFeatureRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE4E9F2))),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00E096), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF222B45))),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF8F9BB3), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChallengeView() {
    final progress = _progressInfo ?? {};
    final currentDay = progress['current_day'] ?? 1;
    final streak = progress['current_streak'] ?? 0;
    final totalXp = progress['total_xp_earned'] ?? 0;
    final completedCount = progress['completed_days_count'] ?? 0;
    final percentage = progress['progress_percentage'] ?? 0;
    final isTodayCompleted = progress['is_today_completed'] == true;

    // Filter hari sesuai tab minggu yang aktif
    final weekDays = _days.where((d) => d['week_number'] == _selectedWeek).toList();
    final todayDayData = _days.firstWhere(
      (d) => d['day_number'] == currentDay,
      orElse: () => _days.isNotEmpty ? _days[0] : null,
    );

    return RefreshIndicator(
      onRefresh: _loadChallengeData,
      color: const Color(0xFF3366FF),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          // 1. Hero Card Progres 28 Hari
          _buildHeroProgressCard(currentDay, streak, totalXp, completedCount, percentage),
          const SizedBox(height: 24),

          // 2. Kartu Misi Hari Ini (Action Card)
          if (todayDayData != null)
            _buildTodayMissionCard(todayDayData, isTodayCompleted),
          const SizedBox(height: 28),

          // 3. Tab Navigasi 4 Minggu
          _buildWeekTabs(),
          const SizedBox(height: 18),

          // 4. Milestone Box untuk Pekan Terpilih
          _buildMilestoneBannerForWeek(_selectedWeek),
          const SizedBox(height: 16),

          // 5. Grid/List Hari untuk Pekan Terpilih
          ...weekDays.map((day) => _buildDayTile(day)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeroProgressCard(int currentDay, int streak, int totalXp, int completedCount, int percentage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF222B45),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF222B45).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PROGRES PERJALANAN', style: TextStyle(color: Color(0xFF8F9BB3), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text('Hari ke-$currentDay dari 28', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 20),
                    const SizedBox(width: 4),
                    Text('$streak Hari', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (percentage / 100.0).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3366FF)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$completedCount dari 28 Hari Selesai ($percentage%)', style: const TextStyle(color: Color(0xFF8F9BB3), fontSize: 12)),
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFFFC94D), size: 16),
                  const SizedBox(width: 4),
                  Text('$totalXp XP', style: const TextStyle(color: Color(0xFFFFC94D), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMissionCard(Map<String, dynamic> day, bool isTodayCompleted) {
    final dayNum = day['day_number'];
    final title = day['title'] ?? 'Misi Hari Ini';
    final desc = day['description'] ?? '';
    final xp = day['total_xp'] ?? 25;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isTodayCompleted ? const Color(0xFF00E096).withOpacity(0.5) : const Color(0xFF3366FF).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isTodayCompleted ? const Color(0xFF00E096).withOpacity(0.12) : const Color(0xFF3366FF).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isTodayCompleted ? Icons.check_circle_rounded : Icons.star_rounded,
                      color: isTodayCompleted ? const Color(0xFF00E096) : const Color(0xFF3366FF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isTodayCompleted ? 'MISI HARI INI SELESAI' : 'MISI HARI INI (HARI $dayNum)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isTodayCompleted ? const Color(0xFF00E096) : const Color(0xFF3366FF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC94D).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('+$xp XP', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF222B45))),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF8F9BB3), height: 1.4)),
          const SizedBox(height: 18),
          if (!isTodayCompleted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3366FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.task_alt_rounded, size: 20),
                label: const Text('Selesaikan Misi Hari Ini', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                onPressed: () => _openDayMissionModal(day),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF00E096).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.thumb_up_alt_rounded, color: Color(0xFF00E096), size: 18),
                  SizedBox(width: 8),
                  Text('Hebat! Streak hari ini aman.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E096), fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeekTabs() {
    return Row(
      children: List.generate(4, (index) {
        final weekNum = index + 1;
        final isSelected = _selectedWeek == weekNum;
        final weekDays = _days.where((d) => d['week_number'] == weekNum).toList();
        final completedInWeek = weekDays.where((d) => d['is_completed'] == true).length;

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedWeek = weekNum),
            child: Container(
              margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3366FF) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? const Color(0xFF3366FF) : const Color(0xFFE4E9F2)),
                boxShadow: isSelected
                    ? [BoxShadow(color: const Color(0xFF3366FF).withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Column(
                children: [
                  Text(
                    'Minggu $weekNum',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF222B45),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completedInWeek/7',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white.withOpacity(0.8) : const Color(0xFF8F9BB3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMilestoneBannerForWeek(int weekNum) {
    final milestoneTitles = {
      1: {'badge': 'Week 1 Survivor', 'desc': 'Klaim lencana pertama setelah bertahan 7 hari.'},
      2: {'badge': 'Halfway Hero', 'desc': 'Paruh perjalanan 14 hari berhasil dilewati.'},
      3: {'badge': 'Discipline Master', 'desc': 'Kunci kebiasaan baru di ambang batas 21 hari.'},
      4: {'badge': '28-Day Champion', 'desc': 'Pencapaian tertinggi: Kebiasaanmu resmi terbangun!'},
    };

    final info = milestoneTitles[weekNum] ?? {'badge': 'Milestone', 'desc': ''};

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC94D).withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC94D).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.military_tech_rounded, color: Color(0xFFD97706), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hadiah Akhir Pekan $weekNum: ${info['badge']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD97706))),
                const SizedBox(height: 2),
                Text(info['desc']!, style: const TextStyle(fontSize: 11, color: Color(0xFF8F9BB3))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTile(Map<String, dynamic> day) {
    final dayNum = day['day_number'];
    final title = day['title'] ?? '';
    final isCompleted = day['is_completed'] == true;
    final status = day['status'];
    final isMilestone = day['is_milestone'] == true;
    final totalXp = day['total_xp'] ?? 25;

    Color iconColor;
    IconData icon;
    Color tileBg = Colors.white;

    if (isCompleted) {
      iconColor = const Color(0xFF00E096);
      icon = Icons.check_circle_rounded;
    } else if (status == 'today') {
      iconColor = const Color(0xFF3366FF);
      icon = Icons.play_circle_fill_rounded;
      tileBg = const Color(0xFF3366FF).withOpacity(0.04);
    } else if (status == 'missed') {
      iconColor = Colors.orange;
      icon = Icons.error_outline_rounded;
    } else {
      iconColor = const Color(0xFFC5CEE0);
      icon = Icons.lock_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status == 'today'
              ? const Color(0xFF3366FF).withOpacity(0.5)
              : const Color(0xFFE4E9F2),
          width: status == 'today' ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _openDayMissionModal(day),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Icon(icon, color: iconColor, size: 24),
          ),
        ),
        title: Row(
          children: [
            Text('Hari $dayNum', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF222B45))),
            if (isMilestone) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC94D).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Milestone', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8F9BB3)),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('+$totalXp XP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF3366FF))),
            const SizedBox(height: 2),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFC5CEE0)),
          ],
        ),
      ),
    );
  }
}
