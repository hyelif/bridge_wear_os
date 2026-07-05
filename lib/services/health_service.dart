import 'package:flutter/foundation.dart';
import 'package:health_connector/health_connector.dart';

class HealthService extends ChangeNotifier {
  HealthConnector? _connector;
  bool _isAvailable = false;
  bool _hasPermissions = false;

  // Cached data
  int _steps = 0;
  int _heartRate = 0;
  double _calories = 0.0;
  Map<String, dynamic> _sleepData = {};

  bool get isAvailable => _isAvailable;
  bool get hasPermissions => _hasPermissions;
  int get steps => _steps;
  int get heartRate => _heartRate;
  double get calories => _calories;
  Map<String, dynamic> get sleepData => _sleepData;

  Future<void> initialize() async {
    try {
      _connector = await HealthConnector.create();
      _isAvailable = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[Health] Init error: $e');
      _isAvailable = false;
      notifyListeners();
    }
  }

  Future<bool> requestPermissions() async {
    if (_connector == null) return false;
    try {
      final results = await _connector!.requestPermissions([
        HealthDataType.steps.readPermission,
        HealthDataType.heartRateSeries.readPermission,
        HealthDataType.sleepSession.readPermission,
        HealthDataType.activeEnergyBurned.readPermission,
      ]);
      _hasPermissions = results.every(
        (r) => r.status == PermissionStatus.granted,
      );
      notifyListeners();
      return _hasPermissions;
    } catch (e) {
      debugPrint('[Health] Permission error: $e');
      return false;
    }
  }

  Future<void> fetchAllData() async {
    if (_connector == null || !_hasPermissions) return;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      // Steps today
      final stepsResponse = await _connector!.readRecords(
        HealthDataType.steps.readInTimeRange(
          startTime: startOfDay,
          endTime: now,
        ),
      );
      _steps = stepsResponse.records.fold<int>(
        0,
        (sum, record) => sum + record.count.value.toInt(),
      );

      // Heart rate (latest sample from heart rate series)
      final hrResponse = await _connector!.readRecords(
        HealthDataType.heartRateSeries.readInTimeRange(
          startTime: startOfDay,
          endTime: now,
        ),
      );
      if (hrResponse.records.isNotEmpty) {
        // Get the most recent record's average heart rate
        final latestRecord = hrResponse.records.last;
        _heartRate = latestRecord.avgRate.inPerMinute.round();
      }

      // Calories (active energy burned today)
      final calResponse = await _connector!.readRecords(
        HealthDataType.activeEnergyBurned.readInTimeRange(
          startTime: startOfDay,
          endTime: now,
        ),
      );
      _calories = calResponse.records.fold<double>(
        0.0,
        (sum, record) => sum + record.energy.inKilocalories,
      );

      // Sleep (last 24 hours)
      final sleepResponse = await _connector!.readRecords(
        HealthDataType.sleepSession.readInTimeRange(
          startTime: startOfDay.subtract(const Duration(days: 1)),
          endTime: now,
        ),
      );
      if (sleepResponse.records.isNotEmpty) {
        final lastSleep = sleepResponse.records.last;
        final durationHours =
            lastSleep.totalSleepDuration.inMinutes / 60.0;
        _sleepData = {
          'duration': durationHours.toStringAsFixed(1),
          'quality': 'good',
        };
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[Health] Fetch error: $e');
    }
  }

  /// Get health data as a map for BLE transmission
  Map<String, dynamic> getHealthDataMap() {
    return {
      'steps': _steps,
      'heartRate': _heartRate,
      'calories': _calories,
      'sleepData': _sleepData,
    };
  }
}
