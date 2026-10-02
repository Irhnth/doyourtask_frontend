import 'dart:async';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepCounterService {
  static final StepCounterService _instance = StepCounterService._internal();
  factory StepCounterService() => _instance;
  StepCounterService._internal();

  static const String _keyBaselineDate = 'step_baseline_date';
  static const String _keyBaselineValue = 'step_baseline_value';

  final StreamController<int> _stepStreamController =
      StreamController<int>.broadcast();
  StreamSubscription<StepCount>? _stepSubscription;

  int _todaySteps = 0;
  bool _isSensorAvailable = true;
  String? _sensorError;
  bool _isInitialized = false;

  Stream<int> get stepStream => _stepStreamController.stream;
  int get todaySteps => _todaySteps;
  bool get isSensorAvailable => _isSensorAvailable;
  String? get sensorError => _sensorError;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Muat nilai langkah yang tersimpan sebelumnya hari ini jika ada
    await _loadSavedSteps();

    // Minta izin aktivitas fisik (Activity Recognition)
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      start();
    } else {
      _isSensorAvailable = false;
      _sensorError = 'Izin aktivitas fisik diperlukan untuk membaca sensor langkah.';
      _stepStreamController.add(_todaySteps);
    }
  }

  Future<void> _loadSavedSteps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final savedDate = prefs.getString(_keyBaselineDate);

      if (savedDate == today) {
        final baseline = prefs.getInt(_keyBaselineValue) ?? 0;
        final lastRaw = prefs.getInt('last_raw_steps') ?? baseline;
        _todaySteps = (lastRaw >= baseline) ? (lastRaw - baseline) : 0;
      } else {
        _todaySteps = 0;
      }
    } catch (_) {}
  }

  void start() {
    if (_stepSubscription != null) return;

    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onStepCountError,
        cancelOnError: false,
      );
    } catch (e) {
      _isSensorAvailable = false;
      _sensorError = 'Sensor langkah tidak tersedia pada perangkat ini.';
      _stepStreamController.add(_todaySteps);
    }
  }

  Future<void> _onStepCount(StepCount event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final savedDate = prefs.getString(_keyBaselineDate);
      int? baseline = prefs.getInt(_keyBaselineValue);

      // Simpan nilai mentah sensor terbaru
      await prefs.setInt('last_raw_steps', event.steps);

      // 1. Jika tanggal berbeda (masuk hari baru) atau belum ada baseline
      if (savedDate != today || baseline == null) {
        baseline = event.steps;
        await prefs.setString(_keyBaselineDate, today);
        await prefs.setInt(_keyBaselineValue, baseline);
      } else if (event.steps < baseline) {
        // 2. Jika perangkat di-restart (nilai sensor pedometer Android me-reset ke 0)
        baseline = 0;
        await prefs.setInt(_keyBaselineValue, 0);
      }

      final calculatedSteps = event.steps - baseline;
      _todaySteps = calculatedSteps >= 0 ? calculatedSteps : 0;
      _isSensorAvailable = true;
      _sensorError = null;

      _stepStreamController.add(_todaySteps);
    } catch (e) {
      // Pertahankan nilai steps yang ada jika terjadi error disk
      _stepStreamController.add(_todaySteps);
    }
  }

  void _onStepCountError(dynamic error) {
    _isSensorAvailable = false;
    _sensorError = 'Sensor langkah tidak tersedia pada perangkat ini.';
    _stepStreamController.add(_todaySteps);
  }

  void stop() {
    _stepSubscription?.cancel();
    _stepSubscription = null;
  }

  void dispose() {
    stop();
    _stepStreamController.close();
    _isInitialized = false;
  }
}
