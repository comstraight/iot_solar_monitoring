import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// FIRESTORE GROUP / SITE MODEL (Matching server.py 'groups' schema)
// -----------------------------------------------------------------------------
class SiteModel {
  final String groupId;
  final String groupName;
  final int groupOrder;

  const SiteModel({
    required this.groupId,
    required this.groupName,
    required this.groupOrder,
  });

  /// Deserializes Firestore map format from backend:
  /// {"group_id": "site_01", "group_name": "Main Solar Farm", "group_order": 0}
  factory SiteModel.fromFirestore(Map<String, dynamic> json, String docId) {
    return SiteModel(
      groupId: json['group_id'] as String? ?? docId,
      groupName: json['group_name'] as String? ?? 'Unnamed Site',
      groupOrder: (json['group_order'] as num?)?.toInt() ?? 0,
    );
  }
}

// -----------------------------------------------------------------------------
// FIRESTORE SUMMARY DOCUMENT MODEL (Pre-aggregated by server.py)
// -----------------------------------------------------------------------------
class AnalyticsDocModel {
  final String id;
  final String title;
  final double totalKwh;
  final Map<String, double> bars;

  AnalyticsDocModel({
    required this.id,
    required this.title,
    required this.totalKwh,
    required this.bars,
  });

  factory AnalyticsDocModel.fromFirestore(
    Map<String, dynamic> json,
    String docId,
  ) {
    final barsMap = (json['bars'] as Map<String, dynamic>?) ?? {};
    final parsedBars = barsMap.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );
    final total = (json['totalKwh'] as num?)?.toDouble() ?? 0.0;
    final title = json['title'] as String? ?? docId;

    return AnalyticsDocModel(
      id: docId,
      title: title,
      totalKwh: total,
      bars: parsedBars,
    );
  }
}

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

class AnalyticsRecord {
  final String title;
  final List<BarData> bars;
  final String totalKwh;

  const AnalyticsRecord({
    required this.title,
    required this.bars,
    this.totalKwh = '0.0',
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AnalyticsScreen(),
    );
  }
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const Color darkGreen = Color(0xFF20831B);
  static const Color lightGreen = Color(0xFF66BB6A);
  static const Color accentOrange = Color(0xFFF1A12A);
  static const Color pageBg = Color(0xFFF4F4F4);
  static const Color cardBg = Color(0xFFEBEBEB);

  int _selectedTimeframe = 0; // 0: Daily, 1: Weekly, 2: Annually
  late PageController _pageController;
  int _activePageIndex = 0;

  List<AnalyticsDocModel> _dailyDocs = [];
  List<AnalyticsDocModel> _weeklyDocs = [];
  List<AnalyticsDocModel> _annualDocs = [];

  double _totalSystemKw = 0.9; // Dynamic fallback for 3x300W system (0.9 kW)
  final DateTime _latestDate = DateTime.now();

  List<SiteModel> _sites = [
    const SiteModel(groupId: 'all', groupName: 'All Sites', groupOrder: 0),
  ];
  late SiteModel _selectedSite;
  bool _isLoadingSites = true;
  bool _isLoadingReadings = true;

  @override
  void initState() {
    super.initState();
    _selectedSite = _sites.first;
    _pageController = PageController(initialPage: 0);
    _loadFirestoreSites();
    _loadFirestoreAnalytics();
  }

  /// Fetches sites dynamically from Firestore 'groups' collection
  Future<void> _loadFirestoreSites() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('groups')
          .orderBy('group_order')
          .get();

      final fetchedSites = snapshot.docs
          .map((doc) => SiteModel.fromFirestore(doc.data(), doc.id))
          .toList();

      setState(() {
        _sites = [
          const SiteModel(
            groupId: 'all',
            groupName: 'All Sites',
            groupOrder: 0,
          ),
          ...fetchedSites,
        ];
        _isLoadingSites = false;
      });
    } catch (e) {
      debugPrint('Error fetching Firestore sites: $e');
      setState(() => _isLoadingSites = false);
    }
  }

  /// Fetches pre-aggregated analytics documents directly from Firestore
  Future<void> _loadFirestoreAnalytics() async {
    setState(() => _isLoadingReadings = true);

    try {
      final targetId = _selectedSite.groupId == 'all'
          ? 'solar_system_01'
          : _selectedSite.groupId;

      // 1. Fetch system status to read current total system rated power
      try {
        final statusDoc = await FirebaseFirestore.instance
            .collection('system_status')
            .doc('current')
            .get();

        if (statusDoc.exists) {
          final data = statusDoc.data();
          if (data != null && data.containsKey('total_system_kw')) {
            _totalSystemKw = (data['total_system_kw'] as num).toDouble();
          } else if (data != null && data.containsKey('panels')) {
            final panels = data['panels'] as Map<String, dynamic>? ?? {};
            double kwSum = 0.0;
            panels.forEach((_, pData) {
              if (pData is Map<String, dynamic>) {
                final meta = pData['metadata'] as Map<String, dynamic>?;
                if (meta != null && meta.containsKey('rated_power_w')) {
                  kwSum += (meta['rated_power_w'] as num).toDouble() / 1000.0;
                }
              }
            });
            if (kwSum > 0) _totalSystemKw = kwSum;
          }
        }
      } catch (e) {
        debugPrint('Error fetching system capacity: $e');
      }

      // 2. Fetch Daily Analytics Summaries
      final dailySnapshot = await FirebaseFirestore.instance
          .collection('analytics')
          .doc(targetId)
          .collection('daily')
          .get();

      final fetchedDaily = dailySnapshot.docs
          .map((doc) => AnalyticsDocModel.fromFirestore(doc.data(), doc.id))
          .toList();
      fetchedDaily.sort((a, b) => a.id.compareTo(b.id));

      // 3. Fetch Weekly Analytics Summaries
      final weeklySnapshot = await FirebaseFirestore.instance
          .collection('analytics')
          .doc(targetId)
          .collection('weekly')
          .get();

      final fetchedWeekly = weeklySnapshot.docs
          .map((doc) => AnalyticsDocModel.fromFirestore(doc.data(), doc.id))
          .toList();
      fetchedWeekly.sort((a, b) => a.id.compareTo(b.id));

      // 4. Fetch Annual Analytics Summaries
      final annualSnapshot = await FirebaseFirestore.instance
          .collection('analytics')
          .doc(targetId)
          .collection('annually')
          .get();

      final fetchedAnnual = annualSnapshot.docs
          .map((doc) => AnalyticsDocModel.fromFirestore(doc.data(), doc.id))
          .toList();
      fetchedAnnual.sort((a, b) => a.id.compareTo(b.id));

      setState(() {
        _dailyDocs = fetchedDaily;
        _weeklyDocs = fetchedWeekly;
        _annualDocs = fetchedAnnual;
        _isLoadingReadings = false;
      });
    } catch (e) {
      debugPrint('Error fetching Firestore analytics: $e');
      setState(() => _isLoadingReadings = false);
    }
  }

  double get _currentYearTotalPower {
    final currentYear = _latestDate.year;
    final doc = _annualDocs.cast<AnalyticsDocModel?>().firstWhere(
      (d) => d!.id == '$currentYear',
      orElse: () => null,
    );
    if (doc != null) {
      return doc.totalKwh;
    }
    return _dailyDocs.fold(0.0, (sum, doc) => sum + doc.totalKwh);
  }

  List<AnalyticsRecord> _buildRecordsForTimeframe(int timeframe) {
    switch (timeframe) {
      case 0:
        return _buildDailyRecords();
      case 1:
        return _buildWeeklyRecords();
      case 2:
      default:
        return _buildAnnualRecords();
    }
  }

  List<AnalyticsRecord> _buildDailyRecords() {
    if (_dailyDocs.isEmpty) return [];

    final recent7 = _dailyDocs.length > 7
        ? _dailyDocs.sublist(_dailyDocs.length - 7)
        : _dailyDocs;

    final timeBuckets = ['6AM', '9AM', '12NN', '3PM', '6PM'];

    // Expected 3-hr bucket capacity (kW * 3hrs * 85% efficiency factor)
    final expectedBucketMax = _totalSystemKw > 0
        ? _totalSystemKw * 3.0 * 0.85
        : 2.3;

    return List.generate(recent7.length, (index) {
      final doc = recent7[index];

      double peakVal = 0.0;
      for (var b in timeBuckets) {
        final v = doc.bars[b] ?? 0.0;
        if (v > peakVal) peakVal = v;
      }

      final dailyDivisor = max(expectedBucketMax, peakVal > 0 ? peakVal : 1.0);

      final bars = timeBuckets.map((b) {
        final val = doc.bars[b] ?? 0.0;
        final isPeak = peakVal > 0 && val == peakVal;
        return BarData(
          label: b,
          val: (val / dailyDivisor).clamp(0.0, 1.0),
          isHighlight: isPeak,
          peakVal: isPeak ? '${val.toStringAsFixed(1)} kWh' : '',
        );
      }).toList();

      String titleText = doc.title;
      if (index == recent7.length - 1) {
        titleText = '${doc.title} (Today)';
      } else if (index == recent7.length - 2) {
        titleText = '${doc.title} (Yesterday)';
      }

      return AnalyticsRecord(
        title: titleText,
        bars: bars,
        totalKwh: doc.totalKwh.toStringAsFixed(1),
      );
    });
  }

  List<AnalyticsRecord> _buildWeeklyRecords() {
    if (_weeklyDocs.isEmpty) return [];

    final weekLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    // Dynamic daily max capacity based on system kW and 5.0 Peak Sun Hours
    final expectedDailyMax = _totalSystemKw > 0 ? _totalSystemKw * 5.0 : 4.5;

    final daysSinceSun = (_latestDate.weekday % 7);
    final todayLabel = weekLabels[daysSinceSun];

    return _weeklyDocs.map((doc) {
      double peakVal = 0.0;
      for (var day in weekLabels) {
        final v = doc.bars[day] ?? 0.0;
        if (v > peakVal) peakVal = v;
      }

      final weeklyDivisor = max(expectedDailyMax, peakVal > 0 ? peakVal : 1.0);

      final bars = weekLabels.map((day) {
        final val = doc.bars[day] ?? 0.0;
        final isToday = day == todayLabel && doc.id == _weeklyDocs.last.id;
        final isPeak = peakVal > 0 && val == peakVal && !isToday;

        return BarData(
          label: day,
          val: (val / weeklyDivisor).clamp(0.0, 1.0),
          isHighlight: isPeak,
          isInProgress: isToday,
          peakVal: isPeak
              ? '${val.toStringAsFixed(1)} kWh'
              : (isToday ? '${val.toStringAsFixed(1)} kWh' : ''),
        );
      }).toList();

      return AnalyticsRecord(
        title: doc.title,
        bars: bars,
        totalKwh: doc.totalKwh.toStringAsFixed(1),
      );
    }).toList();
  }

  List<AnalyticsRecord> _buildAnnualRecords() {
    if (_annualDocs.isEmpty) return [];

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

    // Dynamic expected monthly max yield based on system kW, 5.0 PSH, and 30 days
    final expectedMonthlyMax = _totalSystemKw > 0
        ? _totalSystemKw * 5.0 * 30.0
        : 135.0;

    List<AnalyticsRecord> records = [];

    for (var doc in _annualDocs) {
      // First Half (Jan - Jun)
      double firstHalfTotal = 0.0;
      double firstHalfPeak = 0.0;
      for (int m = 1; m <= 6; m++) {
        final monthKey = monthNames[m - 1];
        final v = doc.bars[monthKey] ?? 0.0;
        firstHalfTotal += v;
        if (v > firstHalfPeak) firstHalfPeak = v;
      }

      final firstHalfDivisor = max(
        expectedMonthlyMax,
        firstHalfPeak > 0 ? firstHalfPeak : 1.0,
      );

      List<BarData> firstHalfBars = [];
      for (int m = 1; m <= 6; m++) {
        final monthKey = monthNames[m - 1];
        final v = doc.bars[monthKey] ?? 0.0;
        final isPeak = firstHalfPeak > 0 && v == firstHalfPeak;
        firstHalfBars.add(
          BarData(
            label: monthKey,
            val: (v / firstHalfDivisor).clamp(0.0, 1.0),
            isHighlight: isPeak,
            peakVal: isPeak ? '${v.toStringAsFixed(0)} kWh' : '',
          ),
        );
      }

      records.add(
        AnalyticsRecord(
          title: '${doc.id} - First Half',
          bars: firstHalfBars,
          totalKwh: firstHalfTotal.toStringAsFixed(0),
        ),
      );

      // Second Half (Jul - Dec)
      double secondHalfTotal = 0.0;
      double secondHalfPeak = 0.0;
      for (int m = 7; m <= 12; m++) {
        final monthKey = monthNames[m - 1];
        final v = doc.bars[monthKey] ?? 0.0;
        secondHalfTotal += v;
        if (v > secondHalfPeak) secondHalfPeak = v;
      }

      final secondHalfDivisor = max(
        expectedMonthlyMax,
        secondHalfPeak > 0 ? secondHalfPeak : 1.0,
      );

      List<BarData> secondHalfBars = [];
      for (int m = 7; m <= 12; m++) {
        final monthKey = monthNames[m - 1];
        final v = doc.bars[monthKey] ?? 0.0;
        final isPeak = secondHalfPeak > 0 && v == secondHalfPeak;
        secondHalfBars.add(
          BarData(
            label: monthKey,
            val: (v / secondHalfDivisor).clamp(0.0, 1.0),
            isHighlight: isPeak,
            peakVal: isPeak ? '${v.toStringAsFixed(0)} kWh' : '',
          ),
        );
      }

      records.add(
        AnalyticsRecord(
          title: '${doc.id} - Second Half',
          bars: secondHalfBars,
          totalKwh: secondHalfTotal.toStringAsFixed(0),
        ),
      );
    }

    return records;
  }

  void _onTimeframeChanged(int newTimeframe) {
    if (_selectedTimeframe != newTimeframe) {
      final records = _buildRecordsForTimeframe(newTimeframe);
      int targetPage = 0;
      if (newTimeframe == 0) {
        targetPage = records.isNotEmpty ? records.length - 1 : 0;
      }
      if (newTimeframe == 2 && records.length > 1) {
        targetPage = 1;
      }

      final oldController = _pageController;
      setState(() {
        _selectedTimeframe = newTimeframe;
        _activePageIndex = targetPage;
        _pageController = PageController(initialPage: targetPage);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController.dispose();
      });
    }
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

  void _showSiteSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: pageBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Site',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.black54,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoadingSites)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: darkGreen),
                  ),
                )
              else
                ..._sites.map((site) {
                  final isSelected = site.groupId == _selectedSite.groupId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected ? darkGreen.withOpacity(0.12) : cardBg,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isSelected
                            ? const BorderSide(color: darkGreen, width: 1.5)
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.location_on_rounded,
                          color: isSelected ? darkGreen : Colors.black45,
                        ),
                        title: Text(
                          site.groupName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected ? darkGreen : Colors.black87,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: darkGreen,
                              )
                            : const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.black38,
                              ),
                        onTap: () {
                          setState(() {
                            _selectedSite = site;
                          });
                          Navigator.pop(context);
                          _loadFirestoreAnalytics();
                        },
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortfolioHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Portfolio',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        InkWell(
          onTap: _showSiteSelectionModal,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: darkGreen,
                ),
                const SizedBox(width: 6),
                Text(
                  _selectedSite.groupName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.unfold_more_rounded,
                  size: 16,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentYearPower = _currentYearTotalPower;
    final currentYearSavings = currentYearPower * 12.0;

    final records = _buildRecordsForTimeframe(_selectedTimeframe);

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
            _buildCircularIcon(Icons.arrow_back_rounded),
            const Text(
              'Metrics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            _buildCircularIcon(Icons.bar_chart_rounded),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPortfolioHeader(),
            const SizedBox(height: 12),
            _buildPersistentKpiRow(
              '${currentYearPower.toStringAsFixed(1)} kWh',
              '₱ ${currentYearSavings.toStringAsFixed(1)}',
            ),
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
            if (_isLoadingReadings)
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: darkGreen),
                ),
              )
            else if (records.isEmpty)
              _buildEmptyChartCard()
            else
              _buildGraphCard(records),
            if (_selectedSite.groupId != 'all') ...[
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
              _buildBatteryDiagnosticsCard(soc: 0.85, soh: 0.98),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularIcon(IconData icon) {
    return Container(
      height: 48,
      width: 48,
      decoration: const BoxDecoration(color: cardBg, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.black87, size: 22),
    );
  }

  Widget _buildTimeframeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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

  Widget _buildPersistentKpiRow(String power, String earnings) {
    return Row(
      children: [
        _buildKpiBox(
          'Total Power (${_latestDate.year})',
          power,
          Icons.bolt_rounded,
          darkGreen,
        ),
        const SizedBox(width: 12),
        _buildKpiBox(
          'Est. Savings (${_latestDate.year})',
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
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
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
                ],
              ),
              _buildTimeframeDropdown(),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 220,
            child: PageView.builder(
              key: ValueKey<int>(_selectedTimeframe),
              controller: _pageController,
              itemCount: records.length,
              onPageChanged: (index) =>
                  setState(() => _activePageIndex = index),
              itemBuilder: (context, recordIndex) {
                final barData = records[recordIndex].bars;
                return Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const double topHeadroom = 36.0;
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

                                    Color barColor;
                                    if (item.isInProgress) {
                                      barColor = lightGreen;
                                    } else if (item.isHighlight) {
                                      barColor = accentOrange;
                                    } else {
                                      barColor = darkGreen;
                                    }

                                    return Expanded(
                                      child: Stack(
                                        alignment: Alignment.bottomCenter,
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: calculatedBarHeight,
                                            decoration: BoxDecoration(
                                              color: barColor,
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(8),
                                                  ),
                                            ),
                                          ),
                                          if (item.peakVal.isNotEmpty)
                                            Positioned(
                                              bottom: calculatedBarHeight + 6,
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
          _buildNavControls(
            activeRecord.title,
            records.length,
            safeActiveIndex,
          ),
        ],
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
            'State of Charge (SOC)',
            '${(soc * 100).toInt()}%',
            soc,
            darkGreen,
            Icons.battery_charging_full_rounded,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Colors.black12),
          ),
          _buildDiagnosticItem(
            'State of Health (SOH)',
            '${(soh * 100).toInt()}%',
            soh,
            Colors.teal,
            Icons.favorite_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticItem(
    String label,
    String valueText,
    double progressValue,
    Color progressColor,
    IconData icon,
  ) {
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

  Widget _buildEmptyChartCard() => Container(
    height: 250,
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


//finally done