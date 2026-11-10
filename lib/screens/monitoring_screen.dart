import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BarData {
  final String label;
  final double val;
  final bool isHighlight;
  final bool isInProgress;
  final String peakVal;

  const BarData({
    required this.label,
    required this.val,
    required this.isHighlight,
    this.isInProgress = false,
    this.peakVal = '',
  });
}

class MonitoringRecord {
  final String title;
  final List<BarData> bars;
  final String totalKwh;

  const MonitoringRecord({
    required this.title,
    required this.bars,
    this.totalKwh = '0.0',
  });
}

class DegradationYearPoint {
  final String yearLabel;
  final double efficiencyRatio;

  const DegradationYearPoint({
    required this.yearLabel,
    required this.efficiencyRatio,
  });
}

class MonitoringScreen extends StatefulWidget {
  final String? panelId;
  final String? initialStatus;
  final DateTime? initialLastUpdated;

  const MonitoringScreen({
    super.key,
    this.panelId,
    this.initialStatus,
    this.initialLastUpdated,
  });

  // Theme Constants
  static const Color darkGreen = Color(0xFF20831B);
  static const Color lightGreen = Color(0xFF66BB6A);
  static const Color accentOrange = Color(0xFFF1A12A);
  static const Color pageBg = Color(0xFFF4F4F4);
  static const Color cardBg = Color(0xFFEBEBEB);
  static const Color appBarBorderGreen = Color(0xFF81E27C);
  static const Color dropdownBg = Color(0xFFF5F5F5);
  static const Color dropdownMenuBg = Color(0xFFF0F0F0);
  static const Color controlBg = Color(0xFFE0E0E0);
  static const Color energyIconBg = Color(0xFFE8F5E9);
  static const Color savingsIconBg = Color(0xFFE0F2F1);
  static const Color progressHighlightBg = Color(0xFFC8E6C9);
  static const Color normalHighlightBg = Color(0xFFDDDDDD);

  // Default Telemetry & System Fallbacks
  static const String defaultPanelId = 'panel_01';
  static const String defaultPanelName = 'Panel_1 - OPI_BE3737AF';
  static const double defaultRatedPowerW = 300.0;
  static const double defaultAnnualDegradationRate = 0.45;
  static const double defaultCurrentEfficiencyRatio = 1.0;
  static const double defaultTariffRateMultiplier = 6.0;

  // Firestore Collection & Field Constants
  static const String colUsers = 'users';
  static const String fieldDefaultPanelId = 'defaultPanelId';
  static const String colSystemStatus = 'system_status';
  static const String docCurrent = 'current';
  static const String fieldPanels = 'panels';
  static const String fieldMetadata = 'metadata';
  static const String fieldDiagnostics = 'diagnostics';
  static const String fieldSensorDiagnostics = 'sensor_diagnostics';
  static const String fieldDegradeHistory = 'degrade_history';
  static const String fieldYearLabel = 'yearLabel';
  static const String fieldEfficiencyRatio = 'efficiencyRatio';
  static const String fieldPanelName = 'panel_name';
  static const String fieldRatedPowerW = 'rated_power_w';
  static const String fieldDegradationRateAnnual = 'degradation_rate_annual';
  static const String fieldCurrentEfficiencyRatio = 'current_efficiency_ratio';
  static const String fieldCondition = 'condition';
  static const String colAnalytics = 'analytics';
  static const String subColDaily = 'daily';
  static const String subColWeekly = 'weekly';
  static const String subColAnnually = 'annually';
  static const String fieldBars = 'bars';
  static const String fieldRawKwh = 'raw_kwh';
  static const String fieldVal = 'val';
  static const String fieldDisplayLabel = 'displayLabel';
  static const String fieldTitle = 'title';
  static const String fieldTotalKwh = 'totalKwh';

  // Condition & Status Options
  static const String conditionGood = 'In good condition';
  static const String conditionFair = 'In fair condition';
  static const String conditionBad = 'In bad condition';
  static const String statusActive = 'Active';
  static const String statusInactive = 'Inactive';
  static const String statusOffline = 'Offline';
  static const String statusSensorProblems = 'Sensor Problems';
  static const String statusPanelRemoved = 'Panel Removed / Disconnected';
  static const String sensorVoltage = 'Voltage Sensor';
  static const String sensorCurrent = 'Current Sensor';
  static const String sensorLight = 'Light Sensor';
  static const String sensorTemperature = 'Temperature Sensor';
  static const String sensorHumidity = 'Humidity Sensor';
  static const String statusWorking = 'Working';
  static const String statusError = 'Error';

  // UI Text Strings & Labels
  static const String titleMonitoring = 'Monitoring';
  static const String titleSensorDiagnostics = 'Sensor Diagnostics';
  static const String titlePerformance = 'Performance';
  static const String titleEnergyProduction = 'Energy Production';
  static const String titleTotalEnergy = 'Total Energy';
  static const String titleTotalSavings = 'Total Savings';
  static const String titlePanelDiagnostics = 'Panel Health Diagnostics';
  static const String titleDegradationRate = 'Degradation Rate';
  static const String titlePanelEfficiency = 'Estimated Panel Efficiency';
  static const String tooltipDiagnosticInfo =
      'This info is gathered within a period of time with an advanced formula using data collected through different sensors and data gathered using the internet.';
  static const String timeframeDaily = 'Daily';
  static const String timeframeWeekly = 'Weekly';
  static const String timeframeAnnually = 'Annually';
  static const String labelFirstHalf = 'First Half';
  static const String labelSecondHalf = 'Second Half';
  static const String unitKwh = 'kWh';
  static const String unitWatts = 'W';
  static const String unitDegradation = '% / yr';
  static const String unitPercent = '%';
  static const String currencyPesos = '₱';
  static const String titleLoading = 'Loading...';

  static const List<String> monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const double wattsPerKw = 1000.0;
  static const double scrollThreshold = 120.0;
  static const int tooltipFadeDelayMs = 1500;
  static const int tooltipFadeAnimMs = 300;
  static const int pageAnimMs = 300;
  static const int appBarAnimMs = 200;

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  String _effectivePanelId = MonitoringScreen.defaultPanelId;

  int _selectedTimeframe = 0; // 0: Daily, 1: Weekly, 2: Annually
  late PageController _pageController;
  int _activePageIndex = 0;

  late final ScrollController _scrollController;
  final GlobalKey _questionMarkKey = GlobalKey();

  int _degradationSlideIndex = 0;
  bool _showPanelNameInAppBar = false;

  String _selectedCondition = MonitoringScreen.conditionGood;
  late String _selectedStatus;

  // OrangePi Offline Watchdog
  DateTime? _lastTelemetryTimestamp;
  Timer? _opiOfflineWatchdogTimer;
  bool _isOpiOffline = false;

  // Live dynamic 5-sensor hardware health flags from Firestore
  bool _voltageSensorWorking = true;
  bool _currentSensorWorking = true;
  bool _lightSensorWorking = true;
  bool _tempSensorWorking = true;
  bool _humiditySensorWorking = true;

  bool _showTooltip = false;
  bool _tooltipVisible = false;
  Timer? _fadeTimer;

  StreamSubscription<DocumentSnapshot>? _statusSubscription;
  StreamSubscription<QuerySnapshot>? _analyticsSubscription;

  String _panelName = MonitoringScreen.defaultPanelName;
  double _panelRatedPowerW = MonitoringScreen.defaultRatedPowerW;
  double _annualDegradationRate = MonitoringScreen.defaultAnnualDegradationRate;
  double _currentEfficiencyRatio =
      MonitoringScreen.defaultCurrentEfficiencyRatio;

  List<MonitoringRecord> _dailyRecords = [];
  List<MonitoringRecord> _weeklyRecords = [];
  List<MonitoringRecord> _annualRecords = [];
  List<List<DegradationYearPoint>> _degradationSlides = [[]];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus ?? MonitoringScreen.statusActive;
    if (widget.initialLastUpdated != null) {
      _lastTelemetryTimestamp = widget.initialLastUpdated;
      final diffSec = DateTime.now()
          .toUtc()
          .difference(_lastTelemetryTimestamp!)
          .inSeconds;
      _isOpiOffline = diffSec > 75;
      if (_isOpiOffline) {
        _selectedStatus = MonitoringScreen.statusOffline;
      }
    }

    _activePageIndex = 0;
    _pageController = PageController(initialPage: _activePageIndex);
    _scrollController = ScrollController()..addListener(_onScroll);

    _initStatusSubscription();
    _resolvePanelIdAndInit();
    _startOpiOfflineWatchdog();
  }

  void _startOpiOfflineWatchdog() {
    _opiOfflineWatchdogTimer?.cancel();
    _opiOfflineWatchdogTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) {
      if (!mounted) return;
      if (_lastTelemetryTimestamp != null) {
        final diffSec = DateTime.now()
            .toUtc()
            .difference(_lastTelemetryTimestamp!)
            .inSeconds;
        final bool offlineNow = diffSec > 75;
        if (offlineNow != _isOpiOffline) {
          setState(() {
            _isOpiOffline = offlineNow;
            if (_isOpiOffline) {
              _selectedStatus = MonitoringScreen.statusOffline;
            }
          });
        }
      } else {
        if (!_isOpiOffline) {
          setState(() {
            _isOpiOffline = true;
            _selectedStatus = MonitoringScreen.statusOffline;
          });
        }
      }
    });
  }

  Future<void> _resolvePanelIdAndInit() async {
    if (widget.panelId != null &&
        widget.panelId!.isNotEmpty &&
        widget.panelId != MonitoringScreen.defaultPanelId) {
      _effectivePanelId = widget.panelId!;
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection(MonitoringScreen.colUsers)
              .doc(user.uid)
              .get();
          if (userDoc.exists && userDoc.data() != null) {
            final data = userDoc.data()!;
            final defaultId = data[MonitoringScreen.fieldDefaultPanelId]
                ?.toString();
            if (defaultId != null && defaultId.isNotEmpty) {
              _effectivePanelId = defaultId;
            }
          }
        } catch (e) {
          debugPrint('Error resolving default panel ID: $e');
        }
      }
    }

    if (!mounted) return;
    _listenToAnalyticsFirestore();
  }

  void _initStatusSubscription() {
    _statusSubscription?.cancel();
    _statusSubscription = FirebaseFirestore.instance
        .collection(MonitoringScreen.colSystemStatus)
        .doc(MonitoringScreen.docCurrent)
        .snapshots(includeMetadataChanges: false)
        .listen((snapshot) {
          if (!mounted || !snapshot.exists || snapshot.data() == null) return;

          final data = snapshot.data() as Map<String, dynamic>;

          // OrangePi heartbeat update check (Supports Timestamp, String, and Epoch int)
          final lastUpdatedVal = data['last_updated'];
          if (lastUpdatedVal != null) {
            DateTime? parsed;
            if (lastUpdatedVal is Timestamp) {
              parsed = lastUpdatedVal.toDate().toUtc();
            } else if (lastUpdatedVal is String && lastUpdatedVal.isNotEmpty) {
              parsed = DateTime.tryParse(lastUpdatedVal)?.toUtc();
            } else if (lastUpdatedVal is int) {
              parsed = DateTime.fromMillisecondsSinceEpoch(
                lastUpdatedVal,
                isUtc: true,
              );
            }
            if (parsed != null) {
              _lastTelemetryTimestamp = parsed;
              final diffSec = DateTime.now()
                  .toUtc()
                  .difference(_lastTelemetryTimestamp!)
                  .inSeconds;
              _isOpiOffline = diffSec > 75;
            }
          }

          final panels =
              data[MonitoringScreen.fieldPanels] as Map<String, dynamic>? ?? {};

          final String targetId = panels.containsKey(widget.panelId)
              ? widget.panelId!
              : _effectivePanelId;

          if (panels.containsKey(targetId)) {
            final panelDoc = panels[targetId] as Map<String, dynamic>;
            final metadata =
                panelDoc[MonitoringScreen.fieldMetadata]
                    as Map<String, dynamic>? ??
                {};
            final diagnostics =
                panelDoc[MonitoringScreen.fieldDiagnostics]
                    as Map<String, dynamic>? ??
                {};
            final sensorDiag =
                panelDoc[MonitoringScreen.fieldSensorDiagnostics]
                    as Map<String, dynamic>? ??
                {};

            final panelRemoved =
                (diagnostics['panel_removed'] == true) ||
                (panelDoc['panel_removed'] == true);

            final voltWorking = sensorDiag['voltage_sensor_working'] ?? true;
            final currWorking = sensorDiag['current_sensor_working'] ?? true;
            final lightWorking = sensorDiag['light_sensor_working'] ?? true;
            final tempWorking = sensorDiag['temp_sensor_working'] ?? true;
            final humiWorking = sensorDiag['humidity_sensor_working'] ?? true;

            final failedSensors = <String>[];
            if (!voltWorking) failedSensors.add('Voltage Sensor');
            if (!currWorking) failedSensors.add('Current Sensor');
            if (!lightWorking) failedSensors.add('Light Sensor');
            if (!tempWorking) failedSensors.add('Temperature Sensor');
            if (!humiWorking) failedSensors.add('Humidity Sensor');

            final historyRaw =
                (diagnostics[MonitoringScreen.fieldDegradeHistory] as List?) ??
                [];
            List<DegradationYearPoint> points = historyRaw.map((e) {
              final m = e as Map<String, dynamic>;
              return DegradationYearPoint(
                yearLabel: m[MonitoringScreen.fieldYearLabel]?.toString() ?? '',
                efficiencyRatio:
                    (m[MonitoringScreen.fieldEfficiencyRatio] as num?)
                        ?.toDouble() ??
                    MonitoringScreen.defaultCurrentEfficiencyRatio,
              );
            }).toList();

            final currentEff =
                (diagnostics[MonitoringScreen.fieldCurrentEfficiencyRatio]
                        as num?)
                    ?.toDouble() ??
                MonitoringScreen.defaultCurrentEfficiencyRatio;

            // Broadcast top status text (Prioritizing OrangePi Offline)
            final determinedStatus = _isOpiOffline
                ? MonitoringScreen.statusOffline
                : panelRemoved
                ? MonitoringScreen.statusPanelRemoved
                : failedSensors.isNotEmpty
                ? MonitoringScreen.statusSensorProblems
                : MonitoringScreen.statusActive;

            // Strictly constrain bottom text to 3 standard strings without forcing "In bad condition" when panel is disconnected
            final explicitCondition =
                panelDoc[MonitoringScreen.fieldCondition]?.toString() ??
                diagnostics[MonitoringScreen.fieldCondition]?.toString();

            String determinedCondition;
            if (explicitCondition == MonitoringScreen.conditionGood ||
                explicitCondition == MonitoringScreen.conditionFair ||
                explicitCondition == MonitoringScreen.conditionBad) {
              determinedCondition = explicitCondition!;
            } else if (currentEff < 0.60) {
              determinedCondition = MonitoringScreen.conditionBad;
            } else if (failedSensors.isNotEmpty || currentEff < 0.80) {
              determinedCondition = MonitoringScreen.conditionFair;
            } else {
              determinedCondition = MonitoringScreen.conditionGood;
            }

            setState(() {
              _panelName =
                  panelDoc[MonitoringScreen.fieldPanelName] ?? targetId;
              _panelRatedPowerW =
                  (metadata[MonitoringScreen.fieldRatedPowerW] as num?)
                      ?.toDouble() ??
                  MonitoringScreen.defaultRatedPowerW;
              _annualDegradationRate =
                  (diagnostics[MonitoringScreen.fieldDegradationRateAnnual]
                          as num?)
                      ?.toDouble() ??
                  MonitoringScreen.defaultAnnualDegradationRate;
              _currentEfficiencyRatio = currentEff;
              _selectedCondition = determinedCondition;

              _voltageSensorWorking = voltWorking;
              _currentSensorWorking = currWorking;
              _lightSensorWorking = lightWorking;
              _tempSensorWorking = tempWorking;
              _humiditySensorWorking = humiWorking;
              _selectedStatus = determinedStatus;

              if (points.isNotEmpty) {
                _degradationSlides = [points];
                _degradationSlideIndex = 0;
              }
            });
          }
        });
  }

  void _listenToAnalyticsFirestore() {
    final timeframeCol = _selectedTimeframe == 0
        ? MonitoringScreen.subColDaily
        : _selectedTimeframe == 1
        ? MonitoringScreen.subColWeekly
        : MonitoringScreen.subColAnnually;

    _analyticsSubscription?.cancel();
    _analyticsSubscription = FirebaseFirestore.instance
        .collection(MonitoringScreen.colAnalytics)
        .doc(_effectivePanelId)
        .collection(timeframeCol)
        .snapshots(includeMetadataChanges: false)
        .listen((snapshot) {
          _processAnalyticsSnapshot(snapshot);
        });
  }

  void _processAnalyticsSnapshot(QuerySnapshot snapshot) {
    if (!mounted || snapshot.docs.isEmpty) return;

    List<MonitoringRecord> records = [];

    dynamic getBarValueRaw(Map<String, dynamic> barsRaw, String key) {
      if (barsRaw.containsKey(key)) return barsRaw[key];
      final aliasMap = {
        '06:00': ['6AM', '06:00', '6:00', '06:00:00'],
        '09:00': ['9AM', '09:00', '9:00', '09:00:00'],
        '12:00': ['12NN', '12:00', '12PM', '12:00:00'],
        '15:00': ['3PM', '15:00', '3PM', '15:00:00'],
        '18:00': ['6PM', '18:00', '6PM', '18:00:00'],
      };
      final aliases = aliasMap[key] ?? [key];
      for (final alias in aliases) {
        if (barsRaw.containsKey(alias)) return barsRaw[alias];
      }
      return null;
    }

    if (_selectedTimeframe == 2) {
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final yearId = doc.id;
        final barsRaw =
            data[MonitoringScreen.fieldBars] as Map<String, dynamic>? ?? {};

        // 1. First Half (Jan - Jun)
        double firstHalfTotal = 0.0;
        double firstHalfPeak = 0.0;
        for (int m = 1; m <= 6; m++) {
          final monthKey = MonitoringScreen.monthNames[m - 1];
          final rawVal = barsRaw[monthKey];
          double v = 0.0;
          if (rawVal is Map) {
            v =
                (rawVal[MonitoringScreen.fieldRawKwh] as num?)?.toDouble() ??
                (rawVal[MonitoringScreen.fieldVal] as num?)?.toDouble() ??
                0.0;
          } else if (rawVal is num) {
            v = rawVal.toDouble();
          }
          v = max(0.0, v);
          firstHalfTotal += v;
          if (v > firstHalfPeak) firstHalfPeak = v;
        }

        final firstHalfCeiling = max(
          _panelRatedPowerW / MonitoringScreen.wattsPerKw,
          firstHalfPeak > 0 ? firstHalfPeak : 1.0,
        );

        List<BarData> firstHalfBars = [];
        for (int m = 1; m <= 6; m++) {
          final monthKey = MonitoringScreen.monthNames[m - 1];
          final rawVal = barsRaw[monthKey];
          double v = 0.0;
          String displayLabel = '';
          if (rawVal is Map) {
            v =
                (rawVal[MonitoringScreen.fieldRawKwh] as num?)?.toDouble() ??
                (rawVal[MonitoringScreen.fieldVal] as num?)?.toDouble() ??
                0.0;
            displayLabel =
                rawVal[MonitoringScreen.fieldDisplayLabel]?.toString() ?? '';
          } else if (rawVal is num) {
            v = rawVal.toDouble();
          }
          v = max(0.0, v);

          final heightRatio = (firstHalfTotal <= 0.0 || v <= 0.0)
              ? 0.0
              : (v / firstHalfCeiling).clamp(0.0, 1.0);
          final isPeak =
              firstHalfPeak > 0 &&
              v == firstHalfPeak &&
              v > 0 &&
              firstHalfTotal > 0;

          firstHalfBars.add(
            BarData(
              label: monthKey,
              val: heightRatio,
              isHighlight: isPeak,
              peakVal: isPeak
                  ? (displayLabel.isNotEmpty
                        ? displayLabel
                        : '${(v * MonitoringScreen.wattsPerKw).toInt()} ${MonitoringScreen.unitWatts}')
                  : '',
            ),
          );
        }

        records.add(
          MonitoringRecord(
            title: '$yearId - ${MonitoringScreen.labelFirstHalf}',
            bars: firstHalfBars,
            totalKwh: max(0.0, firstHalfTotal).toStringAsFixed(0),
          ),
        );

        // 2. Second Half (Jul - Dec)
        double secondHalfTotal = 0.0;
        double secondHalfPeak = 0.0;
        for (int m = 7; m <= 12; m++) {
          final monthKey = MonitoringScreen.monthNames[m - 1];
          final rawVal = barsRaw[monthKey];
          double v = 0.0;
          if (rawVal is Map) {
            v =
                (rawVal[MonitoringScreen.fieldRawKwh] as num?)?.toDouble() ??
                (rawVal[MonitoringScreen.fieldVal] as num?)?.toDouble() ??
                0.0;
          } else if (rawVal is num) {
            v = rawVal.toDouble();
          }
          v = max(0.0, v);
          secondHalfTotal += v;
          if (v > secondHalfPeak) secondHalfPeak = v;
        }

        final secondHalfCeiling = max(
          _panelRatedPowerW / MonitoringScreen.wattsPerKw,
          secondHalfPeak > 0 ? secondHalfPeak : 1.0,
        );

        List<BarData> secondHalfBars = [];
        for (int m = 7; m <= 12; m++) {
          final monthKey = MonitoringScreen.monthNames[m - 1];
          final rawVal = barsRaw[monthKey];
          double v = 0.0;
          String displayLabel = '';
          if (rawVal is Map) {
            v =
                (rawVal[MonitoringScreen.fieldRawKwh] as num?)?.toDouble() ??
                (rawVal[MonitoringScreen.fieldVal] as num?)?.toDouble() ??
                0.0;
            displayLabel =
                rawVal[MonitoringScreen.fieldDisplayLabel]?.toString() ?? '';
          } else if (rawVal is num) {
            v = rawVal.toDouble();
          }
          v = max(0.0, v);

          final heightRatio = (secondHalfTotal <= 0.0 || v <= 0.0)
              ? 0.0
              : (v / secondHalfCeiling).clamp(0.0, 1.0);
          final isPeak =
              secondHalfPeak > 0 &&
              v == secondHalfPeak &&
              v > 0 &&
              secondHalfTotal > 0;

          secondHalfBars.add(
            BarData(
              label: monthKey,
              val: heightRatio,
              isHighlight: isPeak,
              peakVal: isPeak
                  ? (displayLabel.isNotEmpty
                        ? displayLabel
                        : '${(v * MonitoringScreen.wattsPerKw).toInt()} ${MonitoringScreen.unitWatts}')
                  : '',
            ),
          );
        }

        records.add(
          MonitoringRecord(
            title: '$yearId - ${MonitoringScreen.labelSecondHalf}',
            bars: secondHalfBars,
            totalKwh: max(0.0, secondHalfTotal).toStringAsFixed(0),
          ),
        );
      }
    } else {
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final title = data[MonitoringScreen.fieldTitle] as String? ?? '';
        final double rawTotalKwh =
            (data[MonitoringScreen.fieldTotalKwh] as num?)?.toDouble() ?? 0.0;
        final safeTotalKwh = max(0.0, rawTotalKwh);
        final totalKwh = safeTotalKwh.toStringAsFixed(0);
        final barsRaw =
            data[MonitoringScreen.fieldBars] as Map<String, dynamic>? ?? {};

        double peakVal = 0.0;
        barsRaw.forEach((key, val) {
          double v = 0.0;
          if (val is Map) {
            v =
                (val[MonitoringScreen.fieldRawKwh] as num?)?.toDouble() ??
                (val[MonitoringScreen.fieldVal] as num?)?.toDouble() ??
                0.0;
          } else if (val is num) {
            v = val.toDouble();
          }
          v = max(0.0, v);
          if (v > peakVal) peakVal = v;
        });

        final ceiling = max(
          _panelRatedPowerW / MonitoringScreen.wattsPerKw,
          peakVal > 0 ? peakVal : 1.0,
        );

        List<BarData> bars = [];
        final bucketKeys = _selectedTimeframe == 0
            ? ['06:00', '09:00', '12:00', '15:00', '18:00']
            : barsRaw.keys.toList();

        for (var key in bucketKeys) {
          final val = getBarValueRaw(barsRaw, key);
          double rawVal = 0.0;
          String displayLabel = '';

          if (val is Map) {
            rawVal =
                (val[MonitoringScreen.fieldRawKwh] as num?)?.toDouble() ??
                (val[MonitoringScreen.fieldVal] as num?)?.toDouble() ??
                0.0;
            displayLabel =
                val[MonitoringScreen.fieldDisplayLabel]?.toString() ?? '';
          } else if (val is num) {
            rawVal = val.toDouble();
          }

          rawVal = max(0.0, rawVal);

          final heightRatio = (safeTotalKwh <= 0.0 || rawVal <= 0.0)
              ? 0.0
              : (rawVal / ceiling).clamp(0.0, 1.0);
          final isPeak =
              peakVal > 0 &&
              rawVal == peakVal &&
              rawVal > 0 &&
              safeTotalKwh > 0;

          bars.add(
            BarData(
              label: key,
              val: heightRatio,
              isHighlight: isPeak,
              peakVal: isPeak
                  ? (displayLabel.isNotEmpty
                        ? displayLabel
                        : '${(rawVal * MonitoringScreen.wattsPerKw).toInt()} ${MonitoringScreen.unitWatts}')
                  : '',
            ),
          );
        }

        records.add(
          MonitoringRecord(title: title, bars: bars, totalKwh: totalKwh),
        );
      }
    }

    final targetIndex = records.isNotEmpty ? records.length - 1 : 0;

    setState(() {
      if (_selectedTimeframe == 0) {
        _dailyRecords = records;
      } else if (_selectedTimeframe == 1) {
        _weeklyRecords = records;
      } else {
        _annualRecords = records;
      }
      _activePageIndex = targetIndex;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients && records.isNotEmpty) {
        if (_pageController.page?.round() != targetIndex) {
          _pageController.jumpToPage(targetIndex);
        }
      }
    });
  }

  List<MonitoringRecord> _buildRecordsForTimeframe(int timeframe) {
    switch (timeframe) {
      case 0:
        return _dailyRecords;
      case 1:
        return _weeklyRecords;
      case 2:
      default:
        return _annualRecords;
    }
  }

  void _onTimeframeChanged(int newTimeframe) {
    if (_selectedTimeframe != newTimeframe) {
      setState(() {
        _selectedTimeframe = newTimeframe;
        _activePageIndex = 0;
      });
      _listenToAnalyticsFirestore();
    }
  }

  void _onScroll() {
    final isScrolledPast =
        _scrollController.hasClients &&
        _scrollController.offset > MonitoringScreen.scrollThreshold;
    if (isScrolledPast != _showPanelNameInAppBar) {
      setState(() => _showPanelNameInAppBar = isScrolledPast);
    }
    _triggerFadeTimerOnTouch();
  }

  void _openTooltip() {
    _fadeTimer?.cancel();
    setState(() {
      _showTooltip = true;
      _tooltipVisible = true;
    });
  }

  void _triggerFadeTimerOnTouch() {
    if (!_showTooltip || _fadeTimer != null) return;

    _fadeTimer = Timer(
      const Duration(milliseconds: MonitoringScreen.tooltipFadeDelayMs),
      () {
        if (!mounted) return;
        setState(() {
          _tooltipVisible = false;
        });
        Future.delayed(
          const Duration(milliseconds: MonitoringScreen.tooltipFadeAnimMs),
          () {
            if (!mounted) return;
            setState(() {
              _showTooltip = false;
              _fadeTimer = null;
            });
          },
        );
      },
    );
  }

  void _showSensorStatusModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final sensors = [
          {
            'name': MonitoringScreen.sensorVoltage,
            'working': _voltageSensorWorking,
          },
          {
            'name': MonitoringScreen.sensorCurrent,
            'working': _currentSensorWorking,
          },
          {
            'name': MonitoringScreen.sensorLight,
            'working': _lightSensorWorking,
          },
          {
            'name': MonitoringScreen.sensorTemperature,
            'working': _tempSensorWorking,
          },
          {
            'name': MonitoringScreen.sensorHumidity,
            'working': _humiditySensorWorking,
          },
        ];

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                MonitoringScreen.titleSensorDiagnostics,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...sensors.map((sensor) {
                final isWorking = sensor['working'] as bool;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        sensor['name'] as String,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            isWorking
                                ? Icons.check_circle_rounded
                                : Icons.error_rounded,
                            color: isWorking ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isWorking
                                ? MonitoringScreen.statusWorking
                                : MonitoringScreen.statusError,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isWorking ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _analyticsSubscription?.cancel();
    _fadeTimer?.cancel();
    _opiOfflineWatchdogTimer?.cancel();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToPage(int index, int totalRecords) {
    if (index >= 0 && index < totalRecords && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: MonitoringScreen.pageAnimMs),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildTimeframeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: MonitoringScreen.dropdownBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedTimeframe,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.black87,
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          dropdownColor: MonitoringScreen.dropdownMenuBg,
          borderRadius: BorderRadius.circular(16),
          items: const [
            DropdownMenuItem(
              value: 0,
              child: Text(MonitoringScreen.timeframeDaily),
            ),
            DropdownMenuItem(
              value: 1,
              child: Text(MonitoringScreen.timeframeWeekly),
            ),
            DropdownMenuItem(
              value: 2,
              child: Text(MonitoringScreen.timeframeAnnually),
            ),
          ],
          onChanged: (int? newValue) {
            if (newValue != null) {
              _onTimeframeChanged(newValue);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<MonitoringRecord> records = _buildRecordsForTimeframe(
      _selectedTimeframe,
    );
    final int safeIndex = _activePageIndex.clamp(
      0,
      records.isNotEmpty ? records.length - 1 : 0,
    );
    final MonitoringRecord activeRecord = records.isNotEmpty
        ? records[safeIndex]
        : const MonitoringRecord(
            title: MonitoringScreen.titleLoading,
            bars: [],
          );
    final MonitoringRecord latestRecord = records.isNotEmpty
        ? records.last
        : const MonitoringRecord(title: '', bars: []);

    final List<DegradationYearPoint> activeSlidePoints =
        _degradationSlides.isNotEmpty
        ? _degradationSlides[_degradationSlideIndex.clamp(
            0,
            _degradationSlides.length - 1,
          )]
        : [];
    final double persistentLatestEfficiency = _currentEfficiencyRatio;

    // Status color mapping with grey for offline state
    final Color statusColor = _selectedStatus == MonitoringScreen.statusOffline
        ? Colors.grey
        : _selectedStatus == MonitoringScreen.statusPanelRemoved ||
              _selectedStatus == MonitoringScreen.statusSensorProblems
        ? Colors.red
        : _selectedStatus == MonitoringScreen.statusInactive
        ? Colors.grey
        : Colors.green;

    return Listener(
      onPointerDown: (_) => _triggerFadeTimerOnTouch(),
      child: Scaffold(
        backgroundColor: MonitoringScreen.pageBg,
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: MonitoringScreen.pageBg,
              toolbarHeight: 70,
              automaticallyImplyLeading: false,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: const BoxDecoration(
                        color: MonitoringScreen.cardBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.black87,
                        size: 22,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(
                      milliseconds: MonitoringScreen.appBarAnimMs,
                    ),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      _showPanelNameInAppBar
                          ? _panelName
                          : MonitoringScreen.titleMonitoring,
                      key: ValueKey<bool>(_showPanelNameInAppBar),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 12.0,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // STATUS CARD
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 16),
                          child: child,
                        ),
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: MonitoringScreen.cardBg,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: _showSensorStatusModal,
                                  child: Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _selectedStatus,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _panelName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedCondition,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        _selectedCondition ==
                                            MonitoringScreen.conditionBad
                                        ? Colors.redAccent
                                        : _selectedCondition ==
                                              MonitoringScreen.conditionFair
                                        ? Colors.orangeAccent
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.solar_power_rounded,
                            size: 56,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    MonitoringScreen.titlePerformance,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // BAR CHART CARD
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 16),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: MonitoringScreen.cardBg,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        transitionBuilder: (child, animation) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(0.0, 0.15),
                                                end: Offset.zero,
                                              ).animate(animation),
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Text(
                                          activeRecord.totalKwh,
                                          key: ValueKey<String>(
                                            'total_kwh_${activeRecord.title}_${activeRecord.totalKwh}',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        MonitoringScreen.unitKwh,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    MonitoringScreen.titleEnergyProduction,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              _buildTimeframeDropdown(),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 220,
                            child: records.isEmpty
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : PageView.builder(
                                    key: ValueKey<int>(_selectedTimeframe),
                                    controller: _pageController,
                                    itemCount: records.length,
                                    onPageChanged: (index) {
                                      setState(() => _activePageIndex = index);
                                    },
                                    itemBuilder: (context, recordIndex) {
                                      final List<BarData> barData =
                                          records[recordIndex].bars;
                                      return Column(
                                        children: [
                                          Expanded(
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                const double topHeadroom = 36.0;
                                                final double
                                                availableBarHeight =
                                                    constraints.maxHeight -
                                                    topHeadroom;

                                                return Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    Positioned(
                                                      top: topHeadroom,
                                                      left: 0,
                                                      right: 0,
                                                      bottom: 0,
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: List.generate(
                                                          5,
                                                          (_) =>
                                                              _buildDashedLine(),
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: topHeadroom,
                                                      left: 0,
                                                      right: 0,
                                                      bottom: 0,
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .end,
                                                        children: barData.map<Widget>((
                                                          item,
                                                        ) {
                                                          final calculatedBarHeight =
                                                              availableBarHeight *
                                                              item.val.clamp(
                                                                0.0,
                                                                1.0,
                                                              );

                                                          Color barColor;
                                                          if (item
                                                              .isInProgress) {
                                                            barColor =
                                                                MonitoringScreen
                                                                    .lightGreen;
                                                          } else if (item
                                                              .isHighlight) {
                                                            barColor =
                                                                MonitoringScreen
                                                                    .accentOrange;
                                                          } else {
                                                            barColor =
                                                                MonitoringScreen
                                                                    .darkGreen;
                                                          }

                                                          return Expanded(
                                                            child: Stack(
                                                              alignment: Alignment
                                                                  .bottomCenter,
                                                              clipBehavior:
                                                                  Clip.none,
                                                              children: [
                                                                AnimatedContainer(
                                                                  duration:
                                                                      const Duration(
                                                                        milliseconds:
                                                                            400,
                                                                      ),
                                                                  curve: Curves
                                                                      .easeOutCubic,
                                                                  width: 32,
                                                                  height:
                                                                      calculatedBarHeight,
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                        barColor,
                                                                    borderRadius:
                                                                        const BorderRadius.vertical(
                                                                          top: Radius.circular(
                                                                            8,
                                                                          ),
                                                                        ),
                                                                  ),
                                                                ),
                                                                if (item
                                                                    .peakVal
                                                                    .isNotEmpty)
                                                                  Positioned(
                                                                    bottom:
                                                                        calculatedBarHeight +
                                                                        6,
                                                                    child: _buildHighlightLabel(
                                                                      item.peakVal,
                                                                      item.isInProgress,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: barData.map<Widget>((
                                              item,
                                            ) {
                                              return Expanded(
                                                child: Center(
                                                  child: Text(
                                                    item.label,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: item.isInProgress
                                                          ? MonitoringScreen
                                                                .darkGreen
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: MonitoringScreen.controlBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (safeIndex > 0)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.chevron_left_rounded,
                                    ),
                                    onPressed: () => _navigateToPage(
                                      safeIndex - 1,
                                      records.length,
                                    ),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  )
                                else
                                  const SizedBox(width: 24),
                                Text(
                                  activeRecord.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                                if (safeIndex < records.length - 1)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                    onPressed: () => _navigateToPage(
                                      safeIndex + 1,
                                      records.length,
                                    ),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  )
                                else
                                  const SizedBox(width: 24),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // PERSISTENT SUMMARY KPI BOXES
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 16),
                          child: child,
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: MonitoringScreen.cardBg,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      MonitoringScreen.titleTotalEnergy,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: MonitoringScreen.energyIconBg,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.bolt_rounded,
                                        size: 16,
                                        color: MonitoringScreen.darkGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      transitionBuilder: (child, animation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0.0, 0.15),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        latestRecord.totalKwh,
                                        key: ValueKey<String>(
                                          'kpi_energy_${latestRecord.totalKwh}',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      MonitoringScreen.unitKwh,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: MonitoringScreen.cardBg,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      MonitoringScreen.titleTotalSavings,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: MonitoringScreen.savingsIconBg,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.payments_rounded,
                                        size: 16,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.0, 0.15),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    '${MonitoringScreen.currencyPesos} ${(max(0.0, double.tryParse(latestRecord.totalKwh) ?? 0.0) * MonitoringScreen.defaultTariffRateMultiplier).toStringAsFixed(2)}',
                                    key: ValueKey<String>(
                                      'kpi_savings_${latestRecord.totalKwh}',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: MonitoringScreen.darkGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // DEGRADATION DIAGNOSTICS CARD
                  const Text(
                    MonitoringScreen.titlePanelDiagnostics,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 16),
                          child: child,
                        ),
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: MonitoringScreen.cardBg,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            transitionBuilder:
                                                (child, animation) {
                                                  return FadeTransition(
                                                    opacity: animation,
                                                    child: SlideTransition(
                                                      position: Tween<Offset>(
                                                        begin: const Offset(
                                                          0.0,
                                                          0.15,
                                                        ),
                                                        end: Offset.zero,
                                                      ).animate(animation),
                                                      child: child,
                                                    ),
                                                  );
                                                },
                                            child: Text(
                                              _annualDegradationRate
                                                  .toStringAsFixed(2),
                                              key: ValueKey<double>(
                                                _annualDegradationRate,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 36,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            MonitoringScreen.unitDegradation,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        MonitoringScreen.titleDegradationRate,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    key: _questionMarkKey,
                                    onTap: _openTooltip,
                                    child: Container(
                                      height: 32,
                                      width: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _showTooltip
                                              ? MonitoringScreen.darkGreen
                                              : Colors.grey.shade400,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.help_outline_rounded,
                                        size: 18,
                                        color: _showTooltip
                                            ? MonitoringScreen.darkGreen
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // LINE GRAPH
                              SizedBox(
                                height: 180,
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: _DegradationLineChartPainter(
                                    lineColor: MonitoringScreen.darkGreen,
                                    points: activeSlidePoints,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: activeSlidePoints.map((p) {
                                  final bool isCurrentYear =
                                      p.yearLabel ==
                                      DateTime.now().year.toString();
                                  return Text(
                                    p.yearLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isCurrentYear
                                          ? MonitoringScreen.darkGreen
                                          : Colors.black54,
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: MonitoringScreen.controlBg,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.chevron_left_rounded,
                                        size: 20,
                                      ),
                                      onPressed: _degradationSlideIndex > 0
                                          ? () => setState(
                                              () => _degradationSlideIndex--,
                                            )
                                          : null,
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                    Text(
                                      activeSlidePoints.isNotEmpty
                                          ? '${activeSlidePoints.first.yearLabel} - ${activeSlidePoints.last.yearLabel}'
                                          : '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                      ),
                                      onPressed:
                                          _degradationSlideIndex <
                                              _degradationSlides.length - 1
                                          ? () => setState(
                                              () => _degradationSlideIndex++,
                                            )
                                          : null,
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          MonitoringScreen.titlePanelEfficiency,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          '${(persistentLatestEfficiency * 100).toInt()}${MonitoringScreen.unitPercent}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: MonitoringScreen.darkGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: TweenAnimationBuilder<double>(
                                        duration: const Duration(
                                          milliseconds: 600,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        tween: Tween<double>(
                                          begin: 0.0,
                                          end: persistentLatestEfficiency.clamp(
                                            0.0,
                                            1.0,
                                          ),
                                        ),
                                        builder: (context, value, child) {
                                          return LinearProgressIndicator(
                                            value: value,
                                            minHeight: 10,
                                            backgroundColor:
                                                MonitoringScreen.controlBg,
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                  Color
                                                >(MonitoringScreen.darkGreen),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_showTooltip)
                          Positioned(
                            top: 60,
                            right: 12,
                            left: 12,
                            child: AnimatedOpacity(
                              duration: const Duration(
                                milliseconds:
                                    MonitoringScreen.tooltipFadeAnimMs,
                              ),
                              opacity: _tooltipVisible ? 1.0 : 0.0,
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: 8,
                                    top: 0,
                                    child: ClipPath(
                                      clipper: _TriangleClipper(),
                                      child: Container(
                                        width: 14,
                                        height: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 7),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.12,
                                          ),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 18,
                                          color: MonitoringScreen.darkGreen,
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            MonitoringScreen
                                                .tooltipDiagnosticInfo,
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.4,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightLabel(String val, bool isInProgress) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: isInProgress
          ? MonitoringScreen.progressHighlightBg
          : MonitoringScreen.normalHighlightBg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.bolt_rounded,
          size: 12,
          color: isInProgress ? MonitoringScreen.darkGreen : Colors.black54,
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: isInProgress ? MonitoringScreen.darkGreen : Colors.black,
          ),
        ),
      ],
    ),
  );

  Widget _buildDashedLine() {
    return Row(
      children: List.generate(
        30,
        (i) => Expanded(
          child: Container(
            height: 1.5,
            color: i % 2 == 0 ? Colors.black12 : Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _DegradationLineChartPainter extends CustomPainter {
  final Color lineColor;
  final List<DegradationYearPoint> points;

  _DegradationLineChartPainter({required this.lineColor, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    void drawHorizontalDashedLine(Canvas canvas, Offset p1, Offset p2) {
      final Paint dashPaint = Paint()
        ..color = Colors.black12
        ..strokeWidth = 1.5;

      const double dashWidth = 7.0;
      const double dashSpace = 6.5;
      final double distance = (p2 - p1).distance;
      final Offset direction = (p2 - p1) / distance;

      double currentDistance = 0;
      bool draw = true;

      while (currentDistance < distance) {
        final double step = draw ? dashWidth : dashSpace;
        final double nextDistance = (currentDistance + step).clamp(
          0.0,
          distance,
        );

        if (draw) {
          canvas.drawLine(
            p1 + direction * currentDistance,
            p1 + direction * nextDistance,
            dashPaint,
          );
        }
        currentDistance = nextDistance;
        draw = !draw;
      }
    }

    void drawVerticalDashedLine(Canvas canvas, Offset p1, Offset p2) {
      final Paint dashPaint = Paint()
        ..color = Colors.black12
        ..strokeWidth = 1.2;

      const double dashWidth = 3.0;
      const double dashSpace = 3.0;
      final double distance = (p2 - p1).distance;
      final Offset direction = (p2 - p1) / distance;

      double currentDistance = 0;
      bool draw = true;

      while (currentDistance < distance) {
        final double step = draw ? dashWidth : dashSpace;
        final double nextDistance = (currentDistance + step).clamp(
          0.0,
          distance,
        );

        if (draw) {
          canvas.drawLine(
            p1 + direction * currentDistance,
            p1 + direction * nextDistance,
            dashPaint,
          );
        }
        currentDistance = nextDistance;
        draw = !draw;
      }
    }

    for (int quartile = 0; quartile <= 3; quartile++) {
      final double yPos = size.height * (quartile * 0.25);
      drawHorizontalDashedLine(
        canvas,
        Offset(0, yPos),
        Offset(size.width, yPos),
      );
    }

    final List<Offset> renderPoints = [];
    final int count = points.length;

    for (int i = 0; i < count; i++) {
      final double x = count > 1 ? (size.width / (count - 1)) * i : 0.0;
      final double y = size.height * (1.0 - points[i].efficiencyRatio);
      renderPoints.add(Offset(x, y));
    }

    for (final point in renderPoints) {
      drawVerticalDashedLine(
        canvas,
        Offset(point.dx, point.dy),
        Offset(point.dx, size.height),
      );
    }

    final Paint areaPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final Path areaPath = Path();
    areaPath.moveTo(renderPoints[0].dx, renderPoints[0].dy);

    for (int i = 1; i < renderPoints.length; i++) {
      final double controlX = (renderPoints[i - 1].dx + renderPoints[i].dx) / 2;
      areaPath.cubicTo(
        controlX,
        renderPoints[i - 1].dy,
        controlX,
        renderPoints[i].dy,
        renderPoints[i].dx,
        renderPoints[i].dy,
      );
    }

    areaPath.lineTo(size.width, size.height);
    areaPath.lineTo(0, size.height);
    areaPath.close();

    canvas.drawPath(areaPath, areaPaint);

    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path();
    path.moveTo(renderPoints[0].dx, renderPoints[0].dy);

    for (int i = 1; i < renderPoints.length; i++) {
      final double controlX = (renderPoints[i - 1].dx + renderPoints[i].dx) / 2;
      path.cubicTo(
        controlX,
        renderPoints[i - 1].dy,
        controlX,
        renderPoints[i].dy,
        renderPoints[i].dx,
        renderPoints[i].dy,
      );
    }

    canvas.drawPath(path, linePaint);

    final Paint circlePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (final point in renderPoints) {
      canvas.drawCircle(point, 4, circlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
