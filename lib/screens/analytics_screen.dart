import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class SiteModel {
  final String groupId;
  final String groupName;
  final int groupOrder;

  const SiteModel({
    required this.groupId,
    required this.groupName,
    required this.groupOrder,
  });

  factory SiteModel.fromFirestore(Map<String, dynamic> json, String docId) {
    return SiteModel(
      groupId: json['group_id'] as String? ?? docId,
      groupName:
          json['group_name'] as String? ??
          json['name'] as String? ??
          'Unnamed Site',
      groupOrder: (json['group_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class OverviewGroupItem {
  final String groupId;
  final String groupName;
  final double kwh;

  const OverviewGroupItem({
    required this.groupId,
    required this.groupName,
    required this.kwh,
  });

  factory OverviewGroupItem.fromFirestore(Map<String, dynamic> json) {
    return OverviewGroupItem(
      groupId: json['group_id'] as String? ?? '',
      groupName:
          json['group_name'] as String? ??
          json['name'] as String? ??
          'Unnamed Site',
      kwh: (json['kwh'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

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
    final parsedBars = barsMap.map((k, v) {
      if (v is Map) {
        return MapEntry(
          k,
          (v['val'] as num?)?.toDouble() ??
              (v['raw_kwh'] as num?)?.toDouble() ??
              0.0,
        );
      }
      return MapEntry(k, (v as num).toDouble());
    });
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
  final String? initialSiteId;
  final String? initialSiteName;

  const AnalyticsScreen({super.key, this.initialSiteId, this.initialSiteName});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const Color darkGreen = Color(0xFF20831B);
  static const Color lightGreen = Color(0xFF66BB6A);
  static const Color accentOrange = Color(0xFFF1A12A);
  static const Color pageBg = Color(0xFFF4F4F4);
  static const Color cardBg = Color(0xFFEBEBEB);

  static const List<Color> _outputOverviewColors = [
    Color(0xFF52EA3A),
    Color(0xFF65B738),
    Color(0xFF2E6B12),
    Color(0xFF0F2D06),
  ];

  int _selectedTimeframe = 0; // 0: Daily, 1: Weekly, 2: Annually
  late PageController _pageController;
  int _activePageIndex = 0;

  List<AnalyticsDocModel> _dailyDocs = [];
  List<AnalyticsDocModel> _weeklyDocs = [];
  List<AnalyticsDocModel> _annualDocs = [];

  List<OverviewGroupItem> _dailyOverview = [];
  List<OverviewGroupItem> _weeklyOverview = [];
  List<OverviewGroupItem> _annualOverview = [];

  // Dynamic system capacity and electricity tariff rate fetched from backend
  double _totalSystemKw = 0.0;
  double _tariffRate = 12.0;

  final DateTime _latestDate = DateTime.now();

  List<SiteModel> _sites = [
    const SiteModel(groupId: 'all', groupName: 'All Sites', groupOrder: 0),
  ];
  Map<String, double> _siteOutputs = {};
  late SiteModel _selectedSite;
  bool _isLoadingSites = true;
  bool _isLoadingReadings = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    if (widget.initialSiteId != null && widget.initialSiteName != null) {
      _selectedSite = SiteModel(
        groupId: widget.initialSiteId!,
        groupName: widget.initialSiteName!,
        groupOrder: 0,
      );
    } else {
      _selectedSite = _sites.first;
    }

    _loadFirestoreSites();
    _loadFirestoreAnalytics();
  }

  /// Fetches sites & system status dynamically from Firestore system_status/current
  Future<void> _loadFirestoreSites() async {
    try {
      final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

      final docSnap = await FirebaseFirestore.instance
          .collection('system_status')
          .doc('current')
          .get();

      List<SiteModel> fetchedSites = [];
      Map<String, double> calculatedOutputs = {};

      List<OverviewGroupItem> fetchedDailyOverview = [];
      List<OverviewGroupItem> fetchedWeeklyOverview = [];
      List<OverviewGroupItem> fetchedAnnualOverview = [];

      double dynamicSystemKw = 0.0;
      double dynamicTariff = 12.0;

      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;
        final groupsMap = data['groups'] as Map<String, dynamic>? ?? {};
        final panelsMap = data['panels'] as Map<String, dynamic>? ?? {};

        // Extract dynamic tariff rate and rated system capacity from server.py document
        if (data.containsKey('tariff_rate_per_kwh')) {
          dynamicTariff = (data['tariff_rate_per_kwh'] as num).toDouble();
        }
        if (data.containsKey('total_system_kw')) {
          dynamicSystemKw = (data['total_system_kw'] as num).toDouble();
        }

        final overviewMap =
            data['output_overview'] as Map<String, dynamic>? ?? {};
        final rawDaily = (overviewMap['daily'] as List<dynamic>?) ?? [];
        final rawWeekly = (overviewMap['weekly'] as List<dynamic>?) ?? [];
        final rawAnnual = (overviewMap['annually'] as List<dynamic>?) ?? [];

        fetchedDailyOverview = rawDaily
            .where((item) => item is Map<String, dynamic>)
            .map(
              (item) =>
                  OverviewGroupItem.fromFirestore(item as Map<String, dynamic>),
            )
            .toList();
        fetchedWeeklyOverview = rawWeekly
            .where((item) => item is Map<String, dynamic>)
            .map(
              (item) =>
                  OverviewGroupItem.fromFirestore(item as Map<String, dynamic>),
            )
            .toList();
        fetchedAnnualOverview = rawAnnual
            .where((item) => item is Map<String, dynamic>)
            .map(
              (item) =>
                  OverviewGroupItem.fromFirestore(item as Map<String, dynamic>),
            )
            .toList();

        groupsMap.forEach((gId, gData) {
          if (gData is Map<String, dynamic>) {
            final groupOwner = gData['owner_uid'] ?? gData['ownerUid'];
            final groupName = (gData['group_name'] ?? gData['name'] ?? '')
                .toString();

            double siteKw = 0.0;
            panelsMap.forEach((pId, pData) {
              if (pData is Map<String, dynamic>) {
                final pGroup = pData['group']?.toString();
                if (pGroup == gId || pGroup == groupName) {
                  final sensorData =
                      pData['sensor_data'] as Map<String, dynamic>?;
                  if (sensorData != null &&
                      sensorData.containsKey('output_power_w')) {
                    siteKw +=
                        (sensorData['output_power_w'] as num).toDouble() /
                        1000.0;
                  }
                }
              }
            });
            calculatedOutputs[gId] = siteKw;

            final hasMemberPanel = panelsMap.values.any((p) {
              if (p is Map<String, dynamic>) {
                final pGroup = p['group']?.toString();
                final pOwner = p['owner_uid'] ?? p['ownerUid'];
                return (pGroup == gId || pGroup == groupName) &&
                    (pOwner == currentUid || currentUid == null);
              }
              return false;
            });

            if (groupOwner == currentUid ||
                hasMemberPanel ||
                currentUid == null) {
              fetchedSites.add(SiteModel.fromFirestore(gData, gId));
            }
          }
        });

        fetchedSites.sort((a, b) => a.groupOrder.compareTo(b.groupOrder));
      }

      setState(() {
        _sites = [
          const SiteModel(
            groupId: 'all',
            groupName: 'All Sites',
            groupOrder: 0,
          ),
          ...fetchedSites,
        ];

        _tariffRate = dynamicTariff;
        if (dynamicSystemKw > 0) {
          _totalSystemKw = dynamicSystemKw;
        }

        _siteOutputs = calculatedOutputs;
        _dailyOverview = fetchedDailyOverview;
        _weeklyOverview = fetchedWeeklyOverview;
        _annualOverview = fetchedAnnualOverview;

        if (widget.initialSiteId != null) {
          final matched = _sites.firstWhere(
            (s) => s.groupId == widget.initialSiteId,
            orElse: () => _selectedSite,
          );
          _selectedSite = matched;
        }

        _isLoadingSites = false;
      });
    } catch (e) {
      debugPrint('Error fetching Firestore sites: $e');
      setState(() => _isLoadingSites = false);
    }
  }

  /// Fetches analytics documents targeting user-specific or group-specific collections
  Future<void> _loadFirestoreAnalytics() async {
    setState(() => _isLoadingReadings = true);

    try {
      final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

      String targetId;
      if (_selectedSite.groupId == 'all') {
        targetId = (currentUid != null && currentUid.isNotEmpty)
            ? 'user_$currentUid'
            : 'solar_system_01';
      } else {
        targetId = _selectedSite.groupId;
      }

      // Calculate total system capacity dynamically if not present
      try {
        final statusDoc = await FirebaseFirestore.instance
            .collection('system_status')
            .doc('current')
            .get();

        if (statusDoc.exists) {
          final data = statusDoc.data();
          if (data != null && data.containsKey('panels')) {
            final panels = data['panels'] as Map<String, dynamic>? ?? {};
            double kwSum = 0.0;
            panels.forEach((_, pData) {
              if (pData is Map<String, dynamic>) {
                final pOwner = pData['owner_uid'] ?? pData['ownerUid'];
                if (currentUid == null || pOwner == currentUid) {
                  final meta = pData['metadata'] as Map<String, dynamic>?;
                  if (meta != null && meta.containsKey('rated_power_w')) {
                    kwSum += (meta['rated_power_w'] as num).toDouble() / 1000.0;
                  }
                }
              }
            });
            if (kwSum > 0) _totalSystemKw = kwSum;
          }
        }
      } catch (e) {
        debugPrint('Error fetching system capacity: $e');
      }

      // Fetch Daily Analytics Summaries
      var dailySnapshot = await FirebaseFirestore.instance
          .collection('analytics')
          .doc(targetId)
          .collection('daily')
          .get();

      if (dailySnapshot.docs.isEmpty && targetId != 'solar_system_01') {
        dailySnapshot = await FirebaseFirestore.instance
            .collection('analytics')
            .doc('solar_system_01')
            .collection('daily')
            .get();
      }

      final fetchedDaily = dailySnapshot.docs
          .map((doc) => AnalyticsDocModel.fromFirestore(doc.data(), doc.id))
          .toList();
      fetchedDaily.sort((a, b) => a.id.compareTo(b.id));

      // Fetch Weekly Analytics Summaries
      var weeklySnapshot = await FirebaseFirestore.instance
          .collection('analytics')
          .doc(targetId)
          .collection('weekly')
          .get();

      if (weeklySnapshot.docs.isEmpty && targetId != 'solar_system_01') {
        weeklySnapshot = await FirebaseFirestore.instance
            .collection('analytics')
            .doc('solar_system_01')
            .collection('weekly')
            .get();
      }

      final fetchedWeekly = weeklySnapshot.docs
          .map((doc) => AnalyticsDocModel.fromFirestore(doc.data(), doc.id))
          .toList();
      fetchedWeekly.sort((a, b) => a.id.compareTo(b.id));

      // Fetch Annual Analytics Summaries
      var annualSnapshot = await FirebaseFirestore.instance
          .collection('analytics')
          .doc(targetId)
          .collection('annually')
          .get();

      if (annualSnapshot.docs.isEmpty && targetId != 'solar_system_01') {
        annualSnapshot = await FirebaseFirestore.instance
            .collection('analytics')
            .doc('solar_system_01')
            .collection('annually')
            .get();
      }

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
    final expectedBucketMax = _totalSystemKw > 0
        ? _totalSystemKw * 3.0 * 0.85
        : 1.0;

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
    final expectedDailyMax = _totalSystemKw > 0 ? _totalSystemKw * 5.0 : 1.0;

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

    final expectedMonthlyMax = _totalSystemKw > 0
        ? _totalSystemKw * 5.0 * 30.0
        : 1.0;

    List<AnalyticsRecord> records = [];

    for (var doc in _annualDocs) {
      // First Half
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

      // Second Half
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
    // Dynamic electricity tariff multiplier replacing hardcoded 12.0
    final currentYearSavings = currentYearPower * _tariffRate;

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
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: _buildCircularIcon(Icons.arrow_back_rounded),
            ),
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
            const SizedBox(height: 24),
            const Text(
              'Output Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            _buildOutputOverviewCard(),
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

  Widget _buildOutputOverviewCard() {
    List<OverviewGroupItem> currentOverview;
    switch (_selectedTimeframe) {
      case 0:
        currentOverview = _dailyOverview;
        break;
      case 1:
        currentOverview = _weeklyOverview;
        break;
      case 2:
      default:
        currentOverview = _annualOverview;
        break;
    }

    List<OverviewGroupItem> displayItems = [];

    if (_selectedSite.groupId == 'all') {
      if (currentOverview.isNotEmpty) {
        displayItems = currentOverview.take(4).toList();
      } else {
        final nonAllSites = _sites.where((s) => s.groupId != 'all').toList();
        final sortedSites = List<SiteModel>.from(nonAllSites)
          ..sort(
            (a, b) => (_siteOutputs[b.groupId] ?? 0.0).compareTo(
              _siteOutputs[a.groupId] ?? 0.0,
            ),
          );
        displayItems = sortedSites.take(4).map((s) {
          return OverviewGroupItem(
            groupId: s.groupId,
            groupName: s.groupName,
            kwh: _siteOutputs[s.groupId] ?? 0.0,
          );
        }).toList();
      }
    } else {
      final match = currentOverview.firstWhere(
        (item) => item.groupId == _selectedSite.groupId,
        orElse: () => OverviewGroupItem(
          groupId: _selectedSite.groupId,
          groupName: _selectedSite.groupName,
          kwh: _siteOutputs[_selectedSite.groupId] ?? 0.0,
        ),
      );
      displayItems = [match];
    }

    List<double> values = [];
    double totalOutput = 0.0;
    for (var item in displayItems) {
      values.add(item.kwh);
      totalOutput += item.kwh;
    }

    if (totalOutput <= 0.0 &&
        _currentYearTotalPower > 0.0 &&
        displayItems.isNotEmpty) {
      final share = _currentYearTotalPower / displayItems.length;
      values = List.filled(displayItems.length, share);
      totalOutput = _currentYearTotalPower;
    }

    final bool isNoData = displayItems.isEmpty || totalOutput <= 0.0;
    final bool isSingleSite = displayItems.length == 1 && !isNoData;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: DonutChartPainter(
                values: values,
                colors: _outputOverviewColors,
                isNoData: isNoData,
                isSingleSite: isSingleSite,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: SizedBox(
              height: 140,
              child: Column(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child: index < displayItems.length
                          ? Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isNoData
                                        ? const Color(0xFFC4C4C4)
                                        : _outputOverviewColors[index %
                                              _outputOverviewColors.length],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    displayItems[index].groupName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
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

class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final bool isNoData;
  final bool isSingleSite;

  DonutChartPainter({
    required this.values,
    required this.colors,
    required this.isNoData,
    required this.isSingleSite,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    const double donutThickness = 26.0;
    const double cornerRadius = 4.0;
    const double gapAngle = 0.08;

    final double outerRadius =
        (min(size.width, size.height) / 2) - cornerRadius;
    final double innerRadius = outerRadius - donutThickness;

    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerRadius * 2
      ..strokeJoin = StrokeJoin.round;

    if (isNoData) {
      fillPaint.color = const Color(0xFFC4C4C4);
      strokePaint.color = const Color(0xFFC4C4C4);
      _drawFullRing(canvas, outerRect, innerRect, fillPaint, strokePaint);
      return;
    }

    final positiveValues = values.where((v) => v > 0).toList();

    if (isSingleSite || positiveValues.length <= 1) {
      final color = colors.isNotEmpty ? colors[0] : const Color(0xFF52EA3A);
      fillPaint.color = color;
      strokePaint.color = color;
      _drawFullRing(canvas, outerRect, innerRect, fillPaint, strokePaint);
      return;
    }

    final double total = positiveValues.fold(0.0, (sum, v) => sum + v);
    if (total <= 0) {
      fillPaint.color = const Color(0xFFC4C4C4);
      strokePaint.color = const Color(0xFFC4C4C4);
      _drawFullRing(canvas, outerRect, innerRect, fillPaint, strokePaint);
      return;
    }

    double startAngle = -pi / 2;
    int colorIdx = 0;

    for (int i = 0; i < values.length; i++) {
      final double val = values[i];
      if (val <= 0) continue;

      final double rawSweep = (val / total) * (2 * pi);
      final Color sliceColor = colors[colorIdx % colors.length];
      colorIdx++;

      if (rawSweep > gapAngle) {
        final double drawSweep = rawSweep - gapAngle;
        final double drawStart = startAngle + (gapAngle / 2);

        final path = Path()
          ..arcTo(outerRect, drawStart, drawSweep, false)
          ..arcTo(innerRect, drawStart + drawSweep, -drawSweep, false)
          ..close();

        fillPaint.color = sliceColor;
        strokePaint.color = sliceColor;

        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
      }

      startAngle += rawSweep;
    }
  }

  void _drawFullRing(
    Canvas canvas,
    Rect outerRect,
    Rect innerRect,
    Paint fillPaint,
    Paint strokePaint,
  ) {
    final path = Path()
      ..addOval(outerRect)
      ..addOval(innerRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.colors != colors ||
        oldDelegate.isNoData != isNoData ||
        oldDelegate.isSingleSite != isSingleSite;
  }
}
