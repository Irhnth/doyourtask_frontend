import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart'; 
import 'leaderboard_screen.dart';
import 'health_screen.dart'; 
import 'challenge_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _userProfile;
  List<dynamic> _tasks = [];
  Map<String, dynamic>? _challengeData;
  bool _isLoading = true;

  // Filter Tugas: 'all', 'pending', 'completed'
  String _taskFilter = 'all';

  // Variabel untuk Kalender
  DateTime _selectedDate = DateTime.now();
  final int _daysPast = 365; 
  final int _daysFuture = 365; 
  late ScrollController _calendarScrollController;

  final List<String> _idDayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  final List<String> _idMonthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _calendarScrollController = ScrollController(initialScrollOffset: _daysPast * 72.0);
    _loadData();
  }

  @override
  void dispose() {
    _calendarScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getTasks(),
        _apiService.getActiveChallenge().catchError((_) => <String, dynamic>{}),
      ]);
      
      if (mounted) {
        setState(() {
          _userProfile = results[0] as Map<String, dynamic>?;
          _tasks = results[1] as List<dynamic>;
          _challengeData = results[2] as Map<String, dynamic>?;
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
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) {
      return 'Selamat Pagi ☀️';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat Siang 🌤️';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat Sore 🌅';
    } else {
      return 'Selamat Malam 🌙';
    }
  }

  int _getTaskCountForDate(DateTime date) {
    return _tasks.where((task) {
      if (task['deadline'] == null) return false;
      try {
        final dt = DateTime.parse(task['deadline'].toString());
        return _isSameDay(dt, date);
      } catch (_) {
        return false;
      }
    }).length;
  }

  bool _areAllTasksCompletedForDate(DateTime date) {
    final dayTasks = _tasks.where((task) {
      if (task['deadline'] == null) return false;
      try {
        final dt = DateTime.parse(task['deadline'].toString());
        return _isSameDay(dt, date);
      } catch (_) {
        return false;
      }
    }).toList();

    if (dayTasks.isEmpty) return false;
    return dayTasks.every((task) => task['status'] == 'completed');
  }

  void _jumpToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    if (_calendarScrollController.hasClients) {
      _calendarScrollController.animateTo(
        _daysPast * 72.0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _completeTask(int taskId) async {
    try {
      final result = await _apiService.completeTask(taskId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result['message'] ?? 'Quest Selesai! XP telah ditambahkan.',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ), 
            backgroundColor: const Color(0xFF1E2638),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 3),
          ),
        );

        if (result['is_level_up'] == true) {
          _showLevelUpDialog(result['new_level']);
        }
        _loadData();
      }
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

  void _confirmDeleteTask(int taskId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Hapus Quest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF222B45))),
          ],
        ),
        content: Text('Yakin ingin menghapus quest "$title"? Aksi ini tidak dapat dibatalkan.', style: const TextStyle(color: Color(0xFF6C7A9C), fontSize: 14)),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF8F9BB3), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context); 
              try {
                await _apiService.deleteTask(taskId);
                await NotificationService().cancelNotification(taskId);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Quest berhasil dihapus'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Hapus'),
          )
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFECEC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Keluar Akun?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF222B45))),
          ],
        ),
        content: const Text(
          'Anda harus login kembali untuk mengakses quest dan riwayat petualangan Anda.',
          style: TextStyle(color: Color(0xFF6C7A9C), fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF8F9BB3), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _apiService.logout();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
            child: const Text('Keluar'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter tugas berdasarkan tanggal yang dipilih
    final tasksForSelectedDate = _tasks.where((task) {
      if (task['deadline'] == null) return false;
      try {
        final taskDate = DateTime.parse(task['deadline'].toString());
        return _isSameDay(taskDate, _selectedDate);
      } catch (e) {
        return false;
      }
    }).toList();

    // Filter berdasarkan status filter tab
    final filteredTasks = tasksForSelectedDate.where((task) {
      if (_taskFilter == 'completed') return task['status'] == 'completed';
      if (_taskFilter == 'pending') return task['status'] != 'completed';
      return true;
    }).toList();

    final pendingCount = tasksForSelectedDate.where((t) => t['status'] != 'completed').length;
    final completedCount = tasksForSelectedDate.where((t) => t['status'] == 'completed').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF3366FF)))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: const Color(0xFF3366FF),
                child: ListView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // 1. Header (User Info + Shortcut Action Buttons)
                    _buildHeader(),
                    const SizedBox(height: 20),

                    // 2. Gamification Hero Card (Experience, Level, Progress Bar & Mini Stats)
                    _buildGamificationCard(
                      todayTotal: tasksForSelectedDate.length,
                      todayCompleted: completedCount,
                    ),
                    const SizedBox(height: 16),

                    // 3. Tantangan 28 Hari Banner Card
                    _buildChallengeBannerCard(),
                    const SizedBox(height: 16),

                    // 4. Akses Cepat Fitur (Quick Action Hub)
                    _buildQuickActionHub(),
                    const SizedBox(height: 24),

                    // 5. Interactive Calendar Timeline
                    _buildCalendarSection(),
                    const SizedBox(height: 24),

                    // 6. Section Header & Filter Chips
                    _buildTaskSectionHeader(
                      totalCount: tasksForSelectedDate.length,
                      pendingCount: pendingCount,
                      completedCount: completedCount,
                    ),
                    const SizedBox(height: 14),

                    // 7. Quest List / Empty State
                    filteredTasks.isEmpty 
                        ? _buildEmptyState(totalCount: tasksForSelectedDate.length) 
                        : _buildTaskList(filteredTasks),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskModal,
        backgroundColor: const Color(0xFF3366FF),
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text('Quest Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  // ==========================================
  // 1. HEADER (ANTI-OVERFLOW & MODERN)
  // ==========================================
  Widget _buildHeader() {
    final userName = _userProfile?['name']?.toString() ?? 'Petualang';
    final initial = userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U';

    return Row(
      children: [
        // Avatar dengan Border & Tap ke Profil
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())).then((_) => _loadData());
          },
          child: Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF3366FF), Color(0xFF00E096)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3366FF).withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: CircleAvatar(
              radius: 23,
              backgroundColor: Colors.white,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3366FF),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Sapaan & Nama Pengguna (Dengan Expanded agar aman di semua ukuran layar)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getGreeting(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8F9BB3),
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222B45),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Action Buttons Row (Leaderboard, Health, Logout)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TOMBOL: Papan Peringkat (Leaderboard)
            _buildHeaderIconButton(
              icon: Icons.emoji_events_rounded,
              iconColor: const Color(0xFFFFAA00),
              tooltip: 'Papan Peringkat',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardScreen()));
              },
            ),
            const SizedBox(width: 8),

            // TOMBOL: Target Kesehatan
            _buildHeaderIconButton(
              icon: Icons.favorite_rounded,
              iconColor: const Color(0xFFFF3D71),
              tooltip: 'Target Kesehatan',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const HealthScreen()));
              },
            ),
            const SizedBox(width: 8),

            // TOMBOL: Logout dengan dialog konfirmasi
            _buildHeaderIconButton(
              icon: Icons.logout_rounded,
              iconColor: const Color(0xFF8F9BB3),
              tooltip: 'Keluar',
              onPressed: _confirmLogout,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE4E9F2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8F9BB3).withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 20),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        splashRadius: 20,
        onPressed: onPressed,
      ),
    );
  }

  // ==========================================
  // 2. GAMIFICATION HERO CARD (LEVEL & PROGRESS)
  // ==========================================
  Widget _buildGamificationCard({required int todayTotal, required int todayCompleted}) {
    final currentXp = (_userProfile?['current_xp'] is num) ? (_userProfile!['current_xp'] as num).toInt() : 0;
    final nextLevelXp = (_userProfile?['next_level_xp_required'] is num)
        ? (_userProfile!['next_level_xp_required'] as num).toInt()
        : null;

    double progress = 1.0;
    int remainingXp = 0;
    if (nextLevelXp != null && nextLevelXp > 0) {
      progress = (currentXp / nextLevelXp).clamp(0.0, 1.0);
      remainingXp = (nextLevelXp - currentXp).clamp(0, 999999);
    }

    final levelName = _userProfile?['level']?['level_name']?.toString() ?? '1';
    final streak = _challengeData?['progress']?['current_streak'] ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2337), Color(0xFF111524)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF131726).withOpacity(0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Glow Ornaments
          Positioned(
            top: -25,
            right: -25,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3366FF).withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFAA00).withOpacity(0.08),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Level Tag & Rank Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.military_tech_rounded, color: Color(0xFFFFC94D), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Level $levelName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E096).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, color: Color(0xFF00E096), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Aktif',
                            style: TextStyle(
                              color: Color(0xFF00E096),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Total XP Label & Value
                const Text(
                  'TOTAL PENGALAMAN',
                  style: TextStyle(
                    color: Color(0xFF8F9BB3),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      NumberFormat('#,###').format(currentXp),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'XP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFC94D),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Level Progress Indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          nextLevelXp != null ? 'Kemajuan Level' : 'Tingkat Maksimal',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          nextLevelXp != null
                              ? '$currentXp / $nextLevelXp XP (${(progress * 100).toInt()}%)'
                              : 'Level Tertinggi 👑',
                          style: const TextStyle(
                            color: Color(0xFFFFC94D),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: Colors.white.withOpacity(0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
                      ),
                    ),
                    if (nextLevelXp != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Butuh $remainingXp XP lagi untuk naik ke level selanjutnya',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),

                // Mini Stats Divider & Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMiniStat(
                          icon: Icons.checklist_rounded,
                          iconColor: const Color(0xFF3366FF),
                          label: 'Hari Ini',
                          value: '$todayTotal Quest',
                        ),
                      ),
                      Container(width: 1, height: 26, color: Colors.white.withOpacity(0.1)),
                      Expanded(
                        child: _buildMiniStat(
                          icon: Icons.check_circle_rounded,
                          iconColor: const Color(0xFF00E096),
                          label: 'Tuntas',
                          value: '$todayCompleted Quest',
                        ),
                      ),
                      Container(width: 1, height: 26, color: Colors.white.withOpacity(0.1)),
                      Expanded(
                        child: _buildMiniStat(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: const Color(0xFFFF7043),
                          label: 'Streak',
                          value: '$streak Hari',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. TANTANGAN 28 HARI BANNER CARD
  // ==========================================
  Widget _buildChallengeBannerCard() {
    final hasActive = _challengeData != null && _challengeData!['has_active_challenge'] == true;
    final progress = hasActive ? _challengeData!['progress'] as Map<String, dynamic>? : null;
    final currentDay = progress?['current_day'] ?? 1;
    final streak = progress?['current_streak'] ?? 0;
    final percentage = progress?['progress_percentage'] ?? 0;
    final isTodayCompleted = progress?['is_today_completed'] == true;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChallengeScreen()),
        ).then((_) => _loadData());
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: hasActive
                ? [const Color(0xFF2E5BFF), const Color(0xFF1738C2)]
                : [const Color(0xFF2E3A59), const Color(0xFF1E2638)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: (hasActive ? const Color(0xFF2E5BFF) : const Color(0xFF2E3A59)).withOpacity(0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Center(
                child: Icon(
                  hasActive ? Icons.workspace_premium_rounded : Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        hasActive ? 'Tantangan 28 Hari' : 'Mulai Tantangan 28 Hari',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (hasActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                '$streak',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasActive
                        ? (isTodayCompleted
                            ? 'Hari $currentDay/28 • Misi hari ini selesai! ✅'
                            : 'Hari $currentDay/28 • Misi hari ini siap dijalankan! ⚡')
                        : 'Bentuk kebiasaan produktif & dapatkan +1400 XP',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                    ),
                  ),
                  if (hasActive) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (percentage / 100.0).clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E096)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. AKSES CEPAT FITUR (QUICK ACTION HUB)
  // ==========================================
  Widget _buildQuickActionHub() {
    return Row(
      children: [
        // 1. Target Kesehatan & Langkah
        Expanded(
          child: _buildHubCard(
            title: 'Kesehatan',
            subtitle: 'Air & Langkah',
            icon: Icons.health_and_safety_rounded,
            iconColor: const Color(0xFF00E096),
            bgColor: const Color(0xFFE8FAF3),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HealthScreen()));
            },
          ),
        ),
        const SizedBox(width: 10),

        // 2. Papan Peringkat
        Expanded(
          child: _buildHubCard(
            title: 'Peringkat',
            subtitle: 'Top Petualang',
            icon: Icons.emoji_events_rounded,
            iconColor: const Color(0xFFFFAA00),
            bgColor: const Color(0xFFFFF7E6),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardScreen()));
            },
          ),
        ),
        const SizedBox(width: 10),

        // 3. Analisis Profil
        Expanded(
          child: _buildHubCard(
            title: 'Statistik',
            subtitle: 'Pola Kebiasaan',
            icon: Icons.insights_rounded,
            iconColor: const Color(0xFF3366FF),
            bgColor: const Color(0xFFEEF3FF),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())).then((_) => _loadData());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHubCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDF2F7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8F9BB3).withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF222B45),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8F9BB3),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 5. KALENDER TIMELINE (INTERAKTIF & INDIKATOR)
  // ==========================================
  Widget _buildCalendarSection() {
    final monthYearString = '${_idMonthNames[_selectedDate.month - 1]} ${_selectedDate.year}';
    final isTodaySelected = _isSameDay(_selectedDate, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bar Judul Bulan & Tombol Hari Ini
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: Color(0xFF3366FF), size: 18),
                const SizedBox(width: 8),
                Text(
                  monthYearString,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222B45),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (!isTodaySelected)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: const Color(0xFF3366FF),
                    ),
                    icon: const Icon(Icons.today_rounded, size: 16),
                    label: const Text('Hari Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _jumpToToday,
                  ),
                IconButton(
                  icon: const Icon(Icons.date_range_rounded, color: Color(0xFF3366FF), size: 22),
                  tooltip: 'Pilih Tanggal',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000), 
                      lastDate: DateTime(2100), 
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                        final difference = date.difference(DateTime.now().subtract(Duration(days: _daysPast))).inDays;
                        if (difference >= 0 && difference <= (_daysPast + _daysFuture)) {
                          _calendarScrollController.animateTo(
                            difference * 72.0, 
                            duration: const Duration(milliseconds: 500), 
                            curve: Curves.easeInOutCubic,
                          );
                        }
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Strip Kartu Tanggal Horizontal
        SizedBox(
          height: 86,
          child: ListView.builder(
            controller: _calendarScrollController, 
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _daysPast + _daysFuture + 1,
            itemBuilder: (context, index) {
              final date = DateTime.now().subtract(Duration(days: _daysPast)).add(Duration(days: index));
              final isSelected = _isSameDay(date, _selectedDate);
              final isToday = _isSameDay(date, DateTime.now());
              
              final dayName = _idDayNames[date.weekday - 1]; 
              final dayNumber = DateFormat('d').format(date); 

              final taskCount = _getTaskCountForDate(date);
              final allCompleted = taskCount > 0 && _areAllTasksCompletedForDate(date);

              return GestureDetector(
                onTap: () {
                  setState(() { _selectedDate = date; });
                },
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF3366FF) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFF3366FF) 
                          : (isToday ? const Color(0xFF3366FF).withOpacity(0.5) : const Color(0xFFEDF2F7)),
                      width: isToday && !isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF3366FF).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            )
                          ]
                        : [
                            BoxShadow(
                              color: const Color(0xFF8F9BB3).withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white.withOpacity(0.85) : const Color(0xFF8F9BB3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dayNumber,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF222B45),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Indikator Titik Ada Quest
                      if (taskCount > 0)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Colors.white
                                : (allCompleted ? const Color(0xFF00E096) : const Color(0xFF3366FF)),
                          ),
                        )
                      else
                        const SizedBox(height: 5),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 6. SECTION HEADER & FILTER CHIPS
  // ==========================================
  Widget _buildTaskSectionHeader({
    required int totalCount,
    required int pendingCount,
    required int completedCount,
  }) {
    final isToday = _isSameDay(DateTime.now(), _selectedDate);
    final dateLabel = isToday
        ? 'Quest Hari Ini'
        : 'Quest ${_selectedDate.day} ${_idMonthNames[_selectedDate.month - 1]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222B45),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3366FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalCount',
                    style: const TextStyle(
                      color: Color(0xFF3366FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Filter Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Semua',
                count: totalCount,
                isSelected: _taskFilter == 'all',
                onTap: () => setState(() => _taskFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Tertunda',
                count: pendingCount,
                isSelected: _taskFilter == 'pending',
                activeColor: const Color(0xFFFF9500),
                onTap: () => setState(() => _taskFilter = 'pending'),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Selesai',
                count: completedCount,
                isSelected: _taskFilter == 'completed',
                activeColor: const Color(0xFF00E096),
                onTap: () => setState(() => _taskFilter = 'completed'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    Color activeColor = const Color(0xFF3366FF),
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE4E9F2),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF6C7A9C),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.25) : const Color(0xFFF0F3F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF8F9BB3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 7. TASK LIST & CARDS (PREMIUM & RESPONSIVE)
  // ==========================================
  Widget _buildTaskList(List<dynamic> targetList) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: targetList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final task = targetList[index];
        final isCompleted = task['status'] == 'completed';

        String formattedDeadline = '';
        bool isOverdue = false;
        if (task['deadline'] != null) {
          try {
            final dt = DateTime.parse(task['deadline'].toString());
            formattedDeadline = DateFormat('HH:mm').format(dt); 
            if (!isCompleted && dt.isBefore(DateTime.now())) {
              isOverdue = true;
            }
          } catch (_) {}
        }

        final description = task['description']?.toString() ?? '';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCompleted ? const Color(0xFFE4F9F2) : const Color(0xFFEDF2F7),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8F9BB3).withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showTaskDetailsModal(task),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Checkbox Selesai
                    GestureDetector(
                      onTap: isCompleted ? null : () => _completeTask(task['id']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted ? const Color(0xFF00E096) : Colors.transparent,
                          border: Border.all(
                            color: isCompleted ? const Color(0xFF00E096) : const Color(0xFFC5CEE0),
                            width: 2,
                          ),
                          boxShadow: isCompleted
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00E096).withOpacity(0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: isCompleted
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Detail Tugas
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['title'] ?? 'Quest Tanpa Judul',
                            style: TextStyle(
                              fontSize: 15,
                              color: isCompleted ? const Color(0xFF8F9BB3) : const Color(0xFF222B45),
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (description.isNotEmpty && !isCompleted) ...[
                            const SizedBox(height: 3),
                            Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8F9BB3),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),

                          // Badges Row (XP Reward, Deadline, Overdue)
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // XP Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7E6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFFD591).withOpacity(0.6)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, color: Color(0xFFFFAA00), size: 13),
                                    const SizedBox(width: 3),
                                    Text(
                                      '+${task['reward_xp']} XP',
                                      style: const TextStyle(
                                        color: Color(0xFFD48806),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Waktu Tenggat
                              if (formattedDeadline.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time_rounded, color: Color(0xFF8F9BB3), size: 13),
                                    const SizedBox(width: 4),
                                    Text(
                                      formattedDeadline,
                                      style: const TextStyle(
                                        color: Color(0xFF8F9BB3),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),

                              // Alert Terlewat
                              if (isOverdue)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFECEC),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Terlewat',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Trailing Detail Chevron
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFC5CEE0), size: 22),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 8. EMPTY STATE (RAMAH & MODERN)
  // ==========================================
  Widget _buildEmptyState({required int totalCount}) {
    String title = 'Tidak Ada Quest';
    String message = 'Tidak ada quest pada tanggal ini.\nKetuk tombol di bawah untuk menambah yang baru.';

    if (totalCount > 0) {
      if (_taskFilter == 'pending') {
        title = 'Semua Selesai! 🎉';
        message = 'Hebat! Semua quest pada tanggal ini telah kamu tuntaskan.';
      } else if (_taskFilter == 'completed') {
        title = 'Belum Ada yang Selesai';
        message = 'Tuntaskan quest kamu untuk mendapatkan XP & naik level!';
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF3FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD6E4FF)),
              ),
              child: const Icon(
                Icons.assignment_turned_in_rounded,
                size: 54,
                color: Color(0xFF3366FF),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222B45),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8F9BB3),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3366FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _showAddTaskModal,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Buat Quest Baru', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 9. DIALOG & BOTTOM SHEET MODALS
  // ==========================================
  void _showLevelUpDialog(dynamic newLevel) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF7E6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.military_tech_rounded, size: 68, color: Color(0xFFFFB800)),
              ),
              const SizedBox(height: 20),
              const Text(
                'LEVEL UP!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF222B45),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keren! Kemampuanmu meningkat pesat. Kamu sekarang berada di Level $newLevel.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF8F9BB3), height: 1.4),
              ),
              const SizedBox(height: 26),
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Lanjut Berpetualang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskDetailsModal(Map<String, dynamic> task) {
    final isCompleted = task['status'] == 'completed';
    String formattedDeadline = task['deadline'] ?? '-';
    try {
      final dt = DateTime.parse(task['deadline'].toString());
      formattedDeadline = DateFormat('dd MMM yyyy, HH:mm').format(dt); 
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF1F7),
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
                      color: isCompleted ? const Color(0xFFE5F9F1) : const Color(0xFFE5F0FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isCompleted ? 'Quest Selesai ✅' : 'Sedang Berlangsung ⚡',
                      style: TextStyle(
                        color: isCompleted ? const Color(0xFF00E096) : const Color(0xFF3366FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (!isCompleted)
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: Color(0xFF8F9BB3)),
                          tooltip: 'Edit',
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditTaskModal(task);
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        tooltip: 'Hapus',
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmDeleteTask(task['id'], task['title']);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                task['title'] ?? 'Quest',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222B45),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3D6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${task['reward_xp']} XP Reward',
                      style: const TextStyle(
                        color: Color(0xFFFFAA00),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEDF2F7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: Color(0xFF3366FF), size: 18),
                    const SizedBox(width: 12),
                    Text(
                      formattedDeadline,
                      style: const TextStyle(
                        color: Color(0xFF222B45),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Deskripsi & Catatan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF222B45))),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEDF2F7)),
                ),
                child: Text(
                  (task['description'] == null || task['description'].toString().trim().isEmpty)
                      ? 'Tidak ada catatan tambahan untuk quest ini.'
                      : task['description'],
                  style: const TextStyle(color: Color(0xFF6C7A9C), fontSize: 14, height: 1.5),
                ),
              ),
              const SizedBox(height: 28),

              // Tombol Tandai Selesai jika belum selesai
              if (!isCompleted)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E096),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _completeTask(task['id']);
                    },
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text('Tandai Selesai (+XP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showAddTaskModal() {
    _buildTaskFormModal(isEdit: false);
  }

  void _showEditTaskModal(Map<String, dynamic> task) {
    _buildTaskFormModal(isEdit: true, task: task);
  }

  void _buildTaskFormModal({required bool isEdit, Map<String, dynamic>? task}) {
    final titleController = TextEditingController(text: isEdit ? task!['title'] : '');
    final descriptionController = TextEditingController(text: isEdit ? (task!['description'] ?? '') : ''); 
    DateTime? selectedDate = _selectedDate; 
    TimeOfDay? selectedTime;
    
    if (isEdit && task!['deadline'] != null) {
      try {
        final dt = DateTime.parse(task['deadline'].toString());
        selectedDate = dt;
        selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      } catch (_) {}
    } else {
      // Default waktu tenggat 1 jam dari sekarang
      final now = DateTime.now().add(const Duration(hours: 1));
      selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
    }

    int selectedReminderOffset = 10; 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
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
                        color: const Color(0xFFEDF1F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isEdit ? 'Edit Quest' : 'Buat Quest Baru',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF222B45),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Judul Quest / Target Tugas',
                      hintText: 'Misal: Belajar UI Design Flutter',
                      filled: true,
                      fillColor: const Color(0xFFF7F9FC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF3366FF), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descriptionController,
                    maxLines: 2, 
                    decoration: InputDecoration(
                      labelText: 'Catatan atau Rincian (Opsional)',
                      hintText: 'Tambahkan detail tugas...',
                      filled: true,
                      fillColor: const Color(0xFFF7F9FC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF3366FF), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: const BorderSide(color: Color(0xFFE4E9F2)),
                          ),
                          icon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF3366FF)),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) setModalState(() => selectedDate = date);
                          },
                          label: Text(
                            selectedDate == null ? 'Pilih Tanggal' : DateFormat('dd MMM yyyy').format(selectedDate!),
                            style: const TextStyle(color: Color(0xFF222B45), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: const BorderSide(color: Color(0xFFE4E9F2)),
                          ),
                          icon: const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF3366FF)),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime ?? TimeOfDay.now(),
                            );
                            if (time != null) setModalState(() => selectedTime = time);
                          },
                          label: Text(
                            selectedTime == null ? 'Pilih Waktu' : selectedTime!.format(context),
                            style: const TextStyle(color: Color(0xFF222B45), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: selectedReminderOffset,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8F9BB3)),
                    decoration: InputDecoration(
                      labelText: 'Pengingat Otomatis',
                      prefixIcon: const Icon(Icons.notifications_active_rounded, color: Color(0xFF3366FF), size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF7F9FC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Tepat saat tenggat tiba')),
                      DropdownMenuItem(value: 5, child: Text('5 Menit Sebelumnya')),
                      DropdownMenuItem(value: 10, child: Text('10 Menit Sebelumnya')),
                      DropdownMenuItem(value: 30, child: Text('30 Menit Sebelumnya')),
                      DropdownMenuItem(value: 60, child: Text('1 Jam Sebelumnya')),
                    ],
                    onChanged: (value) => setModalState(() => selectedReminderOffset = value!),
                  ),
                  const SizedBox(height: 26),
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
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty || selectedDate == null || selectedTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Silakan lengkapi judul, tanggal, dan waktu quest.')),
                          );
                          return;
                        }

                        final deadline = DateTime(
                          selectedDate!.year,
                          selectedDate!.month,
                          selectedDate!.day,
                          selectedTime!.hour,
                          selectedTime!.minute,
                        );
                        final formattedDeadline = DateFormat('yyyy-MM-dd HH:mm:ss').format(deadline);
                        final reminderTime = deadline.subtract(Duration(minutes: selectedReminderOffset));

                        try {
                          int targetId;
                          if (isEdit) {
                            await _apiService.updateTask(
                              task!['id'],
                              titleController.text.trim(),
                              formattedDeadline,
                              description: descriptionController.text.trim(),
                            );
                            targetId = task['id'];
                            await NotificationService().cancelNotification(targetId);
                          } else {
                            final result = await _apiService.createTask(
                              titleController.text.trim(),
                              formattedDeadline,
                              description: descriptionController.text.trim(),
                            );
                            targetId = result['task']?['id'] ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
                          }
                          
                          if (!reminderTime.isBefore(DateTime.now())) {
                            await NotificationService().scheduleNotification(
                              id: targetId,
                              title: 'Peringatan Quest!',
                              body: 'Quest "${titleController.text.trim()}" akan segera berakhir!',
                              scheduledTime: reminderTime,
                            );
                          }

                          if (mounted) {
                            Navigator.pop(context); 
                            _loadData(); 
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                      child: Text(
                        isEdit ? 'Simpan Perubahan' : 'Buat Quest Baru',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
}