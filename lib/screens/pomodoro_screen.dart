import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PomodoroScreen extends StatefulWidget {
  final Map<String, dynamic> target;

  const PomodoroScreen({super.key, required this.target});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  late int _pomodoroDuration; // Durasi dalam detik
  late int _timeLeft;         // Sisa detik berjalan
  late int _sessionMinutes;   // Menit yang akan dikirim ke API
  
  bool _isRunning = false;
  Timer? _timer;
  final ApiService _apiService = ApiService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    // 1. Ambil nilai target dan progres yang sudah ada
    int targetValue = widget.target['target_value'] ?? 25;
    int currentValue = widget.target['current_value'] ?? 0;
    
    // 2. Hitung sisa waktu yang dibutuhkan untuk menyelesaikan target
    _sessionMinutes = targetValue - currentValue;
    
    // Jika karena suatu hal nilainya 0 atau minus, kembalikan ke target utuh
    if (_sessionMinutes <= 0) {
      _sessionMinutes = targetValue; 
    }

    // 3. Atur durasi timer (ubah menit menjadi detik)
    _pomodoroDuration = _sessionMinutes * 60; 
    
    // TIPS TESTING: 
    // Jika Anda ingin mengetes tanpa menunggu lama, ganti '* 60' di atas menjadi '* 1' 
    // agar durasinya berubah menjadi detik, bukan menit.
    
    _timeLeft = _pomodoroDuration;
  }

  void _startTimer() {
    if (_timer != null) _timer!.cancel();
    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _isRunning = false;
        });
        _completePomodoro();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _pauseTimer();
    setState(() {
      _timeLeft = _pomodoroDuration;
    });
  }

  Future<void> _completePomodoro() async {
    setState(() {
      _isSaving = true;
    });

    try {
      int targetId = widget.target['target_id'] ?? widget.target['id'];
      
      // Kirim pembaruan API secara dinamis sesuai jumlah menit sesinya
      await _apiService.updateHealthProgress(targetId, _sessionMinutes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.timer_rounded, color: Colors.amber),
                const SizedBox(width: 10),
                Text('Sesi Selesai! +$_sessionMinutes ${widget.target['unit']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: const Color(0xFF2E3A59),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Kembali ke Health Screen dan trigger refresh
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan progres: $e'), backgroundColor: Colors.redAccent),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String minutes = (_timeLeft ~/ 60).toString().padLeft(2, '0');
    String seconds = (_timeLeft % 60).toString().padLeft(2, '0');
    double progress = 1 - (_timeLeft / _pomodoroDuration);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF222B45)),
        title: Text(
          widget.target['title'],
          style: const TextStyle(color: Color(0xFF222B45), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: _isSaving
            ? const CircularProgressIndicator(color: Color(0xFF3366FF))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Label info sesi
                  Text(
                    'Target Sesi: $_sessionMinutes ${widget.target['unit']}',
                    style: const TextStyle(fontSize: 16, color: Color(0xFF8F9BB3), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  
                  // Lingkaran Progress Timer
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 250,
                        height: 250,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: const Color(0xFFEDF1F7),
                          color: const Color(0xFF3366FF),
                        ),
                      ),
                      Text(
                        '$minutes:$seconds',
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF222B45),
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                  
                  // Tombol Kontrol
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tombol Reset
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE4E9F2), width: 2),
                        ),
                        child: IconButton(
                          iconSize: 32,
                          color: const Color(0xFF8F9BB3),
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: _resetTimer,
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Tombol Play / Pause
                      GestureDetector(
                        onTap: _isRunning ? _pauseTimer : _startTimer,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Color(0xFF3366FF),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x4D3366FF),
                                blurRadius: 15,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        ),
      ),
    );
  }
}