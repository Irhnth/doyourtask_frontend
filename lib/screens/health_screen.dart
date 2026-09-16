import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'pomodoro_screen.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _healthTargets = [];
  bool _isLoading = true;
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3366FF), 
                    foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 16), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
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
  @override
  void initState() {
    super.initState();
    _loadHealthData();
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
          SnackBar(content: Text(e.toString())),
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

 Future<void> _incrementProgress(int targetId) async {
    try {
      final result = await _apiService.updateHealthProgress(targetId, 1);
      
      // Jika progres selesai dan mendapatkan XP, tampilkan notifikasi SnackBar saja
      if (result['earned_xp'] != null && result['earned_xp'] > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
                  const SizedBox(width: 10),
                  Text(result['message'] ?? 'Target Selesai!', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              backgroundColor: const Color(0xFF2E3A59),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      _loadHealthData(); // Refresh data
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // --- MODAL UNTUK EDIT TARGET ---
  void _showEditTargetModal(Map<String, dynamic> target) {
    final titleController = TextEditingController(text: target['title']);
    final valueController = TextEditingController(text: target['target_value'].toString());
    final unitController = TextEditingController(text: target['unit'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.vertical(top: Radius.circular(32))
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24, 
            left: 24, right: 24, top: 24
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: const Color(0xFFEDF1F7), borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              const Text('Sesuaikan Target', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF222B45))),
              const SizedBox(height: 24),
              
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Nama Target (Misal: Minum Air)',
                  filled: true, fillColor: const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: valueController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Jumlah',
                        filled: true, fillColor: const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: unitController,
                      decoration: InputDecoration(
                        labelText: 'Satuan (Gelas, Menit)',
                        filled: true, fillColor: const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3366FF), 
                    foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 18), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
                    elevation: 0
                  ),
                  onPressed: () async {
                    if (titleController.text.isEmpty || valueController.text.isEmpty) return;
                    
                    try {
                      int targetId = target['target_id'] ?? target['id'];
                      await _apiService.editHealthTarget(
                        targetId, 
                        titleController.text, 
                        int.parse(valueController.text), 
                        unitController.text
                      );
                      
                      if (mounted) {
                        Navigator.pop(context); 
                        _loadHealthData(); 
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  child: const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF222B45)),
        title: const Text(
          'Target Kesehatan',
          style: TextStyle(color: Color(0xFF222B45), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF3366FF)))
            : RefreshIndicator(
                onRefresh: _loadHealthData,
                color: const Color(0xFF3366FF),
                child: _healthTargets.isEmpty 
                    ? _buildEmptyState() 
                    : _buildHealthGrid(),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFEDF1F7))),
                child: const Icon(Icons.health_and_safety_outlined, size: 64, color: Color(0xFFE4E9F2)),
              ),
              const SizedBox(height: 24),
              const Text('Belum Ada Target', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF222B45))),
              const SizedBox(height: 8),
              const Text('Target kesehatan harianmu kosong.\nSilakan tambahkan melalui panel Admin.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8F9BB3), height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHealthGrid() {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.70, 
      ),
      itemCount: _healthTargets.length,
      itemBuilder: (context, index) {
        var target = _healthTargets[index];
        
        int currentValue = target['current_value'] ?? 0;
        int targetValue = target['target_value'] ?? 1;
        double progress = currentValue / targetValue;
        if (progress > 1.0) progress = 1.0; 

        return _buildHealthCard(target, progress, currentValue, targetValue);
      },
    );
  }

  Widget _buildHealthCard(Map<String, dynamic> target, double progress, int currentValue, int targetValue) {
    bool isCompleted = target['is_completed'] ?? false;
    String unit = target['unit'] ?? '';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF1F7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8F9BB3).withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // TOMBOL EDIT DI POJOK KANAN ATAS
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => _showEditTargetModal(target),
              child: const Icon(Icons.edit_note_rounded, color: Color(0xFF8F9BB3), size: 20),
            ),
          ),
          
          Text(
            target['title'] ?? 'Target',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF222B45), fontSize: 13),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 55,
                height: 55,
                child: CircularProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFFF5F7FA),
                  color: isCompleted ? const Color(0xFF00E096) : const Color(0xFF3366FF),
                  strokeWidth: 6,
                ),
              ),
              if (isCompleted) 
                const Icon(Icons.check_rounded, color: Color(0xFF00E096), size: 26),
            ],
          ),
          const SizedBox(height: 12),
          Text('$currentValue / $targetValue $unit',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8F9BB3), fontWeight: FontWeight.w500)),
          // ... (kode di atasnya tetap sama)
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: Builder(
              builder: (context) {
                // Cek apakah target ini adalah Olahraga
                bool isExercise = target['type'] == 'exercise';

                return ElevatedButton(
                  onPressed: isCompleted 
                      ? null 
                      : () async {
                          if (isExercise) {
                            // Jika olahraga, buka layar Pomodoro
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PomodoroScreen(target: target),
                              ),
                            );
                            // Jika Pomodoro selesai, refresh data
                            if (result == true) {
                              _loadHealthData();
                            }
                          } else {
                            // Jika bukan olahraga, tambah +1 secara manual
                            _incrementProgress(target['target_id'] ?? target['id']);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isExercise ? const Color(0xFFFFF3D6) : const Color(0xFFE5F0FF),
                    foregroundColor: isExercise ? const Color(0xFFFFAA00) : const Color(0xFF3366FF),
                    disabledBackgroundColor: const Color(0xFFE5F9F1),
                    disabledForegroundColor: const Color(0xFF00E096),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(
                    isCompleted 
                        ? 'Selesai' 
                        : (isExercise ? 'Mulai Timer' : '+1 $unit'), 
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)
                  ),
                );
              }
            ),
          )
        ],
      ),
    );
  }
}