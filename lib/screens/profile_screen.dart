import 'package:flutter/material.dart';
import '../services/api_service.dart';

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

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getTasks().catchError((_) => <dynamic>[]),
        _apiService.getTodayHealthProgress().catchError((_) => <dynamic>[]),
        _apiService.getLeaderboard().catchError((_) => <dynamic>[]),
      ]);

      if (mounted) {
        setState(() {
          _userProfile = results[0] as Map<String, dynamic>?;
          _tasks = results[1] as List<dynamic>;
          _healthTargets = results[2] as List<dynamic>;
          _leaderboard = results[3] as List<dynamic>;
          _isLoading = false;
        });
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
          // Chips status singkat
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
          // Bar perbandingan visual
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
          // 3 Kolom Metrik
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
          // Status motivasi
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
  // 5. KARTU ANALISIS KESEHATAN & KEBIASAAN
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
  // 6. WIDGET RAK LENCANA (BADGES)
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