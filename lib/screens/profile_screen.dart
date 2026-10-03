import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ==========================================
// MODEL DATA ANALISIS PERILAKU PENUNDAAN
// ==========================================
class _ProcrastinationAnalysis {
  final int totalEvaluated;
  final int onTimeCount;
  final int lastMinuteCount;
  final int lateCompletedCount;
  final int overduePendingCount;
  final int disciplineScore;
  final String archetypeTitle;
  final String archetypeDesc;
  final Color archetypeColor;
  final IconData archetypeIcon;
  final List<String> tips;

  _ProcrastinationAnalysis({
    required this.totalEvaluated,
    required this.onTimeCount,
    required this.lastMinuteCount,
    required this.lateCompletedCount,
    required this.overduePendingCount,
    required this.disciplineScore,
    required this.archetypeTitle,
    required this.archetypeDesc,
    required this.archetypeColor,
    required this.archetypeIcon,
    required this.tips,
  });
}

// ==========================================
// MODEL DATA MONITORING PRODUKTIVITAS HARIAN
// ==========================================
class _DailyProductivityData {
  final DateTime date;
  final String dayLabel; // 'Sen', 'Sel', 'Rab', dst.
  final String fullDayName; // 'Senin', 'Selasa', dst.
  final String dateFormatted; // '3 Okt'
  final int completedCount;
  final int earnedXp;
  final bool isToday;

  _DailyProductivityData({
    required this.date,
    required this.dayLabel,
    required this.fullDayName,
    required this.dateFormatted,
    required this.completedCount,
    required this.earnedXp,
    required this.isToday,
  });
}

class _ProductivityMonitoringStats {
  final List<_DailyProductivityData> dailyData;
  final int todayCompleted;
  final int yesterdayCompleted;
  final int dayDifference;
  final String comparisonText;
  final Color comparisonColor;
  final IconData comparisonIcon;
  final int currentStreak;
  final double averagePerDay;
  final String bestDayName;
  final int bestDayCount;
  final int totalPeriodCompleted;
  final int totalPeriodXp;
  final int daysRange;

  _ProductivityMonitoringStats({
    required this.dailyData,
    required this.todayCompleted,
    required this.yesterdayCompleted,
    required this.dayDifference,
    required this.comparisonText,
    required this.comparisonColor,
    required this.comparisonIcon,
    required this.currentStreak,
    required this.averagePerDay,
    required this.bestDayName,
    required this.bestDayCount,
    required this.totalPeriodCompleted,
    required this.totalPeriodXp,
    required this.daysRange,
  });
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();

  Map<String, dynamic>? _userProfile;
  List<dynamic> _tasks = [];
  List<dynamic> _healthTargets = [];
  List<dynamic> _leaderboard = [];
  Map<String, dynamic>? _serverProcrastinationData;

  bool _isLoading = true;
  int _selectedDaysRange = 30; // Default menampilkan hingga 30 hari
  int _selectedChartDayIndex = 29; // Default memilih hari terakhir
  bool _isHistoryExpanded = false; // Toggle untuk riwayat harian
  final ScrollController _chartScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedChartDayIndex = _selectedDaysRange - 1;
    _loadProfileData();
  }

  @override
  void dispose() {
    _chartScrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chartScrollController.hasClients) {
        _chartScrollController.animateTo(
          _chartScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getTasks().catchError((_) => <dynamic>[]),
        _apiService.getTodayHealthProgress().catchError((_) => <dynamic>[]),
        _apiService.getLeaderboard().catchError((_) => <dynamic>[]),
        _apiService.getProcrastinationAnalysis().catchError((_) => <String, dynamic>{}),
      ]);

      if (mounted) {
        setState(() {
          _userProfile = results[0] as Map<String, dynamic>?;
          _tasks = results[1] as List<dynamic>;
          _healthTargets = results[2] as List<dynamic>;
          _leaderboard = results[3] as List<dynamic>;
          _serverProcrastinationData = results[4] as Map<String, dynamic>?;
          _selectedChartDayIndex = _selectedDaysRange - 1;
          _isLoading = false;
        });
        if (_selectedDaysRange > 7) {
          _scrollToLatest();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFF2E3A59),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Cari posisi peringkat pengguna di leaderboard
  int? _getUserRank() {
    if (_userProfile == null || _leaderboard.isEmpty) return null;
    final currentUserId = _userProfile!['id'];
    final currentUserName = _userProfile!['name'];

    for (int i = 0; i < _leaderboard.length; i++) {
      final user = _leaderboard[i];
      if ((currentUserId != null && user['id'] == currentUserId) ||
          (currentUserName != null && user['name'] == currentUserName)) {
        return i + 1;
      }
    }
    return null;
  }

  // ==========================================
  // PERHITUNGAN ANALISIS PERILAKU PENUNDAAN
  // ==========================================
  _ProcrastinationAnalysis _computeProcrastinationStats() {
    // 1. Prioritaskan hasil perhitungan resmi dari backend server
    if (_serverProcrastinationData != null &&
        _serverProcrastinationData!['status'] == 'success' &&
        _serverProcrastinationData!['data'] != null) {
      final d = _serverProcrastinationData!['data'] as Map<String, dynamic>;
      final score = (d['score'] ?? 0) as int;
      final overduePending = (d['overdue_pending_count'] ?? 0) as int;
      final lastMinute = (d['last_minute_count'] ?? 0) as int;
      final onTime = (d['on_time_count'] ?? 0) as int;
      final lateCompleted = (d['late_completed_count'] ?? 0) as int;
      final total = (d['total_evaluated'] ?? 0) as int;

      IconData archetypeIcon;
      if (total == 0) {
        archetypeIcon = Icons.hourglass_empty_rounded;
      } else if (score >= 80 && overduePending == 0) {
        archetypeIcon = Icons.verified_user_rounded;
      } else if (score >= 50 || (lastMinute > onTime && overduePending <= 1)) {
        archetypeIcon = Icons.bolt_rounded;
      } else {
        archetypeIcon = Icons.warning_amber_rounded;
      }

      Color color;
      final hexColor = d['archetype_color']?.toString() ?? '#8F9BB3';
      try {
        color = Color(int.parse(hexColor.replaceAll('#', '0xFF')));
      } catch (_) {
        color = const Color(0xFF8F9BB3);
      }

      final tipsList = (d['tips'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];

      return _ProcrastinationAnalysis(
        totalEvaluated: total,
        onTimeCount: onTime,
        lastMinuteCount: lastMinute,
        lateCompletedCount: lateCompleted,
        overduePendingCount: overduePending,
        disciplineScore: score,
        archetypeTitle: d['archetype_title']?.toString() ?? 'Belum Cukup Data',
        archetypeDesc: d['archetype_desc']?.toString() ?? '',
        archetypeColor: color,
        archetypeIcon: archetypeIcon,
        tips: tipsList,
      );
    }

    // 2. Fallback perhitungan lokal (menggunakan completed_at aktual, fallback ke updated_at)
    final now = DateTime.now();
    int onTime = 0;
    int lastMinute = 0;
    int lateCompleted = 0;
    int overduePending = 0;

    for (final task in _tasks) {
      final deadlineRaw = task['deadline'];
      if (deadlineRaw == null) continue;
      final deadline = DateTime.tryParse(deadlineRaw.toString());
      if (deadline == null) continue;

      final isCompleted = task['status'] == 'completed';

      if (isCompleted) {
        DateTime? completedAt;
        if (task['completed_at'] != null) {
          completedAt = DateTime.tryParse(task['completed_at'].toString());
        } else if (task['updated_at'] != null) {
          completedAt = DateTime.tryParse(task['updated_at'].toString());
        }
        completedAt ??= deadline;

        if (completedAt.isAfter(deadline)) {
          lateCompleted++;
        } else {
          final diffToDeadline = deadline.difference(completedAt);
          // Bila diselesaikan kurang dari 3 jam sebelum deadline tiba
          if (diffToDeadline.inHours < 3) {
            lastMinute++;
          } else {
            onTime++;
          }
        }
      } else {
        // Quest pending yang sudah melewati tenggat waktu
        if (now.isAfter(deadline)) {
          overduePending++;
        }
      }
    }

    final totalEvaluated = onTime + lastMinute + lateCompleted + overduePending;

    int score = 0;
    if (totalEvaluated > 0) {
      // Bobot: On-Time = 100%, Mepet Tenggat = 50%, Terlambat/Overdue = 0%
      final rawScore = ((onTime * 1.0 + lastMinute * 0.5) / totalEvaluated) * 100;
      score = rawScore.round().clamp(0, 100);
    }

    String archetypeTitle;
    String archetypeDesc;
    Color archetypeColor;
    IconData archetypeIcon;
    List<String> tips;

    if (totalEvaluated == 0) {
      archetypeTitle = 'Belum Cukup Data';
      archetypeDesc = 'Selesaikan beberapa quest untuk mulai melihat pola manajemen waktumu.';
      archetypeColor = const Color(0xFF8F9BB3);
      archetypeIcon = Icons.hourglass_empty_rounded;
      tips = [
        'Tetapkan tenggat waktu yang realistis pada setiap quest baru.',
        'Selesaikan tugas lebih awal untuk membangun ritme kerja yang tenang.',
        'Manfaatkan timer Pomodoro di menu Kesehatan untuk melatih fokus intensif.',
      ];
    } else if (score >= 80 && overduePending == 0) {
      archetypeTitle = 'Eksekutor Proaktif';
      archetypeDesc = 'Luar biasa! Kamu konsisten menuntaskan quest jauh sebelum batas waktu tanpa menunda.';
      archetypeColor = const Color(0xFF00E096);
      archetypeIcon = Icons.verified_user_rounded;
      tips = [
        'Pertahankan kebiasaan baik dengan terus memecah quest besar menjadi langkah kecil.',
        'Berikan waktu istirahat yang cukup di sela-sela pencapaian tugasmu agar tidak burnout.',
        'Tantang dirimu dengan quest baru yang lebih menantang untuk memaksimalkan perolehan XP.',
      ];
    } else if (score >= 50 || (lastMinute > onTime && overduePending <= 1)) {
      archetypeTitle = 'Pejuang Deadline';
      archetypeDesc = 'Kamu sering menyelesaikan quest mepet menit-menit akhir menjelang batas waktu.';
      archetypeColor = const Color(0xFFFFAA00);
      archetypeIcon = Icons.bolt_rounded;
      tips = [
        'Terapkan "Aturan 5 Menit": paksa dirimu memulai tugas selama 5 menit tanpa distraksi untuk mengatasi rasa malas awal.',
        'Gunakan timer Pomodoro (25 menit kerja, 5 menit istirahat) untuk mencegah stres di akhir.',
        'Buat target selesai pribadi 3-6 jam sebelum tenggat waktu sebenarnya.',
      ];
    } else {
      archetypeTitle = 'Kerap Menunda';
      archetypeDesc = 'Terdapat beberapa quest yang terlambat atau melewati tenggat waktu. Yuk atur ulang fokusmu!';
      archetypeColor = const Color(0xFFFF3D71);
      archetypeIcon = Icons.warning_amber_rounded;
      tips = [
        'Pilih 1 quest yang paling mudah dan selesaikan sekarang juga untuk memicu momentum.',
        'Hindari menumpuk deadline di jam yang sama; distribusikan tugas secara bertahap.',
        'Aktifkan pengingat notifikasi kesehatan dan quest agar kamu selalu mendapat alarm berkala.',
      ];
    }

    return _ProcrastinationAnalysis(
      totalEvaluated: totalEvaluated,
      onTimeCount: onTime,
      lastMinuteCount: lastMinute,
      lateCompletedCount: lateCompleted,
      overduePendingCount: overduePending,
      disciplineScore: score,
      archetypeTitle: archetypeTitle,
      archetypeDesc: archetypeDesc,
      archetypeColor: archetypeColor,
      archetypeIcon: archetypeIcon,
      tips: tips,
    );
  }

  // ==========================================
  // PERHITUNGAN MONITORING PRODUKTIVITAS HARIAN
  // ==========================================
  _ProductivityMonitoringStats _computeProductivityMonitoring() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysRange = _selectedDaysRange;

    const dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const fullDayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];

    // Ambil rentang hari terakhir sesuai selectedDaysRange (H-(daysRange-1) sampai H-0)
    final List<DateTime> rangeDays = List.generate(daysRange, (i) {
      return today.subtract(Duration(days: daysRange - 1 - i));
    });

    final Map<String, int> completedMap = {};
    final Map<String, int> xpMap = {};

    for (final task in _tasks) {
      if (task['status'] != 'completed') continue;

      DateTime? completedDate;
      if (task['updated_at'] != null) {
        completedDate = DateTime.tryParse(task['updated_at'].toString());
      }
      if (completedDate == null && task['deadline'] != null) {
        completedDate = DateTime.tryParse(task['deadline'].toString());
      }
      if (completedDate == null) continue;

      final localDate = completedDate.toLocal();
      final key = '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';

      completedMap[key] = (completedMap[key] ?? 0) + 1;
      final xp = (task['reward_xp'] is num) ? (task['reward_xp'] as num).toInt() : 50;
      xpMap[key] = (xpMap[key] ?? 0) + xp;
    }

    final List<_DailyProductivityData> dailyData = [];
    int totalPeriodCompleted = 0;
    int totalPeriodXp = 0;
    String bestDay = '-';
    int bestCount = 0;

    for (int i = 0; i < rangeDays.length; i++) {
      final date = rangeDays[i];
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final completed = completedMap[key] ?? 0;
      final xp = xpMap[key] ?? 0;

      final isCurrentDay = i == rangeDays.length - 1;
      final dayLabel = dayNames[date.weekday - 1];
      final fullDay = fullDayNames[date.weekday - 1];
      final dateFormatted = '${date.day} ${monthNames[date.month - 1]}';

      totalPeriodCompleted += completed;
      totalPeriodXp += xp;

      if (completed > bestCount) {
        bestCount = completed;
        bestDay = fullDay;
      }

      dailyData.add(_DailyProductivityData(
        date: date,
        dayLabel: dayLabel,
        fullDayName: fullDay,
        dateFormatted: dateFormatted,
        completedCount: completed,
        earnedXp: xp,
        isToday: isCurrentDay,
      ));
    }

    // Hari ini vs Kemarin
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final int todayCompleted = completedMap[todayKey] ?? 0;
    final int yesterdayCompleted = completedMap[yesterdayKey] ?? 0;
    final int dayDifference = todayCompleted - yesterdayCompleted;

    String comparisonText;
    Color comparisonColor;
    IconData comparisonIcon;

    if (dayDifference > 0) {
      if (yesterdayCompleted == 0) {
        comparisonText = 'Naik +$dayDifference quest dibanding kemarin';
      } else {
        final percent = ((dayDifference / yesterdayCompleted) * 100).round();
        comparisonText = 'Naik +$dayDifference quest (+$percent%) dibanding kemarin';
      }
      comparisonColor = const Color(0xFF00E096);
      comparisonIcon = Icons.trending_up_rounded;
    } else if (dayDifference == 0) {
      comparisonText = 'Sama dengan kemarin ($todayCompleted quest)';
      comparisonColor = const Color(0xFF3366FF);
      comparisonIcon = Icons.trending_flat_rounded;
    } else {
      final diffAbs = dayDifference.abs();
      comparisonText = 'Turun $diffAbs quest dibanding kemarin';
      comparisonColor = const Color(0xFFFF9E00);
      comparisonIcon = Icons.trending_down_rounded;
    }

    // Hitung Streak berturut-turut (hingga 60 hari ke belakang)
    int streak = 0;
    bool checkingToday = true;
    for (int i = 0; i < 60; i++) {
      final d = today.subtract(Duration(days: i));
      final k = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final c = completedMap[k] ?? 0;
      if (checkingToday) {
        if (c > 0) {
          streak++;
          checkingToday = false;
        } else {
          checkingToday = false;
        }
      } else {
        if (c > 0) {
          streak++;
        } else {
          break;
        }
      }
    }

    final double avgPerDay = (totalPeriodCompleted / daysRange.toDouble());

    return _ProductivityMonitoringStats(
      dailyData: dailyData,
      todayCompleted: todayCompleted,
      yesterdayCompleted: yesterdayCompleted,
      dayDifference: dayDifference,
      comparisonText: comparisonText,
      comparisonColor: comparisonColor,
      comparisonIcon: comparisonIcon,
      currentStreak: streak,
      averagePerDay: avgPerDay,
      bestDayName: bestCount > 0 ? bestDay : 'Belum Ada',
      bestDayCount: bestCount,
      totalPeriodCompleted: totalPeriodCompleted,
      totalPeriodXp: totalPeriodXp,
      daysRange: daysRange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF222B45)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profil & Statistik',
          style: TextStyle(
            color: Color(0xFF222B45),
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF3366FF)),
            tooltip: 'Segarkan Data',
            onPressed: _loadProfileData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3366FF)))
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              color: const Color(0xFF3366FF),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 24),
                    _buildLevelProgressCard(),
                    const SizedBox(height: 28),
                    _buildStatsOverviewSection(),
                    const SizedBox(height: 28),
                    _buildTaskAnalyticsCard(),
                    const SizedBox(height: 28),
                    _buildProcrastinationAnalysisCard(),
                    const SizedBox(height: 28),
                    _buildDailyProductivityMonitoringCard(),
                    const SizedBox(height: 28),
                    _buildHealthHabitAnalyticsCard(),
                    const SizedBox(height: 28),
                    _buildBadgesSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // ==========================================
  // 1. WIDGET FOTO, NAMA & CHIP PERINGKAT
  // ==========================================
  Widget _buildProfileHeader() {
    final name = _userProfile?['name']?.toString() ?? 'Pemain Misterius';
    final email = _userProfile?['email']?.toString() ?? 'email@tidakditemukan.com';
    final initialLetter = name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : 'U';
    final rank = _getUserRank();
    final levelName = _userProfile?['level']?['level_name']?.toString() ?? '1';

    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF3366FF), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3366FF).withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: Colors.white,
              child: Text(
                initialLetter,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3366FF),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222B45),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8F9BB3),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildHeaderTag(
                icon: Icons.shield_rounded,
                iconColor: const Color(0xFF3366FF),
                bgColor: const Color(0xFFEBF1FF),
                label: 'Level $levelName',
              ),
              _buildHeaderTag(
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFFFFAA00),
                bgColor: const Color(0xFFFFF7E6),
                label: rank != null ? 'Peringkat #$rank' : 'Pemain Aktif',
              ),
              if (_tasks.isNotEmpty)
                _buildHeaderTag(
                  icon: Icons.task_alt_rounded,
                  iconColor: const Color(0xFF00E096),
                  bgColor: const Color(0xFFE6FBF5),
                  label: '${_tasks.where((t) => t['status'] == 'completed').length} Quest Tuntas',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTag({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF222B45).withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. WIDGET LEVEL & XP PROGRESS CARD
  // ==========================================
  Widget _buildLevelProgressCard() {
    final currentXp = (_userProfile?['current_xp'] is num) ? (_userProfile!['current_xp'] as num).toInt() : 0;
    final nextLevelXp = (_userProfile?['next_level_xp_required'] is num)
        ? (_userProfile!['next_level_xp_required'] as num).toInt()
        : null;

    double progress = 1.0;
    if (nextLevelXp != null && nextLevelXp > 0) {
      progress = currentXp / nextLevelXp;
      if (progress > 1.0) progress = 1.0;
    }

    final levelName = _userProfile?['level']?['level_name']?.toString() ?? '1';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8F9BB3).withOpacity(0.08),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.military_tech_rounded, color: Color(0xFFFFAA00), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level $levelName',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF222B45),
                        ),
                      ),
                      Text(
                        nextLevelXp != null ? 'Target: $nextLevelXp XP' : 'Level Tertinggi',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8F9BB3)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF1FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$currentXp XP',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3366FF),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: const Color(0xFFEDF1F7),
              color: const Color(0xFF00E096),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% Progres',
                style: const TextStyle(
                  color: Color(0xFF00E096),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                nextLevelXp != null
                    ? 'Butuh ${nextLevelXp - currentXp} XP lagi'
                    : 'Level Maksimal Tercapai! 🏆',
                style: const TextStyle(
                  color: Color(0xFF8F9BB3),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. STATISTIK UTAMA (GRID 4 METRIK)
  // ==========================================
  Widget _buildStatsOverviewSection() {
    final totalTasks = _tasks.length;
    final completedTasks = _tasks.where((t) => t['status'] == 'completed').length;
    final taskSuccessRate = totalTasks > 0 ? ((completedTasks / totalTasks) * 100).round() : 0;

    final totalHealth = _healthTargets.length;
    final completedHealth = _healthTargets.where((t) => t['is_completed'] == true).length;
    final healthSuccessRate = totalHealth > 0 ? ((completedHealth / totalHealth) * 100).round() : 0;

    final badgesCount = (_userProfile?['badges'] as List<dynamic>?)?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.query_stats_rounded, color: Color(0xFF3366FF), size: 22),
                SizedBox(width: 8),
                Text(
                  'Statistik & Performa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222B45),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF1F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Akumulasi',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8F9BB3)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.25,
          children: [
            _buildStatCard(
              title: 'Quest Tuntas',
              value: '$completedTasks / $totalTasks',
              subtitle: totalTasks == 0 ? 'Belum ada tugas' : '$completedTasks diselesaikan',
              icon: Icons.task_alt_rounded,
              iconColor: const Color(0xFF00E096),
              bgColor: const Color(0xFFE6FBF5),
            ),
            _buildStatCard(
              title: 'Tingkat Sukses',
              value: '$taskSuccessRate%',
              subtitle: 'Penyelesaian Quest',
              icon: Icons.trending_up_rounded,
              iconColor: const Color(0xFF3366FF),
              bgColor: const Color(0xFFEBF1FF),
            ),
            _buildStatCard(
              title: 'Target Sehat',
              value: '$completedHealth / $totalHealth',
              subtitle: totalHealth == 0 ? 'Belum ada target' : '$healthSuccessRate% hari ini',
              icon: Icons.favorite_rounded,
              iconColor: const Color(0xFFFF3D71),
              bgColor: const Color(0xFFFFEBF1),
            ),
            _buildStatCard(
              title: 'Lencana Dibuka',
              value: '$badgesCount',
              subtitle: 'Prestasi Pemain',
              icon: Icons.workspace_premium_rounded,
              iconColor: const Color(0xFFFFAA00),
              bgColor: const Color(0xFFFFF8E7),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF1F7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8F9BB3).withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8F9BB3),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222B45),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. KARTU ANALISIS TUGAS (QUEST PRODUCTIVITY)
  // ==========================================
  Widget _buildTaskAnalyticsCard() {
    final totalTasks = _tasks.length;
    final completedTasks = _tasks.where((t) => t['status'] == 'completed').length;
    final activeTasks = totalTasks - completedTasks;
    final double completionRatio = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

    // Hitung tugas hari ini
    final now = DateTime.now();
    final todayTasks = _tasks.where((t) {
      if (t['deadline'] == null) return false;
      try {
        final dt = DateTime.parse(t['deadline'].toString());
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      } catch (_) {
        return false;
      }
    }).toList();

    final todayCompleted = todayTasks.where((t) => t['status'] == 'completed').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8F9BB3).withOpacity(0.08),
            blurRadius: 20,
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
              const Row(
                children: [
                  Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF3366FF), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Ringkasan Quest',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222B45),
                    ),
                  ),
                ],
              ),
              Text(
                '$totalTasks Total',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8F9BB3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(
                  flex: completedTasks == 0 && activeTasks == 0 ? 1 : completedTasks,
                  child: Container(
                    height: 10,
                    color: completedTasks == 0 && activeTasks == 0
                        ? const Color(0xFFEDF1F7)
                        : const Color(0xFF00E096),
                  ),
                ),
                if (activeTasks > 0)
                  Expanded(
                    flex: activeTasks,
                    child: Container(
                      height: 10,
                      color: const Color(0xFF3366FF),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  label: 'Selesai',
                  count: '$completedTasks',
                  dotColor: const Color(0xFF00E096),
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFEDF1F7)),
              Expanded(
                child: _buildMetricItem(
                  label: 'Aktif',
                  count: '$activeTasks',
                  dotColor: const Color(0xFF3366FF),
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFEDF1F7)),
              Expanded(
                child: _buildMetricItem(
                  label: 'Hari Ini',
                  count: '${todayTasks.isEmpty ? 0 : "$todayCompleted/${todayTasks.length}"}',
                  dotColor: const Color(0xFFFFAA00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDF1F7)),
            ),
            child: Row(
              children: [
                Icon(
                  completionRatio >= 0.8
                      ? Icons.check_circle_rounded
                      : (completionRatio >= 0.5 ? Icons.star_rounded : Icons.info_outline_rounded),
                  size: 16,
                  color: completionRatio >= 0.8
                      ? const Color(0xFF00E096)
                      : (completionRatio >= 0.5 ? const Color(0xFFFFAA00) : const Color(0xFF3366FF)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    totalTasks == 0
                        ? 'Buat quest pertamamu untuk mulai melacak produktivitas!'
                        : (completionRatio >= 0.8
                            ? 'Luar biasa! Sebagian besar quest telah kamu selesaikan.'
                            : (completionRatio >= 0.5
                                ? 'Bagus! Lebih dari separuh quest telah tercapai.'
                                : 'Ayo selesaikan sisa quest aktifmu hari ini!')),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF222B45),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. KARTU ANALISIS PERILAKU PENUNDAAN
  // ==========================================
  Widget _buildProcrastinationAnalysisCard() {
    final stats = _computeProcrastinationStats();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8F9BB3).withOpacity(0.08),
            blurRadius: 20,
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
              const Row(
                children: [
                  Icon(Icons.timelapse_rounded, color: Color(0xFF3366FF), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Analisis Penundaan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222B45),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF8F9BB3), size: 20),
                tooltip: 'Rincian & Tips',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showProcrastinationTipsModal(stats),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: stats.archetypeColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: stats.archetypeColor.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: stats.archetypeColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(stats.archetypeIcon, color: stats.archetypeColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              stats.archetypeTitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: stats.archetypeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${stats.disciplineScore}% Skor',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: stats.archetypeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stats.archetypeDesc,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF222B45),
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tingkat Ketepatan Waktu',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8F9BB3),
                ),
              ),
              Text(
                '${stats.disciplineScore}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: stats.archetypeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: stats.totalEvaluated == 0 ? 0.0 : (stats.disciplineScore / 100.0),
              minHeight: 10,
              backgroundColor: const Color(0xFFEDF1F7),
              color: stats.archetypeColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  label: 'Tepat Waktu',
                  count: '${stats.onTimeCount}',
                  dotColor: const Color(0xFF00E096),
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFEDF1F7)),
              Expanded(
                child: _buildMetricItem(
                  label: 'Mepet Tenggat',
                  count: '${stats.lastMinuteCount}',
                  dotColor: const Color(0xFFFFAA00),
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFEDF1F7)),
              Expanded(
                child: _buildMetricItem(
                  label: 'Terlambat',
                  count: '${stats.lateCompletedCount}',
                  dotColor: const Color(0xFFFF3D71),
                ),
              ),
            ],
          ),
          if (stats.overduePendingCount > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBF1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF3D71).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFFF3D71), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ada ${stats.overduePendingCount} quest aktif yang melewati tenggat waktu!',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF3D71),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3366FF),
                side: const BorderSide(color: Color(0xFFE4E9F2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => _showProcrastinationTipsModal(stats),
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
              label: const Text(
                'Lihat Tips & Strategi Anti-Penundaan',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProcrastinationTipsModal(_ProcrastinationAnalysis stats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF1F7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: stats.archetypeColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(stats.archetypeIcon, color: stats.archetypeColor, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Strategi Anti-Penundaan',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF222B45),
                            ),
                          ),
                          Text(
                            'Profil: ${stats.archetypeTitle}',
                            style: TextStyle(
                              fontSize: 12,
                              color: stats.archetypeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF8F9BB3)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFEDF1F7)),
              const SizedBox(height: 12),
              const Text(
                'Rekomendasi Aksi untuk Kamu:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222B45),
                ),
              ),
              const SizedBox(height: 12),
              ...stats.tips.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final tip = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBF1FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$idx',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3366FF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tip,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF222B45),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3366FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Mengerti, Saya Siap Fokus!', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // 6. KARTU MONITORING PRODUKTIVITAS HARIAN
  // ==========================================
  Widget _buildDailyProductivityMonitoringCard() {
    final stats = _computeProductivityMonitoring();
    final safeSelectedIndex = _selectedChartDayIndex.clamp(0, stats.dailyData.length - 1);
    final selectedDayData = stats.dailyData[safeSelectedIndex];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8F9BB3).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Monitoring & Filter Rentang (7 Hari vs 30 Hari)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights_rounded, color: Color(0xFF3366FF), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Monitoring Produktivitas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222B45),
                    ),
                  ),
                ],
              ),
              // Segmented Toggle Filter Rentang Hari
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEDF1F7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRangeToggleChip(7, '7H'),
                    _buildRangeToggleChip(30, '30H'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Banner Perbandingan Hari Ini vs Kemarin
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: stats.comparisonColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: stats.comparisonColor.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: stats.comparisonColor.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(stats.comparisonIcon, color: stats.comparisonColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats.comparisonText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: stats.comparisonColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hari ini: ${stats.todayCompleted} quest  •  Kemarin: ${stats.yesterdayCompleted} quest',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8F9BB3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Judul Grafik & Total Periode
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grafik Aktivitas (${stats.daysRange} Hari)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222B45),
                ),
              ),
              Text(
                '${stats.totalPeriodCompleted} Selesai • +${stats.totalPeriodXp} XP',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8F9BB3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // WIDGET GRAFIK BATANG INTERAKTIF (Hingga 30 Hari dengan Scroll)
          _buildInteractiveBarChart(stats),
          const SizedBox(height: 12),

          // Detail Hari yang Dipilih dari Grafik
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDF1F7)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note_rounded, size: 16, color: Color(0xFF3366FF)),
                    const SizedBox(width: 8),
                    Text(
                      '${selectedDayData.fullDayName}, ${selectedDayData.dateFormatted}${selectedDayData.isToday ? " (Hari Ini)" : ""}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF222B45),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: selectedDayData.completedCount > 0
                            ? const Color(0xFFE6FBF5)
                            : const Color(0xFFEDF1F7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${selectedDayData.completedCount} Quest',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: selectedDayData.completedCount > 0
                              ? const Color(0xFF00E096)
                              : const Color(0xFF8F9BB3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${selectedDayData.earnedXp} XP',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFAA00),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3 Pill Indikator Tren (Streak, Rata-rata, Hari Terbaik)
          Row(
            children: [
              Expanded(
                child: _buildTrendPill(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFFF7A00),
                  bgColor: const Color(0xFFFFF3E0),
                  value: '${stats.currentStreak} Hari',
                  label: 'Streak Aktif',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTrendPill(
                  icon: Icons.speed_rounded,
                  iconColor: const Color(0xFF3366FF),
                  bgColor: const Color(0xFFEBF1FF),
                  value: stats.averagePerDay.toStringAsFixed(1),
                  label: 'Rata-rata/Hari',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTrendPill(
                  icon: Icons.emoji_events_rounded,
                  iconColor: const Color(0xFFFFAA00),
                  bgColor: const Color(0xFFFFF8E7),
                  value: stats.bestDayName,
                  label: stats.bestDayCount > 0 ? '${stats.bestDayCount} Quest' : 'Terbanyak',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Riwayat Hari Terakhir (Expandable)
          InkWell(
            onTap: () {
              setState(() {
                _isHistoryExpanded = !_isHistoryExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDF1F7)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 18, color: Color(0xFF8F9BB3)),
                      const SizedBox(width: 8),
                      Text(
                        _isHistoryExpanded
                            ? 'Sembunyikan Riwayat Harian'
                            : 'Tampilkan Riwayat ${stats.daysRange} Hari',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF222B45),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _isHistoryExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF8F9BB3),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (_isHistoryExpanded) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: stats.dailyData.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  // Tampilkan dari hari terbaru ke terlama
                  final revIndex = stats.dailyData.length - 1 - index;
                  final day = stats.dailyData[revIndex];
                  final isSelected = revIndex == safeSelectedIndex;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedChartDayIndex = revIndex;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEBF1FF) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF3366FF).withOpacity(0.4) : const Color(0xFFEDF1F7),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: day.completedCount > 0 ? const Color(0xFF00E096) : const Color(0xFFC5CEE0),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${day.fullDayName}, ${day.dateFormatted}${day.isToday ? " (Hari Ini)" : ""}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: day.isToday ? FontWeight.bold : FontWeight.w500,
                                  color: day.isToday ? const Color(0xFF3366FF) : const Color(0xFF222B45),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '${day.completedCount} Quest',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: day.completedCount > 0 ? const Color(0xFF222B45) : const Color(0xFF8F9BB3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '+${day.earnedXp} XP',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFAA00),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Chip Toggle Pilihan Rentang Hari
  Widget _buildRangeToggleChip(int days, String label) {
    final isSelected = _selectedDaysRange == days;
    return GestureDetector(
      onTap: () {
        if (_selectedDaysRange != days) {
          setState(() {
            _selectedDaysRange = days;
            _selectedChartDayIndex = days - 1;
          });
          if (days > 7) {
            _scrollToLatest();
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3366FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF8F9BB3),
          ),
        ),
      ),
    );
  }

  // Widget Grafik Batang Interaktif (Hingga 30 Hari)
  Widget _buildInteractiveBarChart(_ProductivityMonitoringStats stats) {
    int maxVal = 3;
    for (final d in stats.dailyData) {
      if (d.completedCount > maxVal) {
        maxVal = d.completedCount;
      }
    }

    const double chartMaxHeight = 90.0;
    final isLongRange = stats.dailyData.length > 7;

    final Widget chartContent = Row(
      mainAxisAlignment: isLongRange ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: stats.dailyData.asMap().entries.map((entry) {
        final index = entry.key;
        final day = entry.value;
        final isSelected = index == _selectedChartDayIndex;

        final double barHeight = day.completedCount == 0
            ? 8.0
            : math.max(16.0, (day.completedCount / maxVal) * chartMaxHeight);

        Color barColor;
        if (isSelected) {
          barColor = const Color(0xFF3366FF);
        } else if (day.isToday) {
          barColor = const Color(0xFF3366FF).withOpacity(0.75);
        } else if (day.completedCount > 0) {
          barColor = const Color(0xFF00E096);
        } else {
          barColor = const Color(0xFFEDF1F7);
        }

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedChartDayIndex = index;
            });
          },
          child: Container(
            width: isLongRange ? 30 : 38,
            margin: isLongRange ? const EdgeInsets.symmetric(horizontal: 4) : EdgeInsets.zero,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Angka di atas batang
                Text(
                  '${day.completedCount}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF3366FF)
                        : (day.completedCount > 0 ? const Color(0xFF222B45) : const Color(0xFF8F9BB3)),
                  ),
                ),
                const SizedBox(height: 6),

                // Batang animasi
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: barHeight,
                  width: isLongRange ? 18 : 22,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF3366FF).withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 8),

                // Label Hari / Tanggal
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: isSelected
                      ? BoxDecoration(
                          color: const Color(0xFF3366FF),
                          borderRadius: BorderRadius.circular(6),
                        )
                      : null,
                  child: Text(
                    isLongRange ? '${day.date.day}' : day.dayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: (isSelected || day.isToday) ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (day.isToday ? const Color(0xFF3366FF) : const Color(0xFF8F9BB3)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );

    if (isLongRange) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            controller: _chartScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: chartContent,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swipe_left_rounded, size: 14, color: Color(0xFF8F9BB3)),
              SizedBox(width: 4),
              Text(
                'Geser grafik untuk menjelajah riwayat hingga 30 hari',
                style: TextStyle(fontSize: 10, color: Color(0xFF8F9BB3), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: chartContent,
    );
  }

  // Widget Pill Indikator Tren
  Widget _buildTrendPill({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222B45),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF222B45).withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String count,
    required Color dotColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8F9BB3),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          count,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF222B45),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 7. KARTU ANALISIS KESEHATAN & KEBIASAAN
  // ==========================================
  Widget _buildHealthHabitAnalyticsCard() {
    final totalHealth = _healthTargets.length;
    final completedHealth = _healthTargets.where((t) => t['is_completed'] == true).length;
    final double healthRatio = totalHealth > 0 ? (completedHealth / totalHealth) : 0.0;
    final int healthPercentage = (healthRatio * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8F9BB3).withOpacity(0.08),
            blurRadius: 20,
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
              const Row(
                children: [
                  Icon(Icons.health_and_safety_rounded, color: Color(0xFFFF3D71), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Target Sehat Hari Ini',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222B45),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBF1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$healthPercentage% Tercapai',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF3D71),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: healthRatio,
              minHeight: 10,
              backgroundColor: const Color(0xFFEDF1F7),
              color: const Color(0xFFFF3D71),
            ),
          ),
          const SizedBox(height: 16),
          if (_healthTargets.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: const Text(
                'Belum ada target kesehatan hari ini.\nAtur target di menu Kesehatan!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF8F9BB3)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _healthTargets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final target = _healthTargets[index];
                final title = target['title']?.toString() ?? 'Target';
                final isCompleted = target['is_completed'] == true;
                final currentValue = target['current_value'] ?? 0;
                final targetValue = target['target_value'] ?? 1;
                final unit = target['unit']?.toString() ?? '';

                final double itemProgress = targetValue > 0
                    ? ((currentValue as num) / (targetValue as num)).clamp(0.0, 1.0)
                    : (isCompleted ? 1.0 : 0.0);

                final iconData = _getHealthIcon(title);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCompleted ? const Color(0xFF00E096).withOpacity(0.3) : const Color(0xFFEDF1F7),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCompleted ? const Color(0xFFE6FBF5) : const Color(0xFFEDF1F7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          iconData,
                          size: 16,
                          color: isCompleted ? const Color(0xFF00E096) : const Color(0xFF8F9BB3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted ? const Color(0xFF8F9BB3) : const Color(0xFF222B45),
                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                Text(
                                  '$currentValue / $targetValue $unit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isCompleted ? const Color(0xFF00E096) : const Color(0xFF8F9BB3),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: itemProgress,
                                minHeight: 4,
                                backgroundColor: const Color(0xFFE4E9F2),
                                color: isCompleted ? const Color(0xFF00E096) : const Color(0xFFFF7A00),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isCompleted ? const Color(0xFF00E096) : const Color(0xFFC5CEE0),
                        size: 20,
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  IconData _getHealthIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('minum') || lower.contains('air') || lower.contains('water')) {
      return Icons.water_drop_rounded;
    }
    if (lower.contains('tidur') || lower.contains('sleep') || lower.contains('istirahat')) {
      return Icons.bedtime_rounded;
    }
    if (lower.contains('pomodoro') || lower.contains('fokus') || lower.contains('belajar') || lower.contains('kerja')) {
      return Icons.timer_rounded;
    }
    if (lower.contains('olahraga') || lower.contains('lari') || lower.contains('jalan') || lower.contains('workout')) {
      return Icons.fitness_center_rounded;
    }
    return Icons.favorite_rounded;
  }

  // ==========================================
  // 8. WIDGET RAK LENCANA (BADGES)
  // ==========================================
  Widget _buildBadgesSection() {
    List<dynamic> badges = _userProfile?['badges'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Koleksi Lencana',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222B45),
                letterSpacing: -0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${badges.length} Diraih',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFAA00),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        badges.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEDF1F7)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada lencana',
                      style: TextStyle(color: Color(0xFF8F9BB3), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Selesaikan quest & kebiasaan sehat untuk mendapatkannya!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8F9BB3), fontSize: 12),
                    ),
                  ],
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.85,
                ),
                itemCount: badges.length,
                itemBuilder: (context, index) {
                  final badge = badges[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEDF1F7)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8F9BB3).withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF3D6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xFFFFAA00),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            badge['badge_name'] ?? 'Lencana',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF222B45),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }
}
