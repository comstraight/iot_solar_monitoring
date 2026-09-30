import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Screen Imports
import 'login_screen.dart';
import 'analytics_screen.dart';
import 'notification_screen.dart';
import 'initial_setup_screen.dart';
import 'groups_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final int currentPercentage;
  final int cardCount;

  const HomeScreen({
    super.key,
    required this.currentPercentage,
    required this.cardCount,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Dropdown States
  String selectedTimeRange = 'This Week';
  String selectedFilter = 'View All';

  final List<String> timeRanges = [
    'Today',
    'This Week',
    'This Month',
    'This Year',
  ];

  // Cached Telemetry Stream Instance (system_status/current document)
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _telemetryStream;

  // Active subscription for aggregated time-range totals
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _analyticsSubscription;

  // Real-time listener state for pre-aggregated time-range totals
  double _aggregatedTotalKwh = 0.0;

  @override
  void initState() {
    super.initState();
    // Optimization: Initialize stream once with strict type mapping & disable metadata-only rebuilds
    _telemetryStream = FirebaseFirestore.instance
        .collection('system_status')
        .doc('current')
        .snapshots(includeMetadataChanges: false);

    _listenToAggregatedTotals();
  }

  @override
  void dispose() {
    _analyticsSubscription?.cancel();
    super.dispose();
  }

  /// Listens to pre-aggregated Firestore analytics collection according to selected time range
  void _listenToAggregatedTotals() {
    // Cancel any existing active listener to prevent memory & Firestore subscription leaks
    _analyticsSubscription?.cancel();

    final DateTime now = DateTime.now();
    final String dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // Sunday-based week identifier matching server.py
    final daysSinceSun = (now.weekday % 7);
    final sunDate = now.subtract(Duration(days: daysSinceSun));
    // Calculate week number in year
    final dayOfYear = int.parse(
      now.difference(DateTime(now.year, 1, 1)).inDays.toString(),
    );
    final wNum = ((dayOfYear - now.weekday + 10) / 7)
        .floor()
        .toString()
        .padLeft(2, '0');
    final weekStr = "${sunDate.year}-W$wNum";
    final yearStr = "${now.year}";

    if (selectedTimeRange == 'Today') {
      _analyticsSubscription = FirebaseFirestore.instance
          .collection('analytics')
          .doc('solar_system_01')
          .collection('daily')
          .doc(dateStr)
          .snapshots()
          .listen((doc) {
            if (doc.exists && mounted) {
              setState(() {
                _aggregatedTotalKwh =
                    (doc.data()?['totalKwh'] as num?)?.toDouble() ?? 0.0;
              });
            }
          });
    } else if (selectedTimeRange == 'This Week') {
      _analyticsSubscription = FirebaseFirestore.instance
          .collection('analytics')
          .doc('solar_system_01')
          .collection('weekly')
          .doc(weekStr)
          .snapshots()
          .listen((doc) {
            if (doc.exists && mounted) {
              setState(() {
                _aggregatedTotalKwh =
                    (doc.data()?['totalKwh'] as num?)?.toDouble() ?? 0.0;
              });
            }
          });
    } else if (selectedTimeRange == 'This Month' ||
        selectedTimeRange == 'This Year') {
      _analyticsSubscription = FirebaseFirestore.instance
          .collection('analytics')
          .doc('solar_system_01')
          .collection('annually')
          .doc(yearStr)
          .snapshots()
          .listen((doc) {
            if (doc.exists && mounted) {
              final data = doc.data() ?? {};
              if (selectedTimeRange == 'This Year') {
                setState(() {
                  _aggregatedTotalKwh =
                      (data['totalKwh'] as num?)?.toDouble() ?? 0.0;
                });
              } else {
                // Calculate sum for current month from pre-aggregated bars map
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
                final currentMonthLabel = monthNames[now.month - 1];
                final bars = data['bars'] as Map<String, dynamic>? ?? {};
                final monthVal = bars[currentMonthLabel];

                double mKwh = 0.0;
                if (monthVal is Map) {
                  mKwh =
                      (monthVal['raw_kwh'] as num?)?.toDouble() ??
                      (monthVal['val'] as num?)?.toDouble() ??
                      0.0;
                } else if (monthVal is num) {
                  mKwh = monthVal.toDouble();
                }

                setState(() {
                  _aggregatedTotalKwh = mKwh;
                });
              }
            }
          });
    }
  }

  Future<void> _handleLogout() async {
    // Close side drawer first
    if ((_scaffoldKey.currentState?.isDrawerOpen ?? false) &&
        Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // Sign out from Firebase Auth
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    // Remove all previous screens from stack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SlickLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildSideMenu(context),
      appBar: _buildAppBar(),
      body: Container(
        color: Colors.white,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _telemetryStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }

            final Map<String, dynamic> telemetryData =
                (snapshot.hasData && snapshot.data!.data() != null)
                ? snapshot.data!.data()!
                : {};

            // 1. Extract Battery SOC (Handles nested 'battery' map from server.py)
            final Map<String, dynamic>? batteryMap =
                telemetryData['battery'] as Map<String, dynamic>?;
            final double soc =
                (batteryMap?['battery_soc'] ??
                        batteryMap?['soc'] ??
                        telemetryData['battery_soc'] ??
                        telemetryData['soc'] ??
                        widget.currentPercentage)
                    .toDouble();

            // 2. Fallback Total Generated kWh if aggregated doc isn't loaded yet
            final double liveTotalToday =
                (telemetryData['total_kwh_today'] ??
                        telemetryData['total_generated_kwh'] ??
                        telemetryData['total_kwh'] ??
                        0.0)
                    .toDouble();

            final double displayTotalGenerated =
                selectedTimeRange == 'Today' && _aggregatedTotalKwh == 0.0
                ? liveTotalToday
                : _aggregatedTotalKwh;

            // 3. Extract Peak Output kW ('peak_output_kw' from server.py)
            final double peakOutput =
                (telemetryData['peak_output_kw'] ??
                        telemetryData['peak_power'] ??
                        0.0)
                    .toDouble();

            // 4. Extract Estimated Savings PHP ('estimated_savings_php' from server.py)
            final double estimatedSavings =
                (telemetryData['estimated_savings_php'] ??
                        telemetryData['estimated_savings'] ??
                        telemetryData['savings_php'] ??
                        0.0)
                    .toDouble();

            // 5. Extract Groups Map ('groups' map from server.py)
            final Map<String, dynamic> groupsMap =
                telemetryData['groups'] as Map<String, dynamic>? ?? {};

            // 6. Extract Panels Map ('panels' map from server.py)
            final Map<String, dynamic> panelsMap =
                telemetryData['panels'] as Map<String, dynamic>? ?? {};

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Top Dashboard & Metrics
                topDashboard(soc: soc, totalGenerated: displayTotalGenerated),
                const SizedBox(height: 10),
                _buildLiveMetricsRow(peakOutput, estimatedSavings),

                // Monitoring Header with Groups Filter Dropdown
                _buildMonitoringHeader(groupsMap),

                // Dynamic Grouped Solar Panels List
                _buildPanelsList(panelsMap, groupsMap),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- Live Metrics Row Component ---
  Widget _buildLiveMetricsRow(double peakOutput, double estimatedSavings) {
    final double cardWidth = MediaQuery.of(context).size.width * 0.46;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // Peak Output Card
        Container(
          height: 120,
          width: cardWidth,
          decoration: _cardBoxDecoration(),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 10, bottom: 10),
                child: Text(
                  'Peak Output',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      peakOutput.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text('kW/h'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Estimated Savings Card
        Container(
          height: 120,
          width: cardWidth,
          decoration: _cardBoxDecoration(),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 10, bottom: 10),
                child: Text(
                  'Estimated Savings',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text('₱'),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      estimatedSavings.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Monitoring Header with Filter Dropdown ---
  Widget _buildMonitoringHeader(Map<String, dynamic> groupsMap) {
    List<String> dynamicFilters = ['View All'];

    if (groupsMap.isNotEmpty) {
      List<Map<String, dynamic>> groupList = groupsMap.values
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Sort groups by group_order
      groupList.sort((a, b) {
        final int orderA = a['group_order'] ?? a['order'] ?? 0;
        final int orderB = b['group_order'] ?? b['order'] ?? 0;
        return orderA.compareTo(orderB);
      });

      for (var g in groupList) {
        final groupName = g['group_name'] ?? g['name'];
        if (groupName != null && groupName.toString().isNotEmpty) {
          dynamicFilters.add(groupName.toString());
        }
      }
    }

    final String activeFilter = dynamicFilters.contains(selectedFilter)
        ? selectedFilter
        : 'View All';

    return Padding(
      padding: const EdgeInsets.only(left: 17, right: 15, top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Monitoring',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          const Text(
            'sort by ',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: activeFilter,
                dropdownColor: Colors.white,
                isDense: true,
                isExpanded: false,
                alignment: Alignment.center,
                icon: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    CupertinoIcons.chevron_down,
                    size: 13,
                    color: Colors.black,
                  ),
                ),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                borderRadius: BorderRadius.circular(12),
                onChanged: (String? newValue) {
                  if (newValue != null && newValue != selectedFilter) {
                    setState(() {
                      selectedFilter = newValue;
                    });
                  }
                },
                items: dynamicFilters.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    alignment: Alignment.center,
                    child: Text(value, textAlign: TextAlign.center),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Dynamic Panels List Grouped by Sites ---
  Widget _buildPanelsList(
    Map<String, dynamic> panelsMap,
    Map<String, dynamic> groupsMap,
  ) {
    if (panelsMap.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: Text(
            'No solar panels registered in database.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    if (groupsMap.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: Text(
            'No groups available.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    // Sort all panels by order
    List<Map<String, dynamic>> allPanelsList = panelsMap.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    allPanelsList.sort((a, b) {
      final int orderA = a['panel_order'] ?? a['order'] ?? 0;
      final int orderB = b['panel_order'] ?? b['order'] ?? 0;
      return orderA.compareTo(orderB);
    });

    // Extract and sort group entries
    List<MapEntry<String, Map<String, dynamic>>> groupEntries = groupsMap
        .entries
        .map((e) => MapEntry(e.key, Map<String, dynamic>.from(e.value as Map)))
        .toList();

    groupEntries.sort((a, b) {
      final int orderA = a.value['group_order'] ?? a.value['order'] ?? 0;
      final int orderB = b.value['group_order'] ?? b.value['order'] ?? 0;
      return orderA.compareTo(orderB);
    });

    // Filter group entries if a specific group is chosen in dropdown
    if (selectedFilter != 'View All') {
      groupEntries = groupEntries.where((entry) {
        final String groupName =
            (entry.value['group_name'] ?? entry.value['name'] ?? '').toString();
        return entry.key == selectedFilter || groupName == selectedFilter;
      }).toList();
    }

    if (groupEntries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: Text(
            'No panels found in this group.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    List<Widget> children = [];

    for (var groupEntry in groupEntries) {
      final String groupKey = groupEntry.key;
      final Map<String, dynamic> groupData = groupEntry.value;
      final String groupName =
          groupData['group_name'] ?? groupData['name'] ?? 'Unnamed Group';

      // Find panels belonging exclusively to this group
      final groupPanels = allPanelsList.where((panelData) {
        return _isPanelInGroup(panelData, groupKey, groupData);
      }).toList();

      // Header for site / group (Clickable shortcut to Analytics Screen)
      children.add(
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnalyticsScreen(
                  initialSiteId: groupKey,
                  initialSiteName: groupName,
                ),
              ),
            );
          },
          child: _buildGroupSectionHeader(groupName),
        ),
      );

      if (groupPanels.isEmpty) {
        children.add(
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0, top: 4.0),
            child: Center(
              child: Text(
                'No panels in this group.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
        );
      } else {
        for (var panelData in groupPanels) {
          final String name =
              panelData['panel_name'] ?? panelData['name'] ?? 'Unnamed Panel';

          final Map<String, dynamic>? sensorData =
              panelData['sensor_data'] as Map<String, dynamic>?;

          final double rawPowerW = (sensorData?['output_power_w'] ?? 0.0)
              .toDouble();

          final double value = sensorData?['output_power_w'] != null
              ? rawPowerW / 1000.0
              : (panelData['power_kwh'] ??
                        panelData['power_w'] ??
                        panelData['power'] ??
                        0.0)
                    .toDouble();

          children.add(metricCard(title: name, value: value));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  // --- Helper to verify if panel belongs to a group ---
  bool _isPanelInGroup(
    Map<String, dynamic> panelData,
    String groupKey,
    Map<String, dynamic> groupData,
  ) {
    final String groupName =
        (groupData['group_name'] ?? groupData['name'] ?? '').toString();
    final String? panelGroup = panelData['group']?.toString();
    final String? panelGroupName = panelData['group_name']?.toString();

    if (panelGroup != null && panelGroup.isNotEmpty && panelGroup == groupKey) {
      return true;
    }

    if (groupName.isNotEmpty) {
      if (panelGroup == groupName) return true;
      if (panelGroupName == groupName) return true;
    }

    return false;
  }

  // --- Group Section Header Widget ---
  Widget _buildGroupSectionHeader(String groupName) {
    return Padding(
      padding: const EdgeInsets.only(left: 17, right: 17, top: 14, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF20831B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              CupertinoIcons.rectangle_grid_2x2,
              size: 14,
              color: Color(0xFF20831B),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            groupName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  // --- Dynamic Solar Panel Metric Card ---
  Widget metricCard({required String title, required double value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          height: 100,
          width: MediaQuery.of(context).size.width * 0.93,
          decoration: _cardBoxDecoration(),
          child: Row(
            children: [
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text('Individual Value', style: TextStyle(fontSize: 9)),
                ],
              ),
              const Spacer(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value < 1.0
                        ? value.toStringAsFixed(2)
                        : value.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                    ),
                  ),
                  const Text('KW/H', style: TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(width: 15),
            ],
          ),
        ),
      ],
    );
  }

  // --- Top Dashboard Card ---
  Widget topDashboard({required double soc, required double totalGenerated}) {
    return Container(
      height: 230,
      decoration: const BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        gradient: LinearGradient(
          colors: [Color(0xFF092508), Color(0xFF20831B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.38, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 65,
            bottom: 0,
            right: 0,
            child: Image.asset(
              'assets/images/house_top_dash.png',
              fit: BoxFit.contain,
              alignment: Alignment.topRight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 15, right: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildDashboardStatusIcon(),
                    const Spacer(),
                    _buildTimeRangeDropdown(),
                  ],
                ),
                const SizedBox(height: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          totalGenerated.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 35,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'KW/H',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Total Generated',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeDropdown() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF092508),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF20341E), width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedTimeRange,
          dropdownColor: const Color(0xFF092508),
          icon: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(
              CupertinoIcons.chevron_down,
              size: 14,
              color: Colors.white,
            ),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          borderRadius: BorderRadius.circular(16),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                selectedTimeRange = newValue;
              });
              _listenToAggregatedTotals();
            }
          },
          items: timeRanges.map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDashboardStatusIcon() {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          child: Stack(
            alignment: Alignment.center,
            children: const [
              Icon(CupertinoIcons.bolt_fill, size: 27, color: Colors.white),
              Icon(CupertinoIcons.bolt_fill, size: 24, color: Colors.black),
              Icon(CupertinoIcons.bolt_fill, size: 23, color: Colors.yellow),
            ],
          ),
        ),
        _buildBadgeIcon(CupertinoIcons.exclamationmark_triangle),
        _buildBadgeIcon(CupertinoIcons.battery_100),
      ],
    );
  }

  Widget _buildBadgeIcon(IconData icon) {
    return Container(
      height: 40,
      width: 40,
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF20341E), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 23, color: Colors.white),
    );
  }

  // --- Linked Side Menu Drawer ---
  Widget _buildSideMenu(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(
              top: 60,
              left: 24,
              right: 24,
              bottom: 20,
            ),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Icon(
                    CupertinoIcons.bolt,
                    color: Colors.black87,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Menu',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: Color(0xFFE5E7EB), height: 1),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                _buildSectionHeader('DASHBOARDS'),
                _buildDrawerItem(
                  icon: CupertinoIcons.chart_pie,
                  title: 'Overview',
                  isSelected: true,
                  onTap: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
                _buildDrawerItem(
                  icon: CupertinoIcons.graph_square,
                  title: 'Metrics',
                  onTap: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AnalyticsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('SETUP'),
                _buildDrawerItem(
                  icon: CupertinoIcons.plus_square,
                  title: 'Add a Setup',
                  onTap: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InitialSetupScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: CupertinoIcons.rectangle_grid_2x2,
                  title: 'Sites',
                  onTap: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GroupsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('SETTINGS AND ACCOUNT'),
                _buildDrawerItem(
                  icon: CupertinoIcons.gear,
                  title: 'Settings',
                  onTap: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: CupertinoIcons.square_arrow_right,
                  title: 'Log Out',
                  isDestructive: true,
                  onTap: _handleLogout,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'v1.0.2 • Solar Monitoring',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    bool isSelected = false,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    final Color iconColor = isDestructive
        ? const Color(0xFFDC2626)
        : (isSelected ? const Color(0xFF111827) : const Color(0xFF6B7280));

    final Color textColor = isDestructive
        ? const Color(0xFFDC2626)
        : (isSelected ? Colors.black : const Color(0xFF374151));

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        tileColor: isSelected ? const Color(0xFFF3F4F6) : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        dense: true,
        leading: Icon(icon, color: iconColor, size: 18),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  // --- Linked App Bar ---
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 70,
      leadingWidth: 70,
      backgroundColor: const Color(0xFF092508),
      leading: Center(
        child: GestureDetector(
          onTap: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          child: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF20341E), width: 1.5),
            ),
            alignment: Alignment.center,
            child: const Icon(
              CupertinoIcons.line_horizontal_3_decrease,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ),
      actions: [
        Center(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 15),
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF20341E), width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.bell,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardBoxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withValues(alpha: 0.2),
          spreadRadius: 2,
          blurRadius: 3,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}


//finally done
//firestore optimized