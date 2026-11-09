import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'output_overview_screen.dart';

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
          json['aggregator_name'] as String? ??
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

  factory OverviewGroupItem.fromFirestore(
    Map<String, dynamic> json, [
    List<SiteModel>? sites,
  ]) {
    final gId =
        json['group_id'] as String? ?? json['aggregator_id'] as String? ?? '';
    var gName =
        json['group_name'] as String? ??
        json['name'] as String? ??
        json['aggregator_name'] as String?;

    if ((gName == null || gName.isEmpty || gName == 'Unnamed Site') &&
        sites != null) {
      final match = sites.firstWhere(
        (s) => s.groupId == gId,
        orElse: () => SiteModel(groupId: gId, groupName: gId, groupOrder: 0),
      );
      gName = match.groupName;
    }

    final rawKwh = (json['kwh'] as num?)?.toDouble() ?? 0.0;

    return OverviewGroupItem(
      groupId: gId,
      groupName: gName ?? (gId.isNotEmpty ? gId : 'Unnamed Site'),
      kwh: max(0.0, rawKwh),
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
      double rawVal = 0.0;
      if (v is Map) {
        rawVal =
            (v['val'] as num?)?.toDouble() ??
            (v['raw_kwh'] as num?)?.toDouble() ??
            0.0;
      } else if (v is num) {
        rawVal = v.toDouble();
      }
      return MapEntry(k, max(0.0, rawVal));
    });
    final rawTotal =
        (json['totalKwh'] as num?)?.toDouble() ??
        (json['total_kwh'] as num?)?.toDouble() ??
        0.0;
    final title = json['title'] as String? ?? docId;

    return AnalyticsDocModel(
      id: docId,
      title: title,
      totalKwh: max(0.0, rawTotal),
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

  double _totalSystemKw = 0.0;
  double _tariffRate = 12.0;

  final DateTime _latestDate = DateTime.now();

  List<SiteModel> _sites = [
    const SiteModel(groupId: 'all', groupName: 'All Sites', groupOrder: 0),
  ];
  Map<String, List<String>> _sitePanelIds = {};
  List<String> _allPanelIds = [];
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
  }

  /// Maps UI daily labels to server bucket string variations safely (clamped >= 0)
  static double _getBarValue(Map<String, double> bars, String bucketLabel) {
    double val = 0.0;
    if (bars.containsKey(bucketLabel)) {
      val = bars[bucketLabel] ?? 0.0;
    } else {
      final aliasMap = {
        '6AM': ['06:00', '6:00', '6AM', '06:00:00'],
        '9AM': ['09:00', '9:00', '9AM', '09:00:00'],
        '12NN': ['12:00', '12PM', '12NN', '12:00:00'],
        '3PM': ['15:00', '3PM', '15:00:00'],
        '6PM': ['18:00', '6PM', '18:00:00'],
      };

      final aliases = aliasMap[bucketLabel] ?? [bucketLabel];
      for (final alias in aliases) {
        if (bars.containsKey(alias)) {
          val = bars[alias] ?? 0.0;
          break;
        }
      }
    }
    return max(0.0, val);
  }

  Future<void> _loadFirestoreSites() async {
    try {
      final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

      final docSnap = await FirebaseFirestore.instance
          .collection('system_status')
          .doc('current')
          .get();

      List<SiteModel> fetchedSites = [];
      Map<String, List<String>> fetchedSitePanelIds = {};
      List<String> fetchedAllPanelIds = ['panel_01'];
      Map<String, double> calculatedOutputs = {};

      List<OverviewGroupItem> fetchedDailyOverview = [];
      List<OverviewGroupItem> fetchedWeeklyOverview = [];
      List<OverviewGroupItem> fetchedAnnualOverview = [];

      double dynamicSystemKw = 0.0;
      double dynamicTariff = 12.0;

      if (currentUid != null && currentUid.isNotEmpty) {
        try {
          final aggsSnap = await FirebaseFirestore.instance
              .collection('aggregators')
              .where('owner_uid', isEqualTo: currentUid)
              .get();

          for (int i = 0; i < aggsSnap.docs.length; i++) {
            final doc = aggsSnap.docs[i];
            final data = doc.data();
            final rawName = data['aggregator_name'] as String?;
            final siteName =
                (rawName != null &&
                    rawName.trim().isNotEmpty &&
                    rawName != 'Orangepi Device')
                ? rawName
                : 'Site ${i + 1}';

            final detectedPanels =
                (data['detected_panels'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];

            fetchedSites.add(
              SiteModel(groupId: doc.id, groupName: siteName, groupOrder: i),
            );
            fetchedSitePanelIds[doc.id] = detectedPanels;
            fetchedAllPanelIds.addAll(detectedPanels);
          }
        } catch (e) {
          debugPrint('Error fetching aggregators for analytics: $e');
        }
      }

      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;
        final groupsMap = data['groups'] as Map<String, dynamic>? ?? {};
        final panelsMap = data['panels'] as Map<String, dynamic>? ?? {};

        if (data.containsKey('tariff_rate_per_kwh')) {
          dynamicTariff = max(
            0.0,
            (data['tariff_rate_per_kwh'] as num).toDouble(),
          );
        }
        if (data.containsKey('total_system_kw')) {
          dynamicSystemKw = max(
            0.0,
            (data['total_system_kw'] as num).toDouble(),
          );
        }

        final overviewMap =
            data['output_overview'] as Map<String, dynamic>? ?? {};
        final rawDaily = (overviewMap['daily'] as List<dynamic>?) ?? [];
        final rawWeekly = (overviewMap['weekly'] as List<dynamic>?) ?? [];
        final rawAnnual = (overviewMap['annually'] as List<dynamic>?) ?? [];

        fetchedDailyOverview = rawDaily
            .where((item) => item is Map<String, dynamic>)
            .map(
              (item) => OverviewGroupItem.fromFirestore(
                item as Map<String, dynamic>,
                fetchedSites,
              ),
            )
            .toList();
        fetchedWeeklyOverview = rawWeekly
            .where((item) => item is Map<String, dynamic>)
            .map(
              (item) => OverviewGroupItem.fromFirestore(
                item as Map<String, dynamic>,
                fetchedSites,
              ),
            )
            .toList();
        fetchedAnnualOverview = rawAnnual
            .where((item) => item is Map<String, dynamic>)
            .map(
              (item) => OverviewGroupItem.fromFirestore(
                item as Map<String, dynamic>,
                fetchedSites,
              ),
            )
            .toList();

        panelsMap.forEach((pId, pData) {
          if (!fetchedAllPanelIds.contains(pId)) {
            fetchedAllPanelIds.add(pId.toString());
          }
        });

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
                        max(
                          0.0,
                          (sensorData['output_power_w'] as num).toDouble(),
                        ) /
                        1000.0;
                  }
                }
              }
            });
            calculatedOutputs[gId] = max(0.0, siteKw);

            final hasMemberPanel = panelsMap.values.any((p) {
              if (p is Map<String, dynamic>) {
                final pGroup = p['group']?.toString();
                final pOwner = p['owner_uid'] ?? p['ownerUid'];
                return (pGroup == gId || pGroup == groupName) &&
                    (pOwner == currentUid || currentUid == null);
              }
              return false;
            });

            if (!fetchedSites.any((s) => s.groupId == gId) &&
                (groupOwner == currentUid ||
                    hasMemberPanel ||
                    currentUid == null)) {
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

        _sitePanelIds = fetchedSitePanelIds;
        _allPanelIds = fetchedAllPanelIds.toSet().toList();
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

      // Chain analytics load after sites & panel IDs are completely resolved
      _loadFirestoreAnalytics();
    } catch (e) {
      debugPrint('Error fetching Firestore sites: $e');
      setState(() => _isLoadingSites = false);
      _loadFirestoreAnalytics();
    }
  }

  /// Multi-target query that collects and merges panel and aggregator subcollections
  Future<List<AnalyticsDocModel>> _fetchAnalyticsForSubcollection(
    String subcollection,
  ) async {
    List<String> candidateTargets = [];

    if (_selectedSite.groupId == 'all') {
      final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null && currentUid.isNotEmpty) {
        candidateTargets.add('user_$currentUid');
      }
      candidateTargets.addAll(_allPanelIds);
      for (final site in _sites) {
        if (site.groupId != 'all') {
          candidateTargets.add(site.groupId);
        }
      }
      candidateTargets.add('solar_system_01');
      candidateTargets.add('panel_01');
    } else {
      candidateTargets.add(_selectedSite.groupId);
      final panels = _sitePanelIds[_selectedSite.groupId] ?? [];
      candidateTargets.addAll(panels);
      candidateTargets.add('solar_system_01');
      candidateTargets.add('panel_01');
    }

    candidateTargets = candidateTargets.toSet().toList();
    List<AnalyticsDocModel> allFetched = [];

    for (final targetId in candidateTargets) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('analytics')
            .doc(targetId)
            .collection(subcollection)
            .get();

        if (snap.docs.isNotEmpty) {
          final docs = snap.docs
              .map((doc) => AnalyticsDocModel.fromFirestore(doc.data(), doc.id))
              .toList();
          allFetched.addAll(docs);
        }
      } catch (e) {
        debugPrint('Error fetching analytics for $targetId/$subcollection: $e');
      }
    }

    if (allFetched.isEmpty && _selectedSite.groupId != 'all') {
      for (final pId in _allPanelIds) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('analytics')
              .doc(pId)
              .collection(subcollection)
              .get();
          if (snap.docs.isNotEmpty) {
            allFetched.addAll(
              snap.docs.map(
                (doc) => AnalyticsDocModel.fromFirestore(doc.data(), doc.id),
              ),
            );
          }
        } catch (_) {}
      }
    }

    // Merge multiple documents sharing the same date/bucket ID safely
    Map<String, AnalyticsDocModel> mergedMap = {};
    for (final doc in allFetched) {
      if (!mergedMap.containsKey(doc.id)) {
        mergedMap[doc.id] = doc;
      } else {
        final existing = mergedMap[doc.id]!;
        final mergedBars = Map<String, double>.from(existing.bars);
        doc.bars.forEach((k, v) {
          mergedBars[k] = max(0.0, (mergedBars[k] ?? 0.0) + v);
        });
        mergedMap[doc.id] = AnalyticsDocModel(
          id: doc.id,
          title: existing.title,
          totalKwh: max(0.0, existing.totalKwh + doc.totalKwh),
          bars: mergedBars,
        );
      }
    }

    final mergedList = mergedMap.values.toList();
    mergedList.sort((a, b) => a.id.compareTo(b.id));
    return mergedList;
  }

  Future<void> _loadFirestoreAnalytics() async {
    setState(() => _isLoadingReadings = true);

    try {
      final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

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
                    kwSum +=
                        max(0.0, (meta['rated_power_w'] as num).toDouble()) /
                        1000.0;
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

      final fetchedDaily = await _fetchAnalyticsForSubcollection('daily');
      final fetchedWeekly = await _fetchAnalyticsForSubcollection('weekly');
      final fetchedAnnual = await _fetchAnalyticsForSubcollection('annually');

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
    final yearStr = '$currentYear';

    final doc = _annualDocs.cast<AnalyticsDocModel?>().firstWhere(
      (d) => d!.id == yearStr || d.id.startsWith(yearStr),
      orElse: () => null,
    );
    if (doc != null && doc.totalKwh > 0) {
      return max(0.0, doc.totalKwh);
    }

    final dailySum = _dailyDocs
        .where((d) => d.id.startsWith(yearStr))
        .fold(0.0, (sum, d) => sum + max(0.0, d.totalKwh));
    if (dailySum > 0) return max(0.0, dailySum);

    return max(
      0.0,
      _dailyDocs.fold(0.0, (sum, d) => sum + max(0.0, d.totalKwh)),
    );
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
        final v = _getBarValue(doc.bars, b);
        if (v > peakVal) peakVal = v;
      }

      final dailyDivisor = max(expectedBucketMax, peakVal > 0 ? peakVal : 1.0);

      final bars = timeBuckets.map((b) {
        final val = _getBarValue(doc.bars, b);
        final isPeak = peakVal > 0 && val == peakVal && val > 0;
        final double barRatio = (peakVal > 0 && dailyDivisor > 0)
            ? (val / dailyDivisor).clamp(0.0, 1.0)
            : 0.0;

        return BarData(
          label: b,
          val: val <= 0 ? 0.0 : barRatio,
          isHighlight: isPeak,
          peakVal: (isPeak && val > 0) ? '${val.toStringAsFixed(1)} kWh' : '',
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
        totalKwh: max(0.0, doc.totalKwh).toStringAsFixed(1),
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
        final v = max(0.0, doc.bars[day] ?? 0.0);
        if (v > peakVal) peakVal = v;
      }

      final weeklyDivisor = max(expectedDailyMax, peakVal > 0 ? peakVal : 1.0);

      final bars = weekLabels.map((day) {
        final val = max(0.0, doc.bars[day] ?? 0.0);
        final isToday = day == todayLabel && doc.id == _weeklyDocs.last.id;
        final isPeak = peakVal > 0 && val == peakVal && !isToday && val > 0;
        final double barRatio = (peakVal > 0 && weeklyDivisor > 0)
            ? (val / weeklyDivisor).clamp(0.0, 1.0)
            : 0.0;

        return BarData(
          label: day,
          val: val <= 0 ? 0.0 : barRatio,
          isHighlight: isPeak,
          isInProgress: isToday,
          peakVal: (isPeak && val > 0)
              ? '${val.toStringAsFixed(1)} kWh'
              : (isToday && val > 0 ? '${val.toStringAsFixed(1)} kWh' : ''),
        );
      }).toList();

      return AnalyticsRecord(
        title: doc.title,
        bars: bars,
        totalKwh: max(0.0, doc.totalKwh).toStringAsFixed(1),
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
      double firstHalfTotal = 0.0;
      double firstHalfPeak = 0.0;
      for (int m = 1; m <= 6; m++) {
        final monthKey = monthNames[m - 1];
        final v = max(0.0, doc.bars[monthKey] ?? 0.0);
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
        final v = max(0.0, doc.bars[monthKey] ?? 0.0);
        final isPeak = firstHalfPeak > 0 && v == firstHalfPeak && v > 0;
        final double barRatio = (firstHalfPeak > 0 && firstHalfDivisor > 0)
            ? (v / firstHalfDivisor).clamp(0.0, 1.0)
            : 0.0;
        firstHalfBars.add(
          BarData(
            label: monthKey,
            val: v <= 0 ? 0.0 : barRatio,
            isHighlight: isPeak,
            peakVal: (isPeak && v > 0) ? '${v.toStringAsFixed(0)} kWh' : '',
          ),
        );
      }

      records.add(
        AnalyticsRecord(
          title: '${doc.id} - First Half',
          bars: firstHalfBars,
          totalKwh: max(0.0, firstHalfTotal).toStringAsFixed(0),
        ),
      );

      double secondHalfTotal = 0.0;
      double secondHalfPeak = 0.0;
      for (int m = 7; m <= 12; m++) {
        final monthKey = monthNames[m - 1];
        final v = max(0.0, doc.bars[monthKey] ?? 0.0);
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
        final v = max(0.0, doc.bars[monthKey] ?? 0.0);
        final isPeak = secondHalfPeak > 0 && v == secondHalfPeak && v > 0;
        final double barRatio = (secondHalfPeak > 0 && secondHalfDivisor > 0)
            ? (v / secondHalfDivisor).clamp(0.0, 1.0)
            : 0.0;
        secondHalfBars.add(
          BarData(
            label: monthKey,
            val: v <= 0 ? 0.0 : barRatio,
            isHighlight: isPeak,
            peakVal: (isPeak && v > 0) ? '${v.toStringAsFixed(0)} kWh' : '',
          ),
        );
      }

      records.add(
        AnalyticsRecord(
          title: '${doc.id} - Second Half',
          bars: secondHalfBars,
          totalKwh: max(0.0, secondHalfTotal).toStringAsFixed(0),
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

  void _showExportCsvModal() {
    int rangeType = 0; // 0: Year, 1: Day, 2: Exact Time Range
    int selectedYear = _latestDate.year;
    DateTime selectedDay = _latestDate;
    DateTime startDate = _latestDate.subtract(const Duration(days: 7));
    TimeOfDay startTime = const TimeOfDay(hour: 0, minute: 0);
    DateTime endDate = _latestDate;
    TimeOfDay endTime = const TimeOfDay(hour: 23, minute: 59);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final startDateTime = DateTime(
              startDate.year,
              startDate.month,
              startDate.day,
              startTime.hour,
              startTime.minute,
            );
            final endDateTime = DateTime(
              endDate.year,
              endDate.month,
              endDate.day,
              endTime.hour,
              endTime.minute,
            );

            return Container(
              decoration: const BoxDecoration(
                color: pageBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
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
                          'Export Data as CSV',
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
                    const Text(
                      'Select Range Type',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildRangeChoiceChip(
                          label: 'Year',
                          selected: rangeType == 0,
                          onTap: () => setModalState(() => rangeType = 0),
                        ),
                        const SizedBox(width: 8),
                        _buildRangeChoiceChip(
                          label: 'Day',
                          selected: rangeType == 1,
                          onTap: () => setModalState(() => rangeType = 1),
                        ),
                        const SizedBox(width: 8),
                        _buildRangeChoiceChip(
                          label: 'Exact Time',
                          selected: rangeType == 2,
                          onTap: () => setModalState(() => rangeType = 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (rangeType == 0) ...[
                      const Text(
                        'Select Year',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedYear,
                            isExpanded: true,
                            items: List.generate(5, (index) {
                              final y = _latestDate.year - index;
                              return DropdownMenuItem(
                                value: y,
                                child: Text('$y'),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedYear = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ] else if (rangeType == 1) ...[
                      const Text(
                        'Select Specific Date',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDay,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDay = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: darkGreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Start Date & Exact Time',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setModalState(() => startDate = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: startTime,
                                );
                                if (picked != null) {
                                  setModalState(() => startTime = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  startTime.format(context),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'End Date & Exact Time',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setModalState(() => endDate = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                );
                                if (picked != null) {
                                  setModalState(() => endTime = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  endTime.format(context),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Generate & Export CSV',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _generateAndExportCsv(
                            rangeType: rangeType,
                            year: selectedYear,
                            selectedDay: selectedDay,
                            startDateTime: startDateTime,
                            endDateTime: endDateTime,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRangeChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? darkGreen : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? darkGreen : Colors.black12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _generateAndExportCsv({
    required int rangeType,
    required int year,
    required DateTime selectedDay,
    required DateTime startDateTime,
    required DateTime endDateTime,
  }) {
    List<List<String>> csvRows = [
      [
        'Timestamp / Date',
        'Site ID',
        'Site Name',
        'Timeframe / Bucket',
        'Energy Output (kWh)',
        'Est. Savings (PHP)',
      ],
    ];

    final siteId = _selectedSite.groupId;
    final siteName = _selectedSite.groupName;

    if (rangeType == 0) {
      final yearStr = '$year';
      final yearDocs = _dailyDocs
          .where((doc) => doc.id.startsWith(yearStr))
          .toList();

      if (yearDocs.isEmpty) {
        for (var doc in _annualDocs) {
          if (doc.id == yearStr) {
            doc.bars.forEach((month, kwh) {
              final safeKwh = max(0.0, kwh);
              csvRows.add([
                '$yearStr-$month',
                siteId,
                siteName,
                'Monthly ($month)',
                safeKwh.toStringAsFixed(2),
                (safeKwh * _tariffRate).toStringAsFixed(2),
              ]);
            });
            csvRows.add([
              '$yearStr Total',
              siteId,
              siteName,
              'Annual Total',
              doc.totalKwh.toStringAsFixed(2),
              (doc.totalKwh * _tariffRate).toStringAsFixed(2),
            ]);
          }
        }
      } else {
        for (var doc in yearDocs) {
          doc.bars.forEach((timeBucket, kwh) {
            final safeKwh = max(0.0, kwh);
            csvRows.add([
              '${doc.id} $timeBucket',
              siteId,
              siteName,
              timeBucket,
              safeKwh.toStringAsFixed(2),
              (safeKwh * _tariffRate).toStringAsFixed(2),
            ]);
          });
          csvRows.add([
            doc.id,
            siteId,
            siteName,
            'Daily Total',
            doc.totalKwh.toStringAsFixed(2),
            (doc.totalKwh * _tariffRate).toStringAsFixed(2),
          ]);
        }
      }
    } else if (rangeType == 1) {
      final dayStr =
          '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}';
      final matchedDocs = _dailyDocs.where((doc) => doc.id == dayStr).toList();

      if (matchedDocs.isNotEmpty) {
        for (var doc in matchedDocs) {
          doc.bars.forEach((timeBucket, kwh) {
            final safeKwh = max(0.0, kwh);
            csvRows.add([
              '${doc.id} $timeBucket',
              siteId,
              siteName,
              timeBucket,
              safeKwh.toStringAsFixed(2),
              (safeKwh * _tariffRate).toStringAsFixed(2),
            ]);
          });
          csvRows.add([
            doc.id,
            siteId,
            siteName,
            'Daily Total',
            doc.totalKwh.toStringAsFixed(2),
            (doc.totalKwh * _tariffRate).toStringAsFixed(2),
          ]);
        }
      } else {
        csvRows.add([dayStr, siteId, siteName, 'Full Day', '0.00', '0.00']);
      }
    } else {
      final bucketHourMap = {
        '6AM': 6,
        '9AM': 9,
        '12NN': 12,
        '3PM': 15,
        '6PM': 18,
      };

      int matchCount = 0;
      for (var doc in _dailyDocs) {
        final docDate = DateTime.tryParse(doc.id);
        if (docDate == null) continue;

        doc.bars.forEach((bucket, kwh) {
          final hour = bucketHourMap[bucket] ?? 12;
          final bucketDt = DateTime(
            docDate.year,
            docDate.month,
            docDate.day,
            hour,
          );

          if ((bucketDt.isAfter(startDateTime) ||
                  bucketDt.isAtSameMomentAs(startDateTime)) &&
              (bucketDt.isBefore(endDateTime) ||
                  bucketDt.isAtSameMomentAs(endDateTime))) {
            matchCount++;
            final safeKwh = max(0.0, kwh);
            csvRows.add([
              '${doc.id} $bucket',
              siteId,
              siteName,
              bucket,
              safeKwh.toStringAsFixed(2),
              (safeKwh * _tariffRate).toStringAsFixed(2),
            ]);
          }
        });
      }

      if (matchCount == 0) {
        csvRows.add([
          '${startDateTime.toString().split('.')[0]} to ${endDateTime.toString().split('.')[0]}',
          siteId,
          siteName,
          'Custom Range',
          '0.00',
          '0.00',
        ]);
      }
    }

    final csvContent = csvRows
        .map((row) {
          return row
              .map((cell) {
                if (cell.contains(',') ||
                    cell.contains('"') ||
                    cell.contains('\n')) {
                  return '"${cell.replaceAll('"', '""')}"';
                }
                return cell;
              })
              .join(',');
        })
        .join('\n');

    _showCsvResultDialog(csvContent, csvRows.length - 1);
  }

  void _showCsvResultDialog(String csvContent, int recordCount) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: darkGreen),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CSV Export Ready',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Exported $recordCount record(s) for site: ${_selectedSite.groupName}',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                width: double.maxFinite,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    csvContent,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Color(0xFF81C784),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: darkGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.copy_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: const Text(
                'Copy CSV',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csvContent));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('CSV copied to clipboard successfully!'),
                    backgroundColor: darkGreen,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
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
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Material(
                        color: isSelected
                            ? darkGreen.withOpacity(0.12)
                            : cardBg,
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
        Row(
          children: [
            const Text(
              'Portfolio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _showExportCsvModal,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: darkGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.download_rounded, size: 14, color: darkGreen),
                    SizedBox(width: 4),
                    Text(
                      'CSV',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: darkGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        InkWell(
          onTap: _showSiteSelectionModal,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: Text(
                    _selectedSite.groupName,
                    key: ValueKey<String>(_selectedSite.groupId),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
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
            GestureDetector(
              onTap: _showExportCsvModal,
              child: _buildCircularIcon(Icons.file_download_outlined),
            ),
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _isLoadingReadings
                  ? Container(
                      key: const ValueKey('loading_chart_container'),
                      height: 250,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: darkGreen),
                      ),
                    )
                  : records.isEmpty
                  ? Container(
                      key: const ValueKey('empty_chart_container'),
                      child: _buildEmptyChartCard(),
                    )
                  : Container(
                      key: ValueKey<String>(
                        'chart_${_selectedSite.groupId}_$_selectedTimeframe',
                      ),
                      child: _buildGraphCard(records),
                    ),
            ),
            if (_selectedSite.groupId == 'all') ...[
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                value,
                key: ValueKey<String>(value),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
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
                          activeRecord.totalKwh,
                          key: ValueKey<String>(
                            'total_${_selectedSite.groupId}_${_selectedTimeframe}_${activeRecord.totalKwh}',
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
                                    final calculatedBarHeight = item.val <= 0
                                        ? 0.0
                                        : availableBarHeight *
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
                                      child: TweenAnimationBuilder<double>(
                                        key: ValueKey<String>(
                                          'bar_${_selectedSite.groupId}_${_selectedTimeframe}_${recordIndex}_${item.label}',
                                        ),
                                        tween: Tween<double>(
                                          begin: 0.0,
                                          end: calculatedBarHeight,
                                        ),
                                        duration: const Duration(
                                          milliseconds: 450,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        builder: (context, animatedHeight, child) {
                                          return Stack(
                                            alignment: Alignment.bottomCenter,
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                width: 40,
                                                height: animatedHeight,
                                                decoration: BoxDecoration(
                                                  color: barColor,
                                                  borderRadius:
                                                      const BorderRadius.vertical(
                                                        top: Radius.circular(8),
                                                      ),
                                                ),
                                              ),
                                              if (item.peakVal.isNotEmpty &&
                                                  animatedHeight > 0 &&
                                                  animatedHeight >=
                                                      calculatedBarHeight *
                                                          0.75)
                                                Positioned(
                                                  bottom: animatedHeight + 6,
                                                  child: AnimatedOpacity(
                                                    duration: const Duration(
                                                      milliseconds: 200,
                                                    ),
                                                    opacity: 1.0,
                                                    child: _buildHighlightLabel(
                                                      item.peakVal,
                                                      item.isInProgress,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              title,
              key: ValueKey<String>(title),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
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
            kwh: max(0.0, _siteOutputs[s.groupId] ?? 0.0),
          );
        }).toList();
      }
    } else {
      final match = currentOverview.firstWhere(
        (item) => item.groupId == _selectedSite.groupId,
        orElse: () => OverviewGroupItem(
          groupId: _selectedSite.groupId,
          groupName: _selectedSite.groupName,
          kwh: max(0.0, _siteOutputs[_selectedSite.groupId] ?? 0.0),
        ),
      );
      displayItems = [match];
    }

    List<double> values = [];
    double totalOutput = 0.0;
    for (var item in displayItems) {
      final safeKwh = max(0.0, item.kwh);
      values.add(safeKwh);
      totalOutput += safeKwh;
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

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OutputOverviewScreen()),
        );
      },
      borderRadius: BorderRadius.circular(28),
      child: Container(
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
              child: TweenAnimationBuilder<double>(
                key: ValueKey<String>(
                  'donut_${_selectedSite.groupId}_$_selectedTimeframe',
                ),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, progress, child) {
                  final animatedValues = values
                      .map((v) => v * progress)
                      .toList();
                  return CustomPaint(
                    painter: DonutChartPainter(
                      values: animatedValues,
                      colors: _outputOverviewColors,
                      isNoData: isNoData,
                      isSingleSite: isSingleSite,
                    ),
                  );
                },
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
                            ? AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Row(
                                  key: ValueKey<String>(
                                    'legend_${displayItems[index].groupId}_$index',
                                  ),
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
                                ),
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
