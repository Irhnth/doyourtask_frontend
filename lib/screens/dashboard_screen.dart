import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'package:intl/intl.dart';
import 'profile_screen.dart'; 
import 'leaderboard_screen.dart';
import 'health_screen.dart'; // Import layar kesehatan baru

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _userProfile;
  List<dynamic> _tasks = [];
  bool _isLoading = true;

  // Variabel untuk Kalender
  DateTime _selectedDate = DateTime.now();
  final int _daysPast = 365; 
  final int _daysFuture = 365; 
  late ScrollController _calendarScrollController;

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

  // Fungsi load data (tanpa memanggil API kesehatan lagi di sini)
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _apiService.getUserProfile(),
        _apiService.getTasks(),
      ]);
      
      if (mounted) {
        setState(() {
          _userProfile = results[0] as Map<String, dynamic>?;
          _tasks = results[1] as List<dynamic>;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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

  void _completeTask(int taskId) async {
    try {
      final result = await _apiService.completeTask(taskId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber),
                const SizedBox(width: 10),
                Text(result['message'] ?? 'Quest Selesai!', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ), 
            backgroundColor: const Color(0xFF2E3A59),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _confirmDeleteTask(int taskId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Quest?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Yakin ingin menghapus "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(context); 
              try {
                await _apiService.deleteTask(taskId);
                await NotificationService().cancelNotification(taskId);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quest dihapus'), backgroundColor: Colors.redAccent));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Hapus'),
          )
        ],
      ),
    );
  }

  void _logout() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _tasks.where((task) {
      if (task['deadline'] == null) return false;
      try {
        final taskDate = DateTime.parse(task['deadline'].toString());
        return _isSameDay(taskDate, _selectedDate);
      } catch (e) {
        return false;
      }
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF3366FF)))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: const Color(0xFF3366FF),
                child: ListView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildGamificationCard(),
                    const SizedBox(height: 28),
                    
                    _buildCalendarTimeline(),
                    const SizedBox(height: 28),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isSameDay(DateTime.now(), _selectedDate)
                              ? 'Tugas Hari Ini'
                              : 'Tugas ${DateFormat('dd MMM yyyy').format(_selectedDate)}', 
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF222B45), letterSpacing: -0.5)
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF3366FF)),
                          tooltip: 'Pilih Tanggal',
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
                                if(difference >= 0 && difference <= (_daysPast + _daysFuture)) {
                                  _calendarScrollController.animateTo(
                                    difference * 72.0, 
                                    duration: const Duration(milliseconds: 500), 
                                    curve: Curves.easeInOut
                                  );
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    filteredTasks.isEmpty ? _buildEmptyState() : _buildTaskList(filteredTasks),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskModal,
        backgroundColor: const Color(0xFF3366FF),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())).then((_) => _loadData());
              },
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE4E9F2), width: 2)),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Text(
                    _userProfile?['name']?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3366FF)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selamat datang,', style: TextStyle(fontSize: 13, color: Color(0xFF8F9BB3), fontWeight: FontWeight.w500)),
                Text(_userProfile?['name'] ?? 'Pengguna', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF222B45), letterSpacing: -0.5)),
              ],
            ),
          ],
        ),
        Row(
          children: [
            // TOMBOL: Target Kesehatan
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE4E9F2))),
              child: IconButton(
                icon: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF00E096), size: 20),
                tooltip: 'Target Kesehatan',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HealthScreen()));
                },
              ),
            ),
            const SizedBox(width: 8),
            // TOMBOL: Leaderboard
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE4E9F2))),
              child: IconButton(
                icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFC94D), size: 20),
                tooltip: 'Papan Peringkat',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardScreen()));
                },
              ),
            ),
            const SizedBox(width: 8),
            // TOMBOL: Logout
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE4E9F2))),
              child: IconButton(icon: const Icon(Icons.logout_rounded, color: Color(0xFF8F9BB3), size: 20), onPressed: _logout),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGamificationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF222B45),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF222B45).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text('Level ${_userProfile?['level']?['level_name'] ?? '1'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const Icon(Icons.military_tech_rounded, color: Color(0xFFFFC94D), size: 28),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Total Experience', style: TextStyle(color: Color(0xFF8F9BB3), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_userProfile?['current_xp'] ?? 0}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, height: 1.0)),
              const SizedBox(width: 6),
              const Padding(padding: EdgeInsets.only(bottom: 4), child: Text('XP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFFC94D)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarTimeline() {
    return SizedBox(
      height: 86,
      child: ListView.builder(
        controller: _calendarScrollController, 
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _daysPast + _daysFuture + 1,
        itemBuilder: (context, index) {
          final date = DateTime.now().subtract(Duration(days: _daysPast)).add(Duration(days: index));
          final isSelected = _isSameDay(date, _selectedDate);
          
          final dayName = DateFormat('E').format(date); 
          final dayNumber = DateFormat('d').format(date); 

          return GestureDetector(
            onTap: () {
              setState(() { _selectedDate = date; });
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3366FF) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? const Color(0xFF3366FF) : const Color(0xFFEDF1F7)),
                boxShadow: isSelected
                    ? [BoxShadow(color: const Color(0xFF3366FF).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                    : [BoxShadow(color: const Color(0xFF8F9BB3).withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(dayName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white.withOpacity(0.8) : const Color(0xFF8F9BB3))),
                  const SizedBox(height: 6),
                  Text(dayNumber, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF222B45))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

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
        if (task['deadline'] != null) {
          try {
            final dt = DateTime.parse(task['deadline'].toString());
            formattedDeadline = DateFormat('HH:mm').format(dt); 
          } catch (e) {}
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEDF1F7)),
            boxShadow: [BoxShadow(color: const Color(0xFF8F9BB3).withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 4))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showTaskDetailsModal(task),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: isCompleted ? null : () => _completeTask(task['id']),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted ? const Color(0xFF00E096) : Colors.transparent,
                          border: Border.all(color: isCompleted ? const Color(0xFF00E096) : const Color(0xFFC5CEE0), width: 2),
                        ),
                        child: isCompleted ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task['title'], style: TextStyle(fontSize: 16, color: isCompleted ? const Color(0xFF8F9BB3) : const Color(0xFF222B45), decoration: isCompleted ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFFFF3D6), borderRadius: BorderRadius.circular(6)),
                                child: Text('+${task['reward_xp']} XP', style: const TextStyle(color: Color(0xFFFFAA00), fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                              if (formattedDeadline.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.access_time_rounded, color: Color(0xFF8F9BB3), size: 12),
                                const SizedBox(width: 4),
                                Text(formattedDeadline, style: const TextStyle(color: Color(0xFF8F9BB3), fontSize: 12, fontWeight: FontWeight.w500)),
                              ]
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFEDF1F7))),
              child: const Icon(Icons.check_circle_outline_rounded, size: 64, color: Color(0xFFE4E9F2)),
            ),
            const SizedBox(height: 24),
            const Text('Semua beres!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF222B45))),
            const SizedBox(height: 8),
            const Text('Tidak ada quest pada tanggal ini.\nKetuk tombol + untuk menambah baru.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8F9BB3), height: 1.5)),
          ],
        ),
      ),
    );
  }

  void _showLevelUpDialog(dynamic newLevel) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.military_tech_rounded, size: 80, color: Color(0xFFFFC94D)),
              const SizedBox(height: 24),
              const Text('LEVEL UP!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF222B45))),
              const SizedBox(height: 8),
              Text('Keren! Kamu mencapai Level $newLevel', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Color(0xFF8F9BB3))),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3366FF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Lanjut Berpetualang', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      )
    );
  }

  void _showTaskDetailsModal(Map<String, dynamic> task) {
    final isCompleted = task['status'] == 'completed';
    String formattedDeadline = task['deadline'] ?? '-';
    try {
      final dt = DateTime.parse(task['deadline'].toString());
      formattedDeadline = DateFormat('dd MMM yyyy, HH:mm').format(dt); 
    } catch (e) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: const Color(0xFFEDF1F7), borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isCompleted)
                    IconButton(icon: const Icon(Icons.edit_rounded, color: Color(0xFF8F9BB3)), onPressed: () { Navigator.pop(context); _showEditTaskModal(task); }),
                  IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: () => _confirmDeleteTask(task['id'], task['title'])),
                ],
              ),
              Text(task['title'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF222B45), letterSpacing: -0.5)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: isCompleted ? const Color(0xFFE5F9F1) : const Color(0xFFE5F0FF), borderRadius: BorderRadius.circular(8)),
                    child: Text(isCompleted ? 'Selesai' : 'Berlangsung', style: TextStyle(color: isCompleted ? const Color(0xFF00E096) : const Color(0xFF3366FF), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3D6), borderRadius: BorderRadius.circular(8)),
                    child: Text('+${task['reward_xp']} XP', style: const TextStyle(color: Color(0xFFFFAA00), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(children: [const Icon(Icons.calendar_today_rounded, color: Color(0xFF8F9BB3), size: 20), const SizedBox(width: 12), Text(formattedDeadline, style: const TextStyle(color: Color(0xFF222B45), fontSize: 15, fontWeight: FontWeight.w500))]),
              const SizedBox(height: 24),
              const Text('Deskripsi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF222B45))),
              const SizedBox(height: 12),
              Text(
                (task['description'] == null || task['description'].toString().trim().isEmpty) ? 'Tidak ada catatan tambahan.' : task['description'],
                style: const TextStyle(color: Color(0xFF8F9BB3), fontSize: 15, height: 1.6),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      }
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
      } catch(e) {}
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
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: const Color(0xFFEDF1F7), borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 24),
                  Text(isEdit ? 'Edit Quest' : 'Quest Baru', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF222B45), letterSpacing: -0.5)),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Apa yang ingin dikerjakan?',
                      filled: true, fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF3366FF), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 2, 
                    decoration: InputDecoration(
                      labelText: 'Catatan tambahan...',
                      filled: true, fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: const BorderSide(color: Color(0xFFE4E9F2))),
                          onPressed: () async {
                            final date = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                            if (date != null) setModalState(() => selectedDate = date);
                          },
                          child: Text(selectedDate == null ? 'Pilih Tanggal' : DateFormat('dd MMM yyyy').format(selectedDate!), style: const TextStyle(color: Color(0xFF222B45))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: const BorderSide(color: Color(0xFFE4E9F2))),
                          onPressed: () async {
                            final time = await showTimePicker(context: context, initialTime: selectedTime ?? TimeOfDay.now());
                            if (time != null) setModalState(() => selectedTime = time);
                          },
                          child: Text(selectedTime == null ? 'Pilih Waktu' : selectedTime!.format(context), style: const TextStyle(color: Color(0xFF222B45))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedReminderOffset,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8F9BB3)),
                    decoration: InputDecoration(
                      labelText: 'Alarm Pengingat',
                      filled: true, fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Tepat saat tenggat')),
                      DropdownMenuItem(value: 5, child: Text('5 Menit Sebelumnya')),
                      DropdownMenuItem(value: 10, child: Text('10 Menit Sebelumnya')),
                      DropdownMenuItem(value: 30, child: Text('30 Menit Sebelumnya')),
                      DropdownMenuItem(value: 60, child: Text('1 Jam Sebelumnya')),
                    ],
                    onChanged: (value) => setModalState(() => selectedReminderOffset = value!),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3366FF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                      onPressed: () async {
                        if (titleController.text.isEmpty || selectedDate == null || selectedTime == null) return;
                        final deadline = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTime!.hour, selectedTime!.minute);
                        final formattedDeadline = DateFormat('yyyy-MM-dd HH:mm:ss').format(deadline);
                        final reminderTime = deadline.subtract(Duration(minutes: selectedReminderOffset));

                        try {
                          int targetId;
                          if (isEdit) {
                            await _apiService.updateTask(task!['id'], titleController.text, formattedDeadline, description: descriptionController.text);
                            targetId = task['id'];
                            await NotificationService().cancelNotification(targetId);
                          } else {
                            final result = await _apiService.createTask(titleController.text, formattedDeadline, description: descriptionController.text);
                            targetId = result['task']?['id'] ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
                          }
                          
                          if (!reminderTime.isBefore(DateTime.now())) {
                            await NotificationService().scheduleNotification(id: targetId, title: 'Peringatan Quest!', body: 'Quest "${titleController.text}" akan segera berakhir!', scheduledTime: reminderTime);
                          }

                          if (mounted) {
                            Navigator.pop(context); 
                            _loadData(); 
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                      child: Text(isEdit ? 'Simpan Perubahan' : 'Buat Quest Baru', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }
}