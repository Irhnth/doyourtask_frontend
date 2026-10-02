import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/step_counter_service.dart';

class StepTrackerScreen extends StatefulWidget {
  final Map<String, dynamic> target;

  const StepTrackerScreen({
    super.key,
    required this.target,
  });

  @override
  State<StepTrackerScreen> createState() => _StepTrackerScreenState();
}

class _StepTrackerScreenState extends State<StepTrackerScreen> {
  final ApiService _apiService = ApiService();
  final StepCounterService _stepService = StepCounterService();

  late int _targetId;
  late String _targetTitle;
  late int _targetSteps;
  late int _currentSteps;
  late int _totalXp;
  late bool _isCompleted;

  StreamSubscription<int>? _stepSubscription;
  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _targetId = widget.target['target_id'] ?? widget.target['id'] ?? 0;
    _targetTitle = widget.target['title'] ?? 'Langkah Kaki';
    _targetSteps = widget.target['target_value'] ?? 6000;
    _currentSteps = widget.target['current_value'] ?? 0;
    _totalXp = widget.target['total_xp'] ?? 0;
    _isCompleted = widget.target['is_completed'] ?? false;

    // Gunakan live steps dari service jika lebih tinggi
    if (_stepService.todaySteps > _currentSteps) {
      _currentSteps = _stepService.todaySteps;
    }

    _listenToStepSensor();
  }

  void _listenToStepSensor() {
    _stepSubscription = _stepService.stepStream.listen((steps) {
      if (!mounted) return;
      if (steps > _currentSteps) {
        setState(() {
          _currentSteps = steps;
          if (_currentSteps >= _targetSteps) {
            _isCompleted = true;
          }
        });
        _scheduleSync();
      }
    });
  }

  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 4), () {
      _syncStepsToBackend();
    });
  }

  Future<void> _syncStepsToBackend() async {
    if (_targetId == 0 || _isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final res = await _apiService.updateStepProgress(_targetId, _currentSteps);
      if (mounted && res['status'] == 'success') {
        final data = res['data'];
        setState(() {
          if (data != null && data['total_xp'] != null) {
            _totalXp = data['total_xp'];
          }
          if (data != null && data['is_completed'] != null) {
            _isCompleted = data['is_completed'];
          }
        });
      }
    } catch (e) {
      debugPrint('Sync step error: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  void _showChangeTargetModal() {
    final presets = [3000, 5000, 6000, 8000, 10000];
    int selectedValue = _targetSteps;
    final controller = TextEditingController(text: _targetSteps.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
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
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF1F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Ubah Target Langkah Harian',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF222B45),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pilih rekomendasi target atau tentukan sendiri jumlah langkah harian Anda.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8F9BB3), height: 1.4),
                  ),
                  const SizedBox(height: 18),

                  // Presets chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((val) {
                      final isSelected = selectedValue == val;
                      return ChoiceChip(
                        label: Text(
                          '${NumberFormat('#,###', 'id_ID').format(val)} Langkah',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF222B45),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0077B6),
                        backgroundColor: const Color(0xFFF7F9FC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF0077B6) : const Color(0xFFEDF1F7),
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              selectedValue = val;
                              controller.text = val.toString();
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Jumlah Langkah Kustom',
                      hintText: 'Contoh: 7500',
                      prefixIcon: const Icon(Icons.directions_walk_rounded, color: Color(0xFF0077B6)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFEDF1F7)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFEDF1F7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF0077B6), width: 1.8),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        setModalState(() {
                          selectedValue = parsed;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final finalVal = int.tryParse(controller.text) ?? selectedValue;
                        if (finalVal <= 0) return;
                        Navigator.pop(modalContext);
                        await _updateTargetValue(finalVal);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0077B6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Simpan Target',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

  Future<void> _updateTargetValue(int newTarget) async {
    setState(() => _isSyncing = true);
    try {
      await _apiService.editHealthTarget(_targetId, _targetTitle, newTarget, 'Langkah');
      setState(() {
        _targetSteps = newTarget;
        _isCompleted = _currentSteps >= _targetSteps;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Target berhasil diubah menjadi ${NumberFormat('#,###', 'id_ID').format(newTarget)} langkah!'),
            backgroundColor: const Color(0xFF00E096),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _syncStepsToBackend();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengubah target langkah.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _targetSteps > 0 ? (_currentSteps / _targetSteps).clamp(0.0, 1.0) : 0.0;
    final int progressPct = (progress * 100).toInt();

    // Estimasi metrik
    final double distanceKm = _currentSteps * 0.00075;
    final double caloriesKcal = _currentSteps * 0.04;
    final int activeMinutes = (_currentSteps / 100).ceil();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF222B45), size: 19),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Column(
          children: [
            const Text(
              'Pelacakan Langkah',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF222B45),
                letterSpacing: -0.3,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _stepService.isSensorAvailable ? const Color(0xFF00E096) : Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _stepService.isSensorAvailable ? 'Sensor Aktif' : 'Pedometer Siap',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8F9BB3),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0077B6)),
                  )
                : const Icon(Icons.refresh_rounded, color: Color(0xFF0077B6), size: 21),
            onPressed: _syncStepsToBackend,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _syncStepsToBackend,
        color: const Color(0xFF0077B6),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HERO CIRCULAR GAUGE CARD
              _buildHeroCircularCard(progress, progressPct),

              const SizedBox(height: 16),

              // 2. TIGA METRIK KEBUGARAN
              _buildMetricsRow(distanceKm, caloriesKcal, activeMinutes),

              const SizedBox(height: 18),

              // 3. MILESTONE XP ROADMAP
              _buildMilestoneRoadmapCard(progressPct),

              const SizedBox(height: 18),

              // 4. ACTION BUTTONS & HEALTH TIP
              _buildTargetSettingsButton(),

              const SizedBox(height: 14),

              _buildHealthTipsCard(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- HERO CIRCULAR GAUGE CARD ---
  Widget _buildHeroCircularCard(double progress, int progressPct) {
    final bool completed = _isCompleted || _currentSteps >= _targetSteps;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: completed
              ? [const Color(0xFF0A3A40), const Color(0xFF08262C)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Circular Progress Indicator besar
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 190,
                height: 190,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 14,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completed ? const Color(0xFF00E096) : const Color(0xFF00B4D8),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (completed ? const Color(0xFF00E096) : const Color(0xFF00B4D8)).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.directions_walk_rounded,
                      color: completed ? const Color(0xFF00E096) : const Color(0xFF00B4D8),
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    NumberFormat('#,###', 'id_ID').format(_currentSteps),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.6,
                    ),
                  ),
                  Text(
                    '/ ${NumberFormat('#,###', 'id_ID').format(_targetSteps)} Langkah',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: completed ? const Color(0xFF00E096) : const Color(0xFF00B4D8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$progressPct%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Subtitle Status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                completed ? Icons.emoji_events_rounded : Icons.offline_bolt_rounded,
                color: completed ? const Color(0xFFFFC94D) : const Color(0xFF00E096),
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  completed
                      ? 'Target harian 100% tercapai! XP terkunci hari ini.'
                      : 'Sisa ${NumberFormat('#,###', 'id_ID').format((_targetSteps - _currentSteps).clamp(0, 999999))} langkah lagi menuju 100%!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TIGA METRIK KEBUGARAN ROW ---
  Widget _buildMetricsRow(double distanceKm, double caloriesKcal, int activeMinutes) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Jarak',
            value: distanceKm.toStringAsFixed(2),
            unit: 'km',
            icon: Icons.place_rounded,
            color: const Color(0xFF00B4D8),
            bgColor: const Color(0xFFE0F7FA),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            title: 'Kalori',
            value: caloriesKcal.toStringAsFixed(0),
            unit: 'kkal',
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFFF5252),
            bgColor: const Color(0xFFFFEBEE),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            title: 'Waktu',
            value: activeMinutes.toString(),
            unit: 'menit',
            icon: Icons.timer_rounded,
            color: const Color(0xFFFFAA00),
            bgColor: const Color(0xFFFFF8E1),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDF1F7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8F9BB3).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222B45),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8F9BB3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8F9BB3),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- MILESTONE XP ROADMAP CARD ---
  Widget _buildMilestoneRoadmapCard(int progressPct) {
    final milestones = [
      {'pct': 20, 'xp': 5},
      {'pct': 40, 'xp': 5},
      {'pct': 60, 'xp': 10},
      {'pct': 80, 'xp': 10},
      {'pct': 100, 'xp': 20},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDF1F7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8F9BB3).withValues(alpha: 0.05),
            blurRadius: 12,
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
              const Row(
                children: [
                  Icon(Icons.military_tech_rounded, color: Color(0xFFFFC94D), size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Milestone XP Harian',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF222B45),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Text(
                  '$_totalXp / 50 XP',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB78103),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Kumpulkan hingga 50 XP setiap hari melalui 5 batas capaian langkah.',
            style: TextStyle(fontSize: 12, color: Color(0xFF8F9BB3), height: 1.35),
          ),
          const SizedBox(height: 14),

          // Milestone list
          Column(
            children: milestones.map((m) {
              final int milestonePct = m['pct'] as int;
              final int xpReward = m['xp'] as int;
              final int neededSteps = ((milestonePct / 100) * _targetSteps).round();
              final bool isAchieved = progressPct >= milestonePct;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isAchieved ? const Color(0xFFE5F9F1) : const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAchieved
                        ? const Color(0xFF00E096).withValues(alpha: 0.35)
                        : const Color(0xFFEDF1F7),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAchieved ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 17,
                      color: isAchieved ? const Color(0xFF00B377) : const Color(0xFF8F9BB3),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Milestone $milestonePct% (${NumberFormat('#,###', 'id_ID').format(neededSteps)} Langkah)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isAchieved ? FontWeight.bold : FontWeight.w600,
                              color: isAchieved ? const Color(0xFF00754A) : const Color(0xFF222B45),
                            ),
                          ),
                          Text(
                            isAchieved ? 'Tercapai & XP telah diberikan' : 'Belum tercapai',
                            style: TextStyle(
                              fontSize: 10,
                              color: isAchieved ? const Color(0xFF009E60) : const Color(0xFF8F9BB3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAchieved ? const Color(0xFF00E096) : const Color(0xFFE4E9F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+$xpReward XP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isAchieved ? Colors.white : const Color(0xFF8F9BB3),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- BUTTON SESUAIKAN TARGET LANGKAH ---
  Widget _buildTargetSettingsButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _showChangeTargetModal,
        icon: const Icon(Icons.tune_rounded, size: 17),
        label: const Text('Sesuaikan Target Langkah'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0077B6),
          side: const BorderSide(color: Color(0xFF0077B6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // --- HEALTH TIP & SENSOR INFO CARD ---
  Widget _buildHealthTipsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7FA).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00B4D8).withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF0077B6), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sensor perangkat keras menghitung langkah secara otomatis saat ponsel dibawa beraktivitas. Hitungan di-reset setiap tengah malam (00:00).',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF0077B6),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
