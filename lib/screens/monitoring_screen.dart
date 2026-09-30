import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BarData {
  final String label;
  final double
  val; // Dynamic ratio (0.0 to 1.0) scaled against specific panel capacity/peak
  final bool isHighlight;
  final bool isInProgress;
  final String peakVal; // Display text for peak bar (e.g., "280 W")

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
  final double efficiencyRatio; // Ratio (0.0 to 1.0)

  const DegradationYearPoint({
    required this.yearLabel,
    required this.efficiencyRatio,
  });
}

class MonitoringScreen extends StatefulWidget {
  final String panelId;

  const MonitoringScreen({
    super.key,
    this.panelId = 'panel_01', // Scoped to specific panel
  });

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  // Theme Constants
  static const Color darkGreen = Color(0xFF20831B);
  static const Color lightGreen = Color(0xFF66BB6A);
  static const Color accentOrange = Color(0xFFF1A12A);
  static const Color pageBg = Color(0xFFF4F4F4);
  static const Color cardBg = Color(0xFFEBEBEB);

  // Timeframe & Page Controllers
  int _selectedTimeframe = 0; // 0: Daily, 1: Weekly, 2: Annually
  late PageController _pageController;
  int _activePageIndex = 0;

  // Controllers & Keys
  late final ScrollController _scrollController;
  final GlobalKey _questionMarkKey = GlobalKey();

  int _degradationSlideIndex = 0;
  bool _showPanelNameInAppBar = false;

  // Panel Condition & Status Options
  String _selectedCondition = 'In good condition';
  String _selectedStatus = 'Active';

  // Tooltip Overlay & Fade States
  bool _showTooltip = false;
  bool _tooltipVisible = false;
  Timer? _fadeTimer;

  // Live Stream Subscriptions
  StreamSubscription<DocumentSnapshot>? _statusSubscription;
  StreamSubscription<QuerySnapshot>? _analyticsSubscription;

  // Panel Data State
  String _panelName = 'SOLAR - 1';
  double _panelRatedPowerW = 300.0;
  double _annualDegradationRate = 0.45;
  double _currentEfficiencyRatio = 1.0;

  // Dynamic Datasets fetched from Firestore
  List<MonitoringRecord> _dailyRecords = [];
  List<MonitoringRecord> _weeklyRecords = [];
  List<MonitoringRecord> _annualRecords = [];
  List<List<DegradationYearPoint>> _degradationSlides = [[]];

  @override
  void initState() {
    super.initState();
    _activePageIndex = 0;
    _pageController = PageController(initialPage: _activePageIndex);
    _scrollController = ScrollController()..addListener(_onScroll);

    _listenToPanelFirestore();
  }

  void _listenToPanelFirestore() {
    // 1. Listen to Specific Panel Details in Live System Status
    _statusSubscription = FirebaseFirestore.instance
        .collection('system_status')
        .doc('current')
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) return;

          final data = snapshot.data() as Map<String, dynamic>;
          final panels = data['panels'] as Map<String, dynamic>? ?? {};

          if (panels.containsKey(widget.panelId)) {
            final panelDoc = panels[widget.panelId] as Map<String, dynamic>;
            final metadata =
                panelDoc['metadata'] as Map<String, dynamic>? ?? {};
            final diagnostics =
                panelDoc['diagnostics'] as Map<String, dynamic>? ?? {};

            final historyRaw = (diagnostics['degrade_history'] as List?) ?? [];
            List<DegradationYearPoint> points = historyRaw.map((e) {
              final m = e as Map<String, dynamic>;
              return DegradationYearPoint(
                yearLabel: m['yearLabel']?.toString() ?? '',
                efficiencyRatio:
                    (m['efficiencyRatio'] as num?)?.toDouble() ?? 1.0,
              );
            }).toList();

            setState(() {
              _panelName = panelDoc['panel_name'] ?? widget.panelId;
              _panelRatedPowerW =
                  (metadata['rated_power_w'] as num?)?.toDouble() ?? 300.0;
              _annualDegradationRate =
                  (diagnostics['degradation_rate_annual'] as num?)
                      ?.toDouble() ??
                  0.45;
              _currentEfficiencyRatio =
                  (diagnostics['current_efficiency_ratio'] as num?)
                      ?.toDouble() ??
                  1.0;

              if (points.isNotEmpty) {
                _degradationSlides = [points];
                _degradationSlideIndex = 0;
              }
            });
          }
        });

    // 2. Listen to Scoped Panel Analytics History
    final timeframeCol = _selectedTimeframe == 0
        ? 'daily'
        : _selectedTimeframe == 1
        ? 'weekly'
        : 'annually';

    _analyticsSubscription?.cancel();
    _analyticsSubscription = FirebaseFirestore.instance
        .collection('analytics')
        .doc(widget.panelId)
        .collection(timeframeCol)
        .snapshots()
        .listen((snapshot) {
          _processAnalyticsSnapshot(snapshot);
        });
  }

  void _processAnalyticsSnapshot(QuerySnapshot snapshot) {
    if (snapshot.docs.isEmpty) return;

    List<MonitoringRecord> records = [];

    if (_selectedTimeframe == 2) {
      // Ported annual halving logic from AnalyticsScreen
      final monthNames = [
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

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final yearId = doc.id;
        final barsRaw = data['bars'] as Map<String, dynamic>? ?? {};

        // 1. First Half (Jan - Jun)
        double firstHalfTotal = 0.0;
        double firstHalfPeak = 0.0;
        for (int m = 1; m <= 6; m++) {
          final monthKey = monthNames[m - 1];
          final rawVal = barsRaw[monthKey];
          double v = 0.0;
          if (rawVal is Map) {
            v =
                (rawVal['raw_kwh'] as num?)?.toDouble() ??
                (rawVal['val'] as num?)?.toDouble() ??
                0.0;
          } else if (rawVal is num) {
            v = rawVal.toDouble();
          }
          firstHalfTotal += v;
          if (v > firstHalfPeak) firstHalfPeak = v;
        }

        final firstHalfCeiling = max(
          _panelRatedPowerW / 1000.0,
          firstHalfPeak > 0 ? firstHalfPeak : 1.0,
        );

        List<BarData> firstHalfBars = [];
        for (int m = 1; m <= 6; m++) {
          final monthKey = monthNames[m - 1];
          final rawVal = barsRaw[monthKey];
          double v = 0.0;
          String displayLabel = '';
          if (rawVal is Map) {
            v =
                (rawVal['raw_kwh'] as num?)?.toDouble() ??
                (rawVal['val'] as num?)?.toDouble() ??
                0.0;
            displayLabel = rawVal['displayLabel']?.toString() ?? '';
          } else if (rawVal is num) {
            v = rawVal.toDouble();
          }

          final heightRatio = (v / firstHalfCeiling).clamp(0.0, 1.0);
          final isPeak = firstHalfPeak > 0 && v == firstHalfPeak;

          firstHalfBars.add(
            BarData(
              label: monthKey,
              val: heightRatio,
              isHighlight: isPeak,
              peakVal: isPeak
                  ? (displayLabel.isNotEmpty
                        ? displayLabel
                        : '${(v * 1000).toInt()} W')
                  : '',
            ),
          );
        }

        records.add(
          MonitoringRecord(
            title: '$yearId - First Half',
            bars: firstHalfBars,
            totalKwh: firstHalfTotal.toStringAsFixed(0),
          ),
        );

        // 2. Second Half (Jul - Dec)
        double secondHalfTotal = 0.0;
        double secondHalfPeak = 0.0;
        for (int m = 7; m <= 12; m++) {
          final monthKey = monthNames[m - 1];
          final rawVal = barsRaw[monthKey];
          double v = 0.0;
          if (rawVal is Map) {
            v =
                (rawVal['raw_kwh'] as num?)?.toDouble() ??
                (rawVal['val'] as num?)?.toDouble() ??
                0.0;
          } else if (rawVal is num) {
            v = rawVal.toDouble();
          }
          secondHalfTotal += v;
          if (v > secondHalfPeak) secondHalfPeak = v;
        }

        final secondHalfCeiling = max(
          _panelRatedPowerW / 1000.0,
          secondHalfPeak > 0 ? secondHalfPeak : 1.0,
        );

        List<BarData> secondHalfBars = [];
        for (int m = 7; m <= 12; m++) {
          final monthKey = monthNames[m - 1];
          final rawVal = barsRaw[monthKey];
          double v = 0.0;
          String displayLabel = '';
          if (rawVal is Map) {
            v =
                (rawVal['raw_kwh'] as num?)?.toDouble() ??
                (rawVal['val'] as num?)?.toDouble() ??
                0.0;
            displayLabel = rawVal['displayLabel']?.toString() ?? '';
          } else if (rawVal is num) {
            v = rawVal.toDouble();
          }

          final heightRatio = (v / secondHalfCeiling).clamp(0.0, 1.0);
          final isPeak = secondHalfPeak > 0 && v == secondHalfPeak;

          secondHalfBars.add(
            BarData(
              label: monthKey,
              val: heightRatio,
              isHighlight: isPeak,
              peakVal: isPeak
                  ? (displayLabel.isNotEmpty
                        ? displayLabel
                        : '${(v * 1000).toInt()} W')
                  : '',
            ),
          );
        }

        records.add(
          MonitoringRecord(
            title: '$yearId - Second Half',
            bars: secondHalfBars,
            totalKwh: secondHalfTotal.toStringAsFixed(0),
          ),
        );
      }
    } else {
      // Standard processing for Daily and Weekly views
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final title = data['title'] as String? ?? '';
        final totalKwh =
            (data['totalKwh'] as num?)?.toDouble().toStringAsFixed(0) ?? '0';
        final barsRaw = data['bars'] as Map<String, dynamic>? ?? {};

        double peakVal = 0.0;
        barsRaw.forEach((key, val) {
          double v = 0.0;
          if (val is Map) {
            v =
                (val['raw_kwh'] as num?)?.toDouble() ??
                (val['val'] as num?)?.toDouble() ??
                0.0;
          } else if (val is num) {
            v = val.toDouble();
          }
          if (v > peakVal) peakVal = v;
        });

        final ceiling = max(
          _panelRatedPowerW / 1000.0,
          peakVal > 0 ? peakVal : 1.0,
        );

        List<BarData> bars = [];
        barsRaw.forEach((key, val) {
          double rawVal = 0.0;
          String displayLabel = '';

          if (val is Map) {
            rawVal =
                (val['raw_kwh'] as num?)?.toDouble() ??
                (val['val'] as num?)?.toDouble() ??
                0.0;
            displayLabel = val['displayLabel']?.toString() ?? '';
          } else if (val is num) {
            rawVal = val.toDouble();
          }

          final heightRatio = (rawVal / ceiling).clamp(0.0, 1.0);
          final isPeak = peakVal > 0 && rawVal == peakVal;

          bars.add(
            BarData(
              label: key,
              val: heightRatio,
              isHighlight: isPeak,
              peakVal: isPeak
                  ? (displayLabel.isNotEmpty
                        ? displayLabel
                        : '${(rawVal * 1000).toInt()} W')
                  : '',
            ),
          );
        });

        records.add(
          MonitoringRecord(title: title, bars: bars, totalKwh: totalKwh),
        );
      }
    }

    setState(() {
      if (_selectedTimeframe == 0) {
        _dailyRecords = records;
      } else if (_selectedTimeframe == 1) {
        _weeklyRecords = records;
      } else {
        _annualRecords = records;
      }
      _activePageIndex = records.isNotEmpty ? records.length - 1 : 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_activePageIndex);
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
      });
      _listenToPanelFirestore();
    }
  }

  void _onScroll() {
    final isScrolledPast =
        _scrollController.hasClients && _scrollController.offset > 120;
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

    _fadeTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _tooltipVisible = false;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          _showTooltip = false;
          _fadeTimer = null;
        });
      });
    });
  }

  void _showSensorStatusModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final sensors = [
          {'name': 'Light Sensor', 'working': true},
          {
            'name': 'Temperature Sensor',
            'working': _selectedStatus != 'Sensor Problems',
          },
          {'name': 'Humidity Sensor', 'working': true},
        ];

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sensor Diagnostics',
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
                          fontSize: 16,
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
                            isWorking ? 'Working' : 'Error',
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
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToPage(int index, int totalRecords) {
    if (index >= 0 && index < totalRecords && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildTimeframeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
          dropdownColor: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(16),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Daily')),
            DropdownMenuItem(value: 1, child: Text('Weekly')),
            DropdownMenuItem(value: 2, child: Text('Annually')),
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
        : const MonitoringRecord(title: 'Loading...', bars: []);
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

    final Color statusColor = _selectedStatus == 'Sensor Problems'
        ? Colors.red
        : _selectedStatus == 'Inactive'
        ? Colors.grey
        : Colors.green;

    return Listener(
      onPointerDown: (_) => _triggerFadeTimerOnTouch(),
      child: Scaffold(
        backgroundColor: pageBg,
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: pageBg,
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
                        color: cardBg,
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
                    duration: const Duration(milliseconds: 200),
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
                      _showPanelNameInAppBar ? _panelName : 'Monitoring',
                      key: ValueKey<bool>(_showPanelNameInAppBar),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF81E27C),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.power_settings_new_rounded,
                      color: Colors.green,
                      size: 22,
                    ),
                  ),
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
                  // --- STATUS CARD ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: _showSensorStatusModal,
                              child: Row(
                                children: [
                                  Container(
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
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCondition,
                                isDense: true,
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'In good condition',
                                    child: Text('In good condition'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'In fair condition',
                                    child: Text('In fair condition'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'In bad condition',
                                    child: Text('In bad condition'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedCondition = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.solar_power_rounded,
                          size: 56,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Performance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- BAR CHART CARD ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
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
                                    Text(
                                      activeRecord.totalKwh,
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'kWh',
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
                                  'Energy Production',
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
                              ? const Center(child: CircularProgressIndicator())
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
                                              final double availableBarHeight =
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
                                                        if (item.isInProgress) {
                                                          barColor = lightGreen;
                                                        } else if (item
                                                            .isHighlight) {
                                                          barColor =
                                                              accentOrange;
                                                        } else {
                                                          barColor = darkGreen;
                                                        }

                                                        return Expanded(
                                                          child: Stack(
                                                            alignment: Alignment
                                                                .bottomCenter,
                                                            clipBehavior:
                                                                Clip.none,
                                                            children: [
                                                              Container(
                                                                width: 40,
                                                                height:
                                                                    calculatedBarHeight,
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      barColor,
                                                                  borderRadius:
                                                                      const BorderRadius.vertical(
                                                                        top:
                                                                            Radius.circular(
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
                                          children: barData.map<Widget>((item) {
                                            return Expanded(
                                              child: Center(
                                                child: Text(
                                                  item.label,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: item.isInProgress
                                                        ? darkGreen
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
                            color: const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (safeIndex > 0)
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded),
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
                                  icon: const Icon(Icons.chevron_right_rounded),
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
                  const SizedBox(height: 16),

                  // --- PERSISTENT SUMMARY KPI BOXES ---
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: cardBg,
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
                                    'Total Energy',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE8F5E9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.bolt_rounded,
                                      size: 16,
                                      color: darkGreen,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    latestRecord.totalKwh,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'kWh',
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
                            color: cardBg,
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
                                    'Total Savings',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE0F2F1),
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
                              Text(
                                '₱ ${(double.parse(latestRecord.totalKwh.isEmpty ? "0" : latestRecord.totalKwh) * 6).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: darkGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- DEGRADATION DIAGNOSTICS CARD ---
                  const Text(
                    'Panel Health Diagnostics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          _annualDegradationRate
                                              .toStringAsFixed(2),
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          '% / yr',
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
                                      'Degradation Rate',
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
                                            ? darkGreen
                                            : Colors.grey.shade400,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.help_outline_rounded,
                                      size: 18,
                                      color: _showTooltip
                                          ? darkGreen
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
                                  lineColor: darkGreen,
                                  points: activeSlidePoints,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                        ? darkGreen
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
                                color: const Color(0xFFE0E0E0),
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
                                        'Estimated Panel Efficiency',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        '${(persistentLatestEfficiency * 100).toInt()}%',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: darkGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: persistentLatestEfficiency.clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      minHeight: 10,
                                      backgroundColor: const Color(0xFFE0E0E0),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            darkGreen,
                                          ),
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
                            duration: const Duration(milliseconds: 300),
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
                                        color: darkGreen,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'This info is gathered within a period of time with an advanced formula using data collected through different sensors and data gathered using the internet.',
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
      color: isInProgress ? const Color(0xFFC8E6C9) : const Color(0xFFDDDDDD),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.bolt_rounded,
          size: 12,
          color: isInProgress ? darkGreen : Colors.black54,
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: isInProgress ? darkGreen : Colors.black,
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
