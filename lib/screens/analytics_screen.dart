import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  final String systemId;

  const AnalyticsScreen({super.key, this.systemId = 'solar_system_01'});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const Color darkGreen = Color(0xFF20831B);
  static const Color accentOrange = Color(0xFFF1A12A);
  static const Color pageBg = Color(0xFFF4F4F4);
  static const Color cardBg = Color(0xFFEBEBEB);

  int _selectedTimeframe = 0; // 0: Daily, 1: Weekly, 2: Annually
  PageController? _pageController;
  int _activePageIndex = 0;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Map<int, List<String>> _expectedLabels = {
    0: ['3AM', '6AM', '9AM', '12NN', '3PM', '6PM', '9PM', '12AM'],
    1: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    2: [
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
    ],
  };

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _onTimeframeChanged(int newTimeframe) {
    if (_selectedTimeframe != newTimeframe) {
      setState(() {
        _selectedTimeframe = newTimeframe;
        _activePageIndex = 0;
        _pageController?.dispose();
        _pageController = PageController(initialPage: 0);
      });
    }
  }

  void _navigateToPage(int index, int totalRecords) {
    if (index >= 0 && index < totalRecords && _pageController != null) {
      _pageController!.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getCollectionName() {
    switch (_selectedTimeframe) {
      case 1:
        return 'weekly';
      case 2:
        return 'annually';
      case 0:
      default:
        return 'daily';
    }
  }

  List<AnalyticsRecord> _parseRecordsFromFirestore(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    double graphCeilingLimit,
  ) {
    if (docs.isEmpty) return [];

    List<AnalyticsRecord> records = [];

    if (_selectedTimeframe == 2) {
      // Annual split into First Half / Second Half documents
      for (var doc in docs) {
        final data = doc.data();

        // Process First Half
        if (data.containsKey('firstHalf')) {
          final firstHalf = data['firstHalf'] as Map<String, dynamic>? ?? {};
          final title = firstHalf['title'] as String? ?? 'First Half';
          final barsMap = (firstHalf['bars'] as Map<String, dynamic>?) ?? {};
          final labels = _expectedLabels[2]!.sublist(0, 6);
          records.add(
            _buildRecordFromMap(title, labels, barsMap, graphCeilingLimit),
          );
        }

        // Process Second Half
        if (data.containsKey('secondHalf')) {
          final secondHalf = data['secondHalf'] as Map<String, dynamic>? ?? {};
          final title = secondHalf['title'] as String? ?? 'Second Half';
          final barsMap = (secondHalf['bars'] as Map<String, dynamic>?) ?? {};
          final labels = _expectedLabels[2]!.sublist(6, 12);
          records.add(
            _buildRecordFromMap(title, labels, barsMap, graphCeilingLimit),
          );
        }
      }
    } else {
      // Daily & Weekly docs
      final labels = _expectedLabels[_selectedTimeframe]!;
      for (var doc in docs) {
        final data = doc.data();
        final title = data['title'] as String? ?? doc.id;
        final barsMap = (data['bars'] as Map<String, dynamic>?) ?? {};
        records.add(
          _buildRecordFromMap(title, labels, barsMap, graphCeilingLimit),
        );
      }
    }

    return records;
  }

  AnalyticsRecord _buildRecordFromMap(
    String title,
    List<String> labels,
    Map<String, dynamic> rawBars,
    double ratedCeiling,
  ) {
    double peakVal = 0.0;
    Map<String, double> parsedValues = {};

    for (var label in labels) {
      double val = (rawBars[label] as num?)?.toDouble() ?? 0.0;
      parsedValues[label] = val;
      if (val > peakVal) peakVal = val;
    }

    double graphCeiling = ratedCeiling > 0
        ? ratedCeiling
        : (peakVal > 0 ? peakVal : 1.0);
    if (peakVal > graphCeiling) graphCeiling = peakVal;

    List<BarData> bars = labels.map((label) {
      double rawVal = parsedValues[label]!;
      bool isPeak = peakVal > 0 && rawVal == peakVal;

      return BarData(
        label: label,
        val: graphCeiling > 0 ? (rawVal / graphCeiling).clamp(0.0, 1.0) : 0.0,
        isHighlight: isPeak,
        peakVal: isPeak ? '${rawVal.toStringAsFixed(1)} kWh' : '',
      );
    }).toList();

    return AnalyticsRecord(title: title, bars: bars);
  }

  @override
  Widget build(BuildContext context) {
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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.collection('system_status').doc('current').snapshots(),
        builder: (context, statusSnapshot) {
          final statusData = statusSnapshot.data?.data() ?? {};

          // Live KPIs
          final totalPower =
              '${(statusData['total_kwh_today'] as num?)?.toStringAsFixed(1) ?? '0.0'} kWh';
          final totalEarnings =
              '₱ ${(statusData['estimated_savings_php'] as num?)?.toStringAsFixed(1) ?? '0.0'}';

          // Battery Diagnostics
          final batteryData =
              (statusData['battery'] as Map<String, dynamic>?) ?? {};
          final double soc =
              ((batteryData['soc'] ?? batteryData['soc_percent'] ?? 0.0) as num)
                  .toDouble() /
              100.0;
          final double soh =
              ((batteryData['soh'] ?? batteryData['soh_percent'] ?? 0.0) as num)
                  .toDouble() /
              100.0;

          // Panel capacity calculation for dynamic graph limit
          double ratedMaxCapacityWatts = 0.0;
          final panelsMap = statusData['panels'] as Map<String, dynamic>? ?? {};
          panelsMap.forEach((key, panelObj) {
            if (panelObj is Map<String, dynamic>) {
              num cap =
                  panelObj['metadata']?['rated_power_w'] ??
                  panelObj['rated_power_w'] ??
                  300.0;
              ratedMaxCapacityWatts += cap.toDouble();
            }
          });
          double ratedMaxCapacityKw = ratedMaxCapacityWatts > 0
              ? (ratedMaxCapacityWatts / 1000.0)
              : 0.6;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimeframeSelector(),
                const SizedBox(height: 20),
                _buildPersistentKpiRow(totalPower, totalEarnings),
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

                // Dynamic Firestore Chart Stream
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db
                      .collection('analytics')
                      .doc(widget.systemId)
                      .collection(_getCollectionName())
                      .snapshots(),
                  builder: (context, chartSnapshot) {
                    if (chartSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return _buildChartLoadingState();
                    }

                    final docs = chartSnapshot.data?.docs ?? [];
                    final records = _parseRecordsFromFirestore(
                      docs,
                      ratedMaxCapacityKw,
                    );

                    if (records.isEmpty) {
                      return _buildEmptyChartCard();
                    }

                    return _buildGraphCard(records);
                  },
                ),

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
                _buildBatteryDiagnosticsCard(soc: soc, soh: soh),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
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
    final tabs = ['Daily', 'Weekly', 'Annually'];
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
                    fontSize: 13,
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

  Widget _buildPersistentKpiRow(String power, String earnings) {
    return Row(
      children: [
        _buildKpiBox('Total Power', power, Icons.bolt_rounded, darkGreen),
        const SizedBox(width: 12),
        _buildKpiBox(
          'Total Earnings',
          earnings,
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

  Widget _buildGraphCard(List<AnalyticsRecord> records) {
    final safeActiveIndex = _activePageIndex.clamp(0, records.length - 1);
    final activeRecord = records[safeActiveIndex];

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
            height: 230,
            child: PageView.builder(
              key: ValueKey<int>(_selectedTimeframe),
              controller: _pageController,
              itemCount: records.length,
              onPageChanged: (index) {
                setState(() => _activePageIndex = index);
              },
              itemBuilder: (context, recordIndex) {
                final barData = records[recordIndex].bars;
                return Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const double topHeadroom = 28.0;
                          final double availableBarHeight =
                              constraints.maxHeight - topHeadroom;

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
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(
                                    5,
                                    (_) => _buildDashedLine(),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: topHeadroom,
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: barData.map<Widget>((item) {
                                    final calculatedBarHeight =
                                        availableBarHeight *
                                        item.val.clamp(0.0, 1.0);
                                    return Expanded(
                                      child: Stack(
                                        alignment: Alignment.bottomCenter,
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 20,
                                            height: calculatedBarHeight,
                                            decoration: BoxDecoration(
                                              color: item.isHighlight
                                                  ? accentOrange
                                                  : darkGreen,
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(6),
                                                  ),
                                            ),
                                          ),
                                          if (item.isHighlight &&
                                              item.peakVal.isNotEmpty)
                                            Positioned(
                                              bottom: calculatedBarHeight + 6,
                                              child: _buildHighlightLabel(
                                                item.peakVal,
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
                                color: item.val == 0.0 && !item.isHighlight
                                    ? Colors.black38
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
          _buildNavControls(
            activeRecord.title,
            records.length,
            safeActiveIndex,
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightLabel(String val) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFDDDDDD),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      val,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );

  Widget _buildNavControls(String title, int totalRecords, int currentIndex) {
    final bool canGoBack = currentIndex > 0;
    final bool canGoForward = currentIndex < totalRecords - 1;

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
                  onPressed: () =>
                      _navigateToPage(currentIndex - 1, totalRecords),
                )
              : const SizedBox(width: 48),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          canGoForward
              ? IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () =>
                      _navigateToPage(currentIndex + 1, totalRecords),
                )
              : const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBatteryDiagnosticsCard({
    required double soc,
    required double soh,
  }) {
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
            valueText: '${(soc * 100).toInt()}%',
            progressValue: soc.clamp(0.0, 1.0),
            progressColor: darkGreen,
            icon: Icons.battery_charging_full_rounded,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Colors.black12),
          ),
          _buildDiagnosticItem(
            label: 'State of Health (SOH)',
            valueText: '${(soh * 100).toInt()}%',
            progressValue: soh.clamp(0.0, 1.0),
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

  Widget _buildChartLoadingState() => Container(
    height: 250,
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(28),
    ),
    child: const Center(child: CircularProgressIndicator(color: darkGreen)),
  );

  Widget _buildEmptyChartCard() => Container(
    height: 250,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(28),
    ),
    child: const Center(
      child: Text(
        'No generation data recorded yet.',
        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
      ),
    ),
  );
}
