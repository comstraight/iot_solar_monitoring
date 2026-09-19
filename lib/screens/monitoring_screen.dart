import 'dart:async';
import 'package:flutter/material.dart';

class BarData {
  final String time;
  final double val;
  final bool isHighlight;
  final String peakVal;

  const BarData({
    required this.time,
    required this.val,
    required this.isHighlight,
    this.peakVal = '',
  });
}

class DailyRecord {
  final String date;
  final String totalKwh;
  final String estimatedSavings;
  final List<BarData> bars;

  const DailyRecord({
    required this.date,
    required this.totalKwh,
    required this.estimatedSavings,
    required this.bars,
  });
}

class DegradationYearPoint {
  final String yearLabel;
  final double efficiencyRatio; // Value between 0.0 and 1.0 (100% scale)

  const DegradationYearPoint({
    required this.yearLabel,
    required this.efficiencyRatio,
  });
}

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  // Theme Constants
  static const Color darkGreen = Color(0xFF20831B);
  static const Color accentOrange = Color(0xFFF1A12A);
  static const Color pageBg = Color(0xFFF4F4F4);
  static const Color cardBg = Color(0xFFEBEBEB);

  // Controllers & Keys
  late final PageController _pageController;
  late final ScrollController _scrollController;
  final GlobalKey _questionMarkKey = GlobalKey();

  int _currentRecordIndex = 2; // Default to latest day (Index 2)
  int _degradationSlideIndex =
      1; // Default to latest historical slide (2020 - 2026)
  bool _showPanelNameInAppBar = false;

  // Tooltip Overlay & Fade States
  bool _showTooltip = false;
  bool _tooltipVisible = false;
  Timer? _fadeTimer;

  // Hardcoded Telemetry Dataset
  final List<DailyRecord> _dailyRecords = const [
    DailyRecord(
      date: 'Sep 15, 2026',
      totalKwh: '610',
      estimatedSavings: '₱ 3,660.00',
      bars: [
        BarData(time: '6AM', val: 0.35, isHighlight: false),
        BarData(time: '7AM', val: 0.45, isHighlight: false),
        BarData(time: '8AM', val: 0.65, isHighlight: false),
        BarData(time: '9AM', val: 0.40, isHighlight: false),
        BarData(time: '10AM', val: 0.85, isHighlight: true, peakVal: '310 kWh'),
        BarData(time: '11AM', val: 0.70, isHighlight: false),
        BarData(time: '12PM', val: 0.40, isHighlight: false),
      ],
    ),
    DailyRecord(
      date: 'Sep 16, 2026',
      totalKwh: '680',
      estimatedSavings: '₱ 4,080.00',
      bars: [
        BarData(time: '6AM', val: 0.40, isHighlight: false),
        BarData(time: '7AM', val: 0.50, isHighlight: false),
        BarData(time: '8AM', val: 0.80, isHighlight: true, peakVal: '340 kWh'),
        BarData(time: '9AM', val: 0.55, isHighlight: false),
        BarData(time: '10AM', val: 0.65, isHighlight: false),
        BarData(time: '11AM', val: 0.60, isHighlight: false),
        BarData(time: '12PM', val: 0.45, isHighlight: false),
      ],
    ),
    DailyRecord(
      date: 'Sep 17, 2026 (Today)',
      totalKwh: '725',
      estimatedSavings: '₱ 4,350.00',
      bars: [
        BarData(time: '6AM', val: 0.45, isHighlight: false),
        BarData(time: '7AM', val: 0.55, isHighlight: false),
        BarData(time: '8AM', val: 0.75, isHighlight: false),
        BarData(time: '9AM', val: 0.38, isHighlight: false),
        BarData(time: '10AM', val: 0.75, isHighlight: false),
        BarData(time: '11AM', val: 1.00, isHighlight: true, peakVal: '360 kWh'),
        BarData(time: '12PM', val: 0.52, isHighlight: false),
      ],
    ),
  ];

  // Paginated Historical Solar Panel Degradation Data
  final List<List<DegradationYearPoint>> _degradationSlides = const [
    // Slide 1 (2014 to 2020)
    [
      DegradationYearPoint(yearLabel: '2014', efficiencyRatio: 1.00),
      DegradationYearPoint(yearLabel: '2015', efficiencyRatio: 0.98),
      DegradationYearPoint(yearLabel: '2016', efficiencyRatio: 0.96),
      DegradationYearPoint(yearLabel: '2017', efficiencyRatio: 0.94),
      DegradationYearPoint(yearLabel: '2018', efficiencyRatio: 0.92),
      DegradationYearPoint(yearLabel: '2019', efficiencyRatio: 0.90),
      DegradationYearPoint(yearLabel: '2020', efficiencyRatio: 0.88),
    ],
    // Slide 2 (2020 to 2026 - Current Year)
    [
      DegradationYearPoint(yearLabel: '2020', efficiencyRatio: 0.88),
      DegradationYearPoint(yearLabel: '2021', efficiencyRatio: 0.87),
      DegradationYearPoint(yearLabel: '2022', efficiencyRatio: 0.86),
      DegradationYearPoint(yearLabel: '2023', efficiencyRatio: 0.85),
      DegradationYearPoint(yearLabel: '2024', efficiencyRatio: 0.85),
      DegradationYearPoint(yearLabel: '2025', efficiencyRatio: 0.84),
      DegradationYearPoint(yearLabel: '2026', efficiencyRatio: 0.84),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentRecordIndex);
    _scrollController = ScrollController()..addListener(_onScroll);
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

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToPage(int index) {
    if (index >= 0 && index < _dailyRecords.length) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int safeIndex = _currentRecordIndex.clamp(
      0,
      _dailyRecords.length - 1,
    );
    final DailyRecord activeRecord = _dailyRecords[safeIndex];
    final DailyRecord latestRecord = _dailyRecords.last;

    // Active degradation slide data points
    final List<DegradationYearPoint> activeSlidePoints =
        _degradationSlides[_degradationSlideIndex];

    // PERSISTENT LATEST EFFICIENCY: Always shows current year reading (2026 -> 84%)
    final double persistentLatestEfficiency =
        _degradationSlides.last.last.efficiencyRatio;

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
                      _showPanelNameInAppBar ? 'SOLAR - 1' : 'Monitoring',
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
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Active',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'SOLAR - 1',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'In good condition',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
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
                          crossAxisAlignment: CrossAxisAlignment.baseline,
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
                          'Total Energy Production',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 180,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _dailyRecords.length,
                            onPageChanged: (index) {
                              setState(() => _currentRecordIndex = index);
                            },
                            itemBuilder: (context, recordIndex) {
                              final List<BarData> barData =
                                  _dailyRecords[recordIndex].bars;
                              return Stack(
                                children: [
                                  Positioned.fill(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildDashedLine(),
                                        _buildDashedLine(),
                                        _buildDashedLine(),
                                        _buildDashedLine(),
                                        const SizedBox(height: 20),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: List.generate(barData.length, (
                                      i,
                                    ) {
                                      final BarData item = barData[i];
                                      return Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            if (item.isHighlight)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                margin: const EdgeInsets.only(
                                                  bottom: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFDDDDDD,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  children: [
                                                    const Icon(
                                                      Icons.bolt_rounded,
                                                      size: 12,
                                                      color: Colors.black54,
                                                    ),
                                                    Text(
                                                      item.peakVal,
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              const SizedBox(height: 32),
                                            Container(
                                              width: 42,
                                              height: 100 * item.val,
                                              decoration: BoxDecoration(
                                                color: item.isHighlight
                                                    ? accentOrange
                                                    : darkGreen,
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(8),
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              item.time,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
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
                              if (_currentRecordIndex > 0)
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded),
                                  onPressed: () =>
                                      _navigateToPage(_currentRecordIndex - 1),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                )
                              else
                                const SizedBox(width: 24),
                              Text(
                                activeRecord.date,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              if (_currentRecordIndex <
                                  _dailyRecords.length - 1)
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded),
                                  onPressed: () =>
                                      _navigateToPage(_currentRecordIndex + 1),
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
                                latestRecord.estimatedSavings,
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
                                      children: const [
                                        Text(
                                          '0.45',
                                          style: TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
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

                                // QUESTION MARK BUTTON
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

                            // LINE GRAPH - EXACT 180 CANVAS HEIGHT MATCHING BAR GRAPH
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

                            // DYNAMIC X-AXIS LABELS (PURE YEARS ONLY)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: activeSlidePoints.map((p) {
                                final bool isCurrentYear =
                                    p.yearLabel == '2026';
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

                            // DEGRADATION MULTI-YEAR SLIDE NAVIGATOR
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
                                    '${activeSlidePoints.first.yearLabel} - ${activeSlidePoints.last.yearLabel}',
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

                            // PERSISTENT ESTIMATED PANEL EFFICIENCY BAR BELOW
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
                                      value: persistentLatestEfficiency,
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

                      // OVERLAY POPUP TOOLTIP
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
                                        color: Colors.black.withOpacity(0.12),
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
                                          'This info is gathered within a period of time with an advanced formula using data collected through different sensors and data gathered through the internet.',
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

// --- CUSTOM PAINTER WITH MATCHING HORIZONTAL DASH PATTERN (7px DASH, 6.5px GAP) ---
class _DegradationLineChartPainter extends CustomPainter {
  final Color lineColor;
  final List<DegradationYearPoint> points;

  _DegradationLineChartPainter({required this.lineColor, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    // Helper to draw horizontal dashed lines matching the loose bar-graph pattern
    void drawHorizontalDashedLine(Canvas canvas, Offset p1, Offset p2) {
      final Paint dashPaint = Paint()
        ..color = Colors.black12
        ..strokeWidth = 1.5;

      const double dashWidth = 7.0; // Increased to match wide bar-graph dashes
      const double dashSpace = 6.5; // Increased to match loose bar-graph gaps
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

    // Helper to draw subtle vertical dashed lines down to the baseline
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

    // 1. DRAW 4 HORIZONTAL QUARTILE GRID LINES (0%, 25%, 50%, 75%, 100%)
    for (int quartile = 0; quartile <= 3; quartile++) {
      final double yPos = size.height * (quartile * 0.25);
      drawHorizontalDashedLine(
        canvas,
        Offset(0, yPos),
        Offset(size.width, yPos),
      );
    }

    // MAP YEAR DATA RATIOS TO CANVAS PIXEL COORDINATES
    final List<Offset> renderPoints = [];
    final int count = points.length;

    for (int i = 0; i < count; i++) {
      final double x = count > 1 ? (size.width / (count - 1)) * i : 0.0;
      final double y = size.height * (1.0 - points[i].efficiencyRatio);
      renderPoints.add(Offset(x, y));
    }

    // 2. DRAW VERTICAL DOTTED LINES FROM DATA POINTS TO BASELINE
    for (final point in renderPoints) {
      drawVerticalDashedLine(
        canvas,
        Offset(point.dx, point.dy),
        Offset(point.dx, size.height),
      );
    }

    // 3. DRAW GRADIENT AREA FILL
    final Paint areaPaint = Paint()
      ..color = lineColor.withOpacity(0.12)
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

    // 4. DRAW MAIN BEZIER DEGRADATION TREND LINE
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

    // 5. DRAW DATA POINT CIRCLES
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
