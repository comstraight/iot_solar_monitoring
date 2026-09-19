import 'package:flutter/material.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AnalyticsScreen(),
    ),
  );
}

class BarData {
  final String label;
  final double val;
  final bool isHighlight;
  final String peakVal;

  const BarData({
    required this.label,
    required this.val,
    required this.isHighlight,
    this.peakVal = '',
  });
}

class AnalyticsRecord {
  final String title;
  final List<BarData> bars;

  const AnalyticsRecord({required this.title, required this.bars});
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const Color darkGreen = Color(0xFF20831B);
  static const Color accentOrange = Color(0xFFF1A12A);
  static const Color pageBg = Color(0xFFF4F4F4);
  static const Color cardBg = Color(0xFFEBEBEB);

  // Timeframe switch state (0: Daily, 1: Weekly, 2: Monthly, 3: Annually)
  int _selectedTimeframe = 0;

  // Single active PageController
  PageController? _pageController;

  // Indices tracking current page position for each dataset
  int _dailyIndex = 2;
  int _weeklyIndex = 1;
  int _monthlyIndex = 2;
  int _annualIndex = 1;

  // Persistent Latest Overall Stats
  final String _latestPowerGenerated = '725 kWh';
  final String _latestTotalEarnings = '₱ 4,350.00';

  // --- DATASETS ---
  final List<AnalyticsRecord> _dailyRecords = const [
    AnalyticsRecord(
      title: 'Sep 15, 2026',
      bars: [
        BarData(label: '6AM', val: 0.35, isHighlight: false),
        BarData(label: '7AM', val: 0.45, isHighlight: false),
        BarData(label: '8AM', val: 0.65, isHighlight: false),
        BarData(label: '9AM', val: 0.40, isHighlight: false),
        BarData(
          label: '10AM',
          val: 0.85,
          isHighlight: true,
          peakVal: '310 kWh',
        ),
        BarData(label: '11AM', val: 0.70, isHighlight: false),
        BarData(label: '12PM', val: 0.40, isHighlight: false),
      ],
    ),
    AnalyticsRecord(
      title: 'Sep 16, 2026',
      bars: [
        BarData(label: '6AM', val: 0.40, isHighlight: false),
        BarData(label: '7AM', val: 0.50, isHighlight: false),
        BarData(label: '8AM', val: 0.80, isHighlight: true, peakVal: '340 kWh'),
        BarData(label: '9AM', val: 0.55, isHighlight: false),
        BarData(label: '10AM', val: 0.65, isHighlight: false),
        BarData(label: '11AM', val: 0.60, isHighlight: false),
        BarData(label: '12PM', val: 0.45, isHighlight: false),
      ],
    ),
    AnalyticsRecord(
      title: 'Sep 17, 2026 (Today)',
      bars: [
        BarData(label: '6AM', val: 0.45, isHighlight: false),
        BarData(label: '7AM', val: 0.55, isHighlight: false),
        BarData(label: '8AM', val: 0.75, isHighlight: false),
        BarData(label: '9AM', val: 0.38, isHighlight: false),
        BarData(label: '10AM', val: 0.75, isHighlight: false),
        BarData(
          label: '11AM',
          val: 1.00,
          isHighlight: true,
          peakVal: '360 kWh',
        ),
        BarData(label: '12PM', val: 0.52, isHighlight: false),
      ],
    ),
  ];

  final List<AnalyticsRecord> _weeklyRecords = const [
    AnalyticsRecord(
      title: 'Aug 31 - Sep 06, 2026',
      bars: [
        BarData(label: 'Mon', val: 0.60, isHighlight: false),
        BarData(label: 'Tue', val: 0.70, isHighlight: false),
        BarData(label: 'Wed', val: 0.50, isHighlight: false),
        BarData(label: 'Thu', val: 0.80, isHighlight: false),
        BarData(label: 'Fri', val: 0.95, isHighlight: true, peakVal: '4.1 MWh'),
        BarData(label: 'Sat', val: 0.65, isHighlight: false),
        BarData(label: 'Sun', val: 0.40, isHighlight: false),
      ],
    ),
    AnalyticsRecord(
      title: 'Sep 07 - Sep 13, 2026 (Current Week)',
      bars: [
        BarData(label: 'Mon', val: 0.65, isHighlight: false),
        BarData(label: 'Tue', val: 0.75, isHighlight: false),
        BarData(label: 'Wed', val: 0.85, isHighlight: false),
        BarData(label: 'Thu', val: 0.90, isHighlight: true, peakVal: '4.3 MWh'),
        BarData(label: 'Fri', val: 0.80, isHighlight: false),
        BarData(label: 'Sat', val: 0.70, isHighlight: false),
        BarData(label: 'Sun', val: 0.60, isHighlight: false),
      ],
    ),
  ];

  final List<AnalyticsRecord> _monthlyRecords = const [
    AnalyticsRecord(
      title: 'July 2026',
      bars: [
        BarData(label: 'W1', val: 0.70, isHighlight: false),
        BarData(label: 'W2', val: 0.80, isHighlight: false),
        BarData(label: 'W3', val: 0.90, isHighlight: true, peakVal: '18 MWh'),
        BarData(label: 'W4', val: 0.75, isHighlight: false),
      ],
    ),
    AnalyticsRecord(
      title: 'August 2026',
      bars: [
        BarData(label: 'W1', val: 0.65, isHighlight: false),
        BarData(label: 'W2', val: 0.85, isHighlight: false),
        BarData(label: 'W3', val: 0.95, isHighlight: true, peakVal: '19.5 MWh'),
        BarData(label: 'W4', val: 0.80, isHighlight: false),
      ],
    ),
    AnalyticsRecord(
      title: 'September 2026 (Current Month)',
      bars: [
        BarData(label: 'W1', val: 0.75, isHighlight: false),
        BarData(label: 'W2', val: 0.88, isHighlight: true, peakVal: '21 MWh'),
        BarData(label: 'W3', val: 0.60, isHighlight: false),
        BarData(label: 'W4', val: 0.00, isHighlight: false),
      ],
    ),
  ];

  final List<AnalyticsRecord> _annualRecords = const [
    AnalyticsRecord(
      title: 'Year 2025',
      bars: [
        BarData(label: 'Q1', val: 0.70, isHighlight: false),
        BarData(label: 'Q2', val: 0.85, isHighlight: false),
        BarData(label: 'Q3', val: 0.95, isHighlight: true, peakVal: '240 MWh'),
        BarData(label: 'Q4', val: 0.80, isHighlight: false),
      ],
    ),
    AnalyticsRecord(
      title: 'Year 2026 (Current Year)',
      bars: [
        BarData(label: 'Q1', val: 0.80, isHighlight: false),
        BarData(label: 'Q2', val: 0.90, isHighlight: false),
        BarData(label: 'Q3', val: 1.00, isHighlight: true, peakVal: '265 MWh'),
        BarData(label: 'Q4', val: 0.30, isHighlight: false),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initControllerForTimeframe();
  }

  void _initControllerForTimeframe() {
    _pageController?.dispose();
    _pageController = PageController(initialPage: _activeIndex);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  List<AnalyticsRecord> get _activeRecords {
    switch (_selectedTimeframe) {
      case 1:
        return _weeklyRecords;
      case 2:
        return _monthlyRecords;
      case 3:
        return _annualRecords;
      case 0:
      default:
        return _dailyRecords;
    }
  }

  int get _activeIndex {
    switch (_selectedTimeframe) {
      case 1:
        return _weeklyIndex.clamp(0, _weeklyRecords.length - 1);
      case 2:
        return _monthlyIndex.clamp(0, _monthlyRecords.length - 1);
      case 3:
        return _annualIndex.clamp(0, _annualRecords.length - 1);
      case 0:
      default:
        return _dailyIndex.clamp(0, _dailyRecords.length - 1);
    }
  }

  void _updateActiveIndex(int newIndex) {
    setState(() {
      switch (_selectedTimeframe) {
        case 0:
          _dailyIndex = newIndex;
          break;
        case 1:
          _weeklyIndex = newIndex;
          break;
        case 2:
          _monthlyIndex = newIndex;
          break;
        case 3:
          _annualIndex = newIndex;
          break;
      }
    });
  }

  void _navigateToPage(int index) {
    if (index >= 0 &&
        index < _activeRecords.length &&
        _pageController != null) {
      _pageController!.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onTimeframeChanged(int newTimeframe) {
    if (_selectedTimeframe != newTimeframe) {
      setState(() {
        _selectedTimeframe = newTimeframe;
        _initControllerForTimeframe();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeRecord = _activeRecords[_activeIndex];

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: pageBg,
        toolbarHeight: 70,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCircularIcon(
              Icons.arrow_back_rounded,
              () => Navigator.maybePop(context),
            ),
            const Text(
              'Analytics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            _buildCircularIcon(Icons.bar_chart_rounded, null),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeframeSelector(),
            const SizedBox(height: 20),
            _buildPersistentKpiRow(),
            const SizedBox(height: 20),
            const Text(
              'Energy Output Trend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            _buildGraphCard(activeRecord),
            const SizedBox(height: 24),
            const Text(
              'Battery Diagnostics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            _buildBatteryDiagnosticsCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularIcon(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: 48,
        decoration: const BoxDecoration(color: cardBg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.black87, size: 22),
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    final tabs = ['Daily', 'Weekly', 'Monthly', 'Annually'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTimeframe == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onTimeframeChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? darkGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tabs[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPersistentKpiRow() {
    return Row(
      children: [
        _buildKpiBox(
          'Total Power',
          _latestPowerGenerated,
          Icons.bolt_rounded,
          darkGreen,
        ),
        const SizedBox(width: 12),
        _buildKpiBox(
          'Total Earnings',
          _latestTotalEarnings,
          Icons.payments_rounded,
          Colors.teal,
        ),
      ],
    );
  }

  Widget _buildKpiBox(String label, String value, IconData icon, Color color) {
    return Expanded(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Icon(icon, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphCard(AnalyticsRecord activeRecord) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            child: PageView.builder(
              key: ValueKey<int>(_selectedTimeframe),
              controller: _pageController,
              itemCount: _activeRecords.length,
              onPageChanged: _updateActiveIndex,
              itemBuilder: (context, recordIndex) {
                final barData = _activeRecords[recordIndex].bars;
                return Column(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              4,
                              (_) => _buildDashedLine(),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: barData.map<Widget>((item) {
                              return Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (item.isHighlight)
                                      _buildHighlightLabel(item.peakVal),
                                    Container(
                                      width: 42,
                                      height: 110 * item.val,
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
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: barData.map<Widget>((item) {
                        return Expanded(
                          child: Center(
                            child: Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
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
          _buildNavControls(activeRecord.title),
        ],
      ),
    );
  }

  Widget _buildHighlightLabel(String val) => Container(
    padding: const EdgeInsets.all(4),
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFDDDDDD),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      val,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );

  Widget _buildNavControls(String title) {
    final bool canGoBack = _activeIndex > 0;
    final bool canGoForward = _activeIndex < _activeRecords.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          canGoBack
              ? IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _navigateToPage(_activeIndex - 1),
                )
              : const SizedBox(width: 48),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          canGoForward
              ? IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _navigateToPage(_activeIndex + 1),
                )
              : const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBatteryDiagnosticsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildDiagnosticItem(
            label: 'State of Charge (SOC)',
            valueText: '88%',
            progressValue: 0.88,
            progressColor: darkGreen,
            icon: Icons.battery_charging_full_rounded,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Colors.black12),
          ),
          _buildDiagnosticItem(
            label: 'State of Health (SOH)',
            valueText: '96%',
            progressValue: 0.96,
            progressColor: Colors.teal,
            icon: Icons.favorite_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticItem({
    required String label,
    required String valueText,
    required double progressValue,
    required Color progressColor,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: progressColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            Text(
              valueText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: progressColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progressValue,
            minHeight: 10,
            backgroundColor: Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }

  Widget _buildDashedLine() => Row(
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
