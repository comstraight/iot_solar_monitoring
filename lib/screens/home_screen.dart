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
import 'settings_screen.dart';
import 'monitoring_screen.dart';

/// Type definitions to prevent generic angle-bracket stripping issues
typedef SystemDocumentSnapshot = DocumentSnapshot<Map<String, dynamic>>;
typedef SystemJsonMap = Map<String, dynamic>;

/// Centralized UI Colors
abstract class _AppColors {
  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color borderGreen = Color(0xFF20341E);
  static const Color backgroundWhite = Colors.white;
  static const Color cardShadow = Colors.grey;
  static const Color textBlack = Colors.black;
  static const Color textBlack87 = Colors.black87;
  static const Color textGrey = Colors.grey;
  static final Color textGrey500 = Colors.grey.shade500;
  static const Color textSubtleGrey = Color(0xFF6B7280);
  static const Color textDarkGrey = Color(0xFF374151);
  static const Color textPrimaryDark = Color(0xFF111827);
  static const Color drawerBgGrey = Color(0xFFF3F4F6);
  static const Color drawerBorderGrey = Color(0xFFE5E7EB);
  static const Color activeIndicatorGreen = Color(0xFF22C55E);
  static const Color destructiveRed = Color(0xFFDC2626);
  static const Color boltYellow = Colors.yellow;
  static const Color iconWhite = Colors.white;
}

/// Centralized Text & Asset Paths
abstract class _AppStrings {
  static const String timeRangeToday = 'Today';
  static const String timeRangeThisWeek = 'This Week';
  static const String timeRangeThisMonth = 'This Month';
  static const String timeRangeThisYear = 'This Year';
  static const String filterViewAll = 'View All';

  static const String peakOutputLabel = 'Peak Output';
  static const String estimatedSavingsLabel = 'Estimated Savings';
  static const String unitKwhLower = 'kW/h';
  static const String unitKwhUpper = 'KW/H';
  static const String currencySymbol = '₱';
  static const String monitoringTitle = 'Monitoring';
  static const String sortByLabel = 'sort by ';
  static const String totalGeneratedLabel = 'Total Generated';
  static const String individualValueLabel = 'Individual Value';

  static const String noPanelsRegistered =
      'No solar panels registered for your account.';
  static const String noGroupsAvailable = 'No groups available.';
  static const String noPanelsFoundInGroup = 'No panels found in this group.';
  static const String noPanelsInThisGroup = 'No panels in this group.';
  static const String unnamedGroup = 'Unnamed Group';
  static const String unnamedPanel = 'Unnamed Panel';

  static const String menuHeader = 'Menu';
  static const String sectionDashboards = 'DASHBOARDS';
  static const String menuOverview = 'Overview';
  static const String menuMetrics = 'Metrics';
  static const String sectionSetup = 'SETUP';
  static const String menuAddSetup = 'Add a Setup';
  static const String sectionSettingsAccount = 'SETTINGS AND ACCOUNT';
  static const String menuSettings = 'Settings';
  static const String menuLogOut = 'Log Out';
  static const String appVersion = 'v1.0.2 • Solar Monitoring';

  static const String houseDashAsset = 'assets/images/house_top_dash.png';
}

/// Centralized Layout Dimensions & Magic Numbers
abstract class _AppDimensions {
  static const double dashboardHeight = 230.0;
  static const double metricCardHeight = 120.0;
  static const double panelMetricCardHeight = 100.0;
  static const double appBarHeight = 70.0;
  static const double appBarButtonSize = 40.0;
  static const double drawerHeaderIconSize = 42.0;

  static const double cardWidthFactorMetric = 0.46;
  static const double cardWidthFactorPanel = 0.93;

  static const double fontExtraLarge = 36.0;
  static const double fontHeaderLarge = 35.0;
  static const double fontValueLarge = 30.0;
  static const double fontTitleLarge = 21.0;
  static const double fontSectionTitle = 20.0;
  static const double fontHeaderMedium = 18.0;
  static const double fontDrawerMenu = 16.0;
  static const double fontCardTitle = 15.0;
  static const double fontBodyMedium = 13.0;
  static const double fontSubtitle = 12.0;
  static const double fontBodySmall = 11.0;
  static const double fontSectionHeader = 10.0;
  static const double fontCaption = 9.0;

  static const double iconSizeExtraLarge = 27.0;
  static const double iconSizeLarge = 24.0;
  static const double iconSizeMediumLarge = 23.0;
  static const double iconSizeMedium = 22.0;
  static const double iconSizeStandard = 20.0;
  static const double iconSizeDrawer = 18.0;
  static const double iconSizeSmall = 14.0;
  static const double iconSizeExtraSmall = 13.0;

  static const double radiusDashboard = 20.0;
  static const double radiusDropdown = 20.0;
  static const double radiusDropdownMenu = 16.0;
  static const double radiusDropdownFilter = 12.0;
  static const double radiusCard = 10.0;
  static const double radiusBadge = 6.0;
  static const double radiusIndicatorDot = 6.0;

  static const double spacingExtraLarge = 32.0;
  static const double spacingLarge = 24.0;
  static const double spacingMedium = 16.0;
  static const double spacingStandard = 15.0;
  static const double spacingSmall = 10.0;
  static const double spacingTiny = 8.0;
  static const double spacingMicro = 4.0;

  static const double borderWidthStandard = 1.5;
  static const double borderWidthThick = 2.5;

  static const double shadowAlphaCard = 0.2;
  static const double shadowAlphaBadge = 0.25;
  static const double shadowAlphaIconBg = 0.1;
}

/// Centralized Firestore Collection Names & Field Constants
abstract class _AppFirestore {
  static const String collectionSystemStatus = 'system_status';
  static const String docCurrent = 'current';

  static const String collectionUsers = 'users';
  static const String collectionAnalytics = 'analytics';
  static const String collectionDaily = 'daily';
  static const String collectionWeekly = 'weekly';
  static const String collectionAnnually = 'annually';

  static const String fallbackSystemDoc = 'solar_system_01';
  static const String userDocPrefix = 'user_';

  static const String fieldPairedDevices = 'pairedDevices';
  static const String fieldTotalKwh = 'totalKwh';
  static const String fieldBars = 'bars';
  static const String fieldRawKwh = 'raw_kwh';
  static const String fieldVal = 'val';

  static const String fieldBattery = 'battery';
  static const String fieldBatterySoc = 'battery_soc';
  static const String fieldSoc = 'soc';
  static const String fieldTotalKwhToday = 'total_kwh_today';
  static const String fieldTotalGeneratedKwh = 'total_generated_kwh';
  static const String fieldPeakOutputKw = 'peak_output_kw';
  static const String fieldPeakPower = 'peak_power';
  static const String fieldEstimatedSavingsPhp = 'estimated_savings_php';
  static const String fieldEstimatedSavings = 'estimated_savings';
  static const String fieldSavingsPhp = 'savings_php';

  static const String fieldGroups = 'groups';
  static const String fieldPanels = 'panels';
  static const String fieldOwnerUid = 'owner_uid';
  static const String fieldOwnerUidCamel = 'ownerUid';
  static const String fieldGroupName = 'group_name';
  static const String fieldName = 'name';
  static const String fieldGroupOrder = 'group_order';
  static const String fieldOrder = 'order';
  static const String fieldPanelOrder = 'panel_order';
  static const String fieldGroup = 'group';
  static const String fieldSensorData = 'sensor_data';
  static const String fieldOutputPowerW = 'output_power_w';
  static const String fieldPowerKwh = 'power_kwh';
  static const String fieldPowerW = 'power_w';
  static const String fieldPower = 'power';
}

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
  String selectedTimeRange = _AppStrings.timeRangeThisWeek;
  String selectedFilter = _AppStrings.filterViewAll;

  final List<String> timeRanges = [
    _AppStrings.timeRangeToday,
    _AppStrings.timeRangeThisWeek,
    _AppStrings.timeRangeThisMonth,
    _AppStrings.timeRangeThisYear,
  ];

  // Cached Telemetry Stream Instance (system_status/current document)
  late final Stream<SystemDocumentSnapshot> _telemetryStream;

  // Active subscription for aggregated time-range totals
  StreamSubscription<SystemDocumentSnapshot>? _analyticsSubscription;

  // Active subscription for user profile pairedDevices
  StreamSubscription<SystemDocumentSnapshot>? _userSubscription;

  // Real-time listener for user's claimed sites from aggregators collection
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sitesSubscription;
  Map<String, String> _connectedSitesMap = {};

  List<String> _userPairedDevices = [];

  // Real-time listener state for pre-aggregated time-range totals
  double _aggregatedTotalKwh = 0.0;

  @override
  void initState() {
    super.initState();
    _telemetryStream = FirebaseFirestore.instance
        .collection(_AppFirestore.collectionSystemStatus)
        .doc(_AppFirestore.docCurrent)
        .snapshots(includeMetadataChanges: false);

    _listenToUserDoc();
    _listenToSitesCollection();
    _listenToAggregatedTotals();
  }

  @override
  void dispose() {
    _analyticsSubscription?.cancel();
    _userSubscription?.cancel();
    _sitesSubscription?.cancel();
    super.dispose();
  }

  /// Listens to user's claimed OrangePis / Sites from aggregators collection
  void _listenToSitesCollection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _sitesSubscription = FirebaseFirestore.instance
        .collection('aggregators')
        .where('owner_uid', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            final Map<String, String> siteMap = {};
            for (int i = 0; i < snapshot.docs.length; i++) {
              final doc = snapshot.docs[i];
              final data = doc.data();
              final rawName = data['aggregator_name']?.toString();
              final siteName =
                  (rawName != null &&
                      rawName.trim().isNotEmpty &&
                      rawName != 'Orangepi Device')
                  ? rawName
                  : 'Site ${i + 1}';
              siteMap[doc.id] = siteName;
            }
            setState(() {
              _connectedSitesMap = siteMap;
            });
          }
        });
  }

  /// Real-time listener for current user's document to get paired device IDs
  void _listenToUserDoc() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userSubscription = FirebaseFirestore.instance
        .collection(_AppFirestore.collectionUsers)
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
          if (doc.exists && mounted) {
            final data = doc.data() ?? {};
            final List<dynamic> paired =
                data[_AppFirestore.fieldPairedDevices] as List<dynamic>? ?? [];
            setState(() {
              _userPairedDevices = paired.map((e) => e.toString()).toList();
            });
          }
        });
  }

  /// Listens to pre-aggregated Firestore analytics collection for current user
  void _listenToAggregatedTotals() {
    _analyticsSubscription?.cancel();

    final user = FirebaseAuth.instance.currentUser;
    final String docId = (user != null && user.uid.isNotEmpty)
        ? '${_AppFirestore.userDocPrefix}${user.uid}'
        : _AppFirestore.fallbackSystemDoc;

    final DateTime now = DateTime.now();
    final String dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final daysSinceSun = (now.weekday % 7);
    final sunDate = now.subtract(Duration(days: daysSinceSun));
    final dayOfYear = int.parse(
      now.difference(DateTime(now.year, 1, 1)).inDays.toString(),
    );
    final wNum = ((dayOfYear - now.weekday + 10) / 7)
        .floor()
        .toString()
        .padLeft(2, '0');
    final weekStr = "${sunDate.year}-W$wNum";
    final yearStr = "${now.year}";

    void attachListener(String targetDoc) {
      if (selectedTimeRange == _AppStrings.timeRangeToday) {
        _analyticsSubscription = FirebaseFirestore.instance
            .collection(_AppFirestore.collectionAnalytics)
            .doc(targetDoc)
            .collection(_AppFirestore.collectionDaily)
            .doc(dateStr)
            .snapshots()
            .listen((doc) {
              if (doc.exists && mounted) {
                setState(() {
                  _aggregatedTotalKwh =
                      (doc.data()?[_AppFirestore.fieldTotalKwh] as num?)
                          ?.toDouble() ??
                      0.0;
                });
              } else if (targetDoc != _AppFirestore.fallbackSystemDoc) {
                attachListener(_AppFirestore.fallbackSystemDoc);
              }
            });
      } else if (selectedTimeRange == _AppStrings.timeRangeThisWeek) {
        _analyticsSubscription = FirebaseFirestore.instance
            .collection(_AppFirestore.collectionAnalytics)
            .doc(targetDoc)
            .collection(_AppFirestore.collectionWeekly)
            .doc(weekStr)
            .snapshots()
            .listen((doc) {
              if (doc.exists && mounted) {
                setState(() {
                  _aggregatedTotalKwh =
                      (doc.data()?[_AppFirestore.fieldTotalKwh] as num?)
                          ?.toDouble() ??
                      0.0;
                });
              } else if (targetDoc != _AppFirestore.fallbackSystemDoc) {
                attachListener(_AppFirestore.fallbackSystemDoc);
              }
            });
      } else if (selectedTimeRange == _AppStrings.timeRangeThisMonth ||
          selectedTimeRange == _AppStrings.timeRangeThisYear) {
        _analyticsSubscription = FirebaseFirestore.instance
            .collection(_AppFirestore.collectionAnalytics)
            .doc(targetDoc)
            .collection(_AppFirestore.collectionAnnually)
            .doc(yearStr)
            .snapshots()
            .listen((doc) {
              if (doc.exists && mounted) {
                final data = doc.data() ?? {};
                if (selectedTimeRange == _AppStrings.timeRangeThisYear) {
                  setState(() {
                    _aggregatedTotalKwh =
                        (data[_AppFirestore.fieldTotalKwh] as num?)
                            ?.toDouble() ??
                        0.0;
                  });
                } else {
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
                  final bars =
                      data[_AppFirestore.fieldBars] as Map<String, dynamic>? ??
                      {};
                  final monthVal = bars[currentMonthLabel];

                  double mKwh = 0.0;
                  if (monthVal is Map) {
                    mKwh =
                        (monthVal[_AppFirestore.fieldRawKwh] as num?)
                            ?.toDouble() ??
                        (monthVal[_AppFirestore.fieldVal] as num?)
                            ?.toDouble() ??
                        0.0;
                  } else if (monthVal is num) {
                    mKwh = monthVal.toDouble();
                  }

                  setState(() {
                    _aggregatedTotalKwh = mKwh;
                  });
                }
              } else if (targetDoc != _AppFirestore.fallbackSystemDoc) {
                attachListener(_AppFirestore.fallbackSystemDoc);
              }
            });
      }
    }

    attachListener(docId);
  }

  Future<void> _handleLogout() async {
    if ((_scaffoldKey.currentState?.isDrawerOpen ?? false) &&
        Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SlickLoginScreen()),
      (route) => false,
    );
  }

  void _showRenamePanelDialog(String panelId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
          ),
          title: const Text(
            'Rename Panel',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter new panel name',
              filled: true,
              fillColor: _AppColors.drawerBgGrey,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: _AppDimensions.spacingMedium,
                vertical: _AppDimensions.spacingSmall,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _AppColors.textSubtleGrey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.midGreen,
                foregroundColor: _AppColors.backgroundWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    _AppDimensions.radiusCard,
                  ),
                ),
              ),
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  try {
                    final docRef = FirebaseFirestore.instance
                        .collection(_AppFirestore.collectionSystemStatus)
                        .doc(_AppFirestore.docCurrent);

                    await docRef.update({
                      'panels.$panelId.panel_name': newName,
                    });

                    await FirebaseFirestore.instance
                        .collection('devices')
                        .doc(panelId)
                        .set({'panel_name': newName}, SetOptions(merge: true));
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error renaming panel: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildSideMenu(context),
      appBar: _buildAppBar(),
      body: Container(
        color: _AppColors.backgroundWhite,
        child: StreamBuilder<SystemDocumentSnapshot>(
          stream: _telemetryStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }

            final SystemJsonMap telemetryData =
                (snapshot.hasData && snapshot.data!.data() != null)
                ? snapshot.data!.data()! as SystemJsonMap
                : {} as SystemJsonMap;

            final SystemJsonMap? batteryMap =
                telemetryData[_AppFirestore.fieldBattery] as SystemJsonMap?;
            final double soc =
                (batteryMap?[_AppFirestore.fieldBatterySoc] ??
                        batteryMap?[_AppFirestore.fieldSoc] ??
                        telemetryData[_AppFirestore.fieldBatterySoc] ??
                        telemetryData[_AppFirestore.fieldSoc] ??
                        widget.currentPercentage)
                    .toDouble();

            final double liveTotalToday =
                (telemetryData[_AppFirestore.fieldTotalKwhToday] ??
                        telemetryData[_AppFirestore.fieldTotalGeneratedKwh] ??
                        0.0)
                    .toDouble();

            final double displayTotalGenerated =
                selectedTimeRange == _AppStrings.timeRangeThisWeek &&
                    _aggregatedTotalKwh == 0.0
                ? liveTotalToday
                : (_aggregatedTotalKwh == 0.0
                      ? liveTotalToday
                      : _aggregatedTotalKwh);

            final double peakOutput =
                (telemetryData[_AppFirestore.fieldPeakOutputKw] ??
                        telemetryData[_AppFirestore.fieldPeakPower] ??
                        0.0)
                    .toDouble();

            final double estimatedSavings =
                (telemetryData[_AppFirestore.fieldEstimatedSavingsPhp] ??
                        telemetryData[_AppFirestore.fieldEstimatedSavings] ??
                        telemetryData[_AppFirestore.fieldSavingsPhp] ??
                        0.0)
                    .toDouble();

            final SystemJsonMap rawGroupsMap =
                telemetryData[_AppFirestore.fieldGroups] as SystemJsonMap? ??
                {};

            final SystemJsonMap rawPanelsMap =
                telemetryData[_AppFirestore.fieldPanels] as SystemJsonMap? ??
                {};

            final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
            final SystemJsonMap userPanelsMap = {};

            rawPanelsMap.forEach((pId, pData) {
              if (pData is SystemJsonMap) {
                final String? ownerUid =
                    pData[_AppFirestore.fieldOwnerUid] ??
                    pData[_AppFirestore.fieldOwnerUidCamel];
                final String? aggregatorId = pData['aggregator_id']?.toString();

                final bool isOwner =
                    (currentUid != null &&
                    ownerUid != null &&
                    ownerUid == currentUid);
                final bool isClaimedByConnectedSite =
                    aggregatorId != null &&
                    _connectedSitesMap.containsKey(aggregatorId);
                final bool isPaired = _userPairedDevices.contains(pId);

                if (isOwner || isClaimedByConnectedSite || isPaired) {
                  userPanelsMap[pId] = pData;
                }
              }
            });

            final SystemJsonMap userGroupsMap = {};

            _connectedSitesMap.forEach((siteId, siteName) {
              userGroupsMap[siteId] = {
                _AppFirestore.fieldGroupName: siteName,
                _AppFirestore.fieldName: siteName,
                _AppFirestore.fieldOwnerUid: currentUid,
              };
            });

            rawGroupsMap.forEach((gId, gData) {
              if (gData is SystemJsonMap) {
                final String? groupOwner =
                    gData[_AppFirestore.fieldOwnerUid] ??
                    gData[_AppFirestore.fieldOwnerUidCamel];
                final String groupName =
                    (_connectedSitesMap[gId] ??
                            gData[_AppFirestore.fieldGroupName] ??
                            gData[_AppFirestore.fieldName] ??
                            '')
                        .toString();

                final bool hasMemberPanel = userPanelsMap.values.any((p) {
                  final pGroup = p[_AppFirestore.fieldGroup]?.toString();
                  return pGroup == gId || pGroup == groupName;
                });

                if (groupOwner == currentUid ||
                    _connectedSitesMap.containsKey(gId) ||
                    hasMemberPanel) {
                  userGroupsMap[gId] = {
                    ...gData,
                    _AppFirestore.fieldGroupName: groupName,
                  };
                }
              }
            });

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                topDashboard(soc: soc, totalGenerated: displayTotalGenerated),
                const SizedBox(height: _AppDimensions.spacingSmall),
                _buildLiveMetricsRow(peakOutput, estimatedSavings),
                _buildMonitoringHeader(userGroupsMap),
                _buildPanelsList(userPanelsMap, userGroupsMap),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLiveMetricsRow(double peakOutput, double estimatedSavings) {
    final double cardWidth =
        MediaQuery.of(context).size.width *
        _AppDimensions.cardWidthFactorMetric;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Container(
          height: _AppDimensions.metricCardHeight,
          width: cardWidth,
          decoration: _cardBoxDecoration(),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(
                  top: _AppDimensions.spacingSmall,
                  bottom: _AppDimensions.spacingSmall,
                ),
                child: Text(
                  _AppStrings.peakOutputLabel,
                  style: TextStyle(
                    fontSize: _AppDimensions.fontCardTitle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: _AppDimensions.spacingSmall,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.1),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        peakOutput.toStringAsFixed(1),
                        key: ValueKey<double>(peakOutput),
                        style: const TextStyle(
                          fontSize: _AppDimensions.fontExtraLarge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: _AppDimensions.spacingMicro),
                    const Padding(
                      padding: EdgeInsets.only(
                        bottom: _AppDimensions.spacingSmall,
                      ),
                      child: Text(_AppStrings.unitKwhLower),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          height: _AppDimensions.metricCardHeight,
          width: cardWidth,
          decoration: _cardBoxDecoration(),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(
                  top: _AppDimensions.spacingSmall,
                  bottom: _AppDimensions.spacingSmall,
                ),
                child: Text(
                  _AppStrings.estimatedSavingsLabel,
                  style: TextStyle(
                    fontSize: _AppDimensions.fontCardTitle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: _AppDimensions.spacingSmall,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(
                        bottom: _AppDimensions.spacingSmall,
                      ),
                      child: Text(_AppStrings.currencySymbol),
                    ),
                    const SizedBox(width: 3),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.1),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        estimatedSavings.toStringAsFixed(0),
                        key: ValueKey<double>(estimatedSavings),
                        style: const TextStyle(
                          fontSize: _AppDimensions.fontExtraLarge,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildMonitoringHeader(SystemJsonMap groupsMap) {
    List<String> dynamicFilters = [_AppStrings.filterViewAll];

    if (groupsMap.isNotEmpty) {
      List<SystemJsonMap> groupList = groupsMap.values
          .map((e) => SystemJsonMap.from(e as Map))
          .toList();

      groupList.sort((a, b) {
        final int orderA =
            a[_AppFirestore.fieldGroupOrder] ??
            a[_AppFirestore.fieldOrder] ??
            0;
        final int orderB =
            b[_AppFirestore.fieldGroupOrder] ??
            b[_AppFirestore.fieldOrder] ??
            0;
        return orderA.compareTo(orderB);
      });

      for (var g in groupList) {
        final groupName =
            g[_AppFirestore.fieldGroupName] ?? g[_AppFirestore.fieldName];
        if (groupName != null && groupName.toString().isNotEmpty) {
          dynamicFilters.add(groupName.toString());
        }
      }
    }

    final String activeFilter = dynamicFilters.contains(selectedFilter)
        ? selectedFilter
        : _AppStrings.filterViewAll;

    return Padding(
      padding: const EdgeInsets.only(
        left: 17,
        right: 15,
        top: _AppDimensions.spacingSmall + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            _AppStrings.monitoringTitle,
            style: TextStyle(
              fontSize: _AppDimensions.fontSectionTitle,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const Text(
            _AppStrings.sortByLabel,
            style: TextStyle(
              fontSize: _AppDimensions.fontBodySmall,
              color: _AppColors.textGrey,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: activeFilter,
                dropdownColor: _AppColors.backgroundWhite,
                isDense: true,
                isExpanded: false,
                alignment: Alignment.center,
                icon: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    CupertinoIcons.chevron_down,
                    size: _AppDimensions.iconSizeExtraSmall,
                    color: _AppColors.textBlack,
                  ),
                ),
                style: const TextStyle(
                  color: _AppColors.textBlack,
                  fontSize: _AppDimensions.fontBodyMedium,
                  fontWeight: FontWeight.bold,
                ),
                borderRadius: BorderRadius.circular(
                  _AppDimensions.radiusDropdownFilter,
                ),
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

  Widget _buildPanelsList(SystemJsonMap panelsMap, SystemJsonMap groupsMap) {
    if (panelsMap.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          vertical: _AppDimensions.spacingExtraLarge,
        ),
        child: Center(
          child: Text(
            _AppStrings.noPanelsRegistered,
            style: TextStyle(
              color: _AppColors.textGrey,
              fontSize: _AppDimensions.fontBodyMedium,
            ),
          ),
        ),
      );
    }

    if (groupsMap.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          vertical: _AppDimensions.spacingExtraLarge,
        ),
        child: Center(
          child: Text(
            _AppStrings.noGroupsAvailable,
            style: TextStyle(
              color: _AppColors.textGrey,
              fontSize: _AppDimensions.fontBodyMedium,
            ),
          ),
        ),
      );
    }

    List<SystemJsonMap> allPanelsList = panelsMap.values
        .map((e) => SystemJsonMap.from(e as Map))
        .toList();

    allPanelsList.sort((a, b) {
      final int orderA =
          a[_AppFirestore.fieldPanelOrder] ?? a[_AppFirestore.fieldOrder] ?? 0;
      final int orderB =
          b[_AppFirestore.fieldPanelOrder] ?? b[_AppFirestore.fieldOrder] ?? 0;
      return orderA.compareTo(orderB);
    });

    List<MapEntry<String, SystemJsonMap>> groupEntries = groupsMap.entries
        .map((e) => MapEntry(e.key, SystemJsonMap.from(e.value as Map)))
        .toList();

    groupEntries.sort((a, b) {
      final int orderA =
          a.value[_AppFirestore.fieldGroupOrder] ??
          a.value[_AppFirestore.fieldOrder] ??
          0;
      final int orderB =
          b.value[_AppFirestore.fieldGroupOrder] ??
          b.value[_AppFirestore.fieldOrder] ??
          0;
      return orderA.compareTo(orderB);
    });

    if (selectedFilter != _AppStrings.filterViewAll) {
      groupEntries = groupEntries.where((entry) {
        final String groupName =
            (_connectedSitesMap[entry.key] ??
                    entry.value[_AppFirestore.fieldGroupName] ??
                    entry.value[_AppFirestore.fieldName] ??
                    '')
                .toString();
        return entry.key == selectedFilter || groupName == selectedFilter;
      }).toList();
    }

    if (groupEntries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          vertical: _AppDimensions.spacingExtraLarge,
        ),
        child: Center(
          child: Text(
            _AppStrings.noPanelsFoundInGroup,
            style: TextStyle(
              color: _AppColors.textGrey,
              fontSize: _AppDimensions.fontBodyMedium,
            ),
          ),
        ),
      );
    }

    List<Widget> children = [];

    for (var groupEntry in groupEntries) {
      final String groupKey = groupEntry.key;
      final SystemJsonMap groupData = groupEntry.value;
      final String groupName =
          _connectedSitesMap[groupKey] ??
          groupData[_AppFirestore.fieldGroupName] ??
          groupData[_AppFirestore.fieldName] ??
          _AppStrings.unnamedGroup;

      final groupPanels = allPanelsList.where((panelData) {
        return _isPanelInGroup(panelData, groupKey, groupData);
      }).toList();

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
            padding: EdgeInsets.only(
              bottom: _AppDimensions.spacingMedium,
              top: _AppDimensions.spacingMicro,
            ),
            child: Center(
              child: Text(
                _AppStrings.noPanelsInThisGroup,
                style: TextStyle(
                  color: _AppColors.textGrey,
                  fontSize: _AppDimensions.fontSubtitle,
                ),
              ),
            ),
          ),
        );
      } else {
        for (int i = 0; i < groupPanels.length; i++) {
          final panelData = groupPanels[i];
          final int panelIndex = i + 1;
          final String panelId =
              panelData['panel_id']?.toString() ??
              panelData['id']?.toString() ??
              'panel_$panelIndex';

          // Use real-time panel name from Firestore, falling back to claimed/unclaimed format
          final String displayPanelName =
              panelData['panel_name']?.toString() ??
              panelData['name']?.toString() ??
              'Panel_$panelIndex - $groupName';

          final SystemJsonMap? sensorData =
              panelData[_AppFirestore.fieldSensorData] as SystemJsonMap?;

          final double rawPowerW =
              (sensorData?[_AppFirestore.fieldOutputPowerW] ?? 0.0).toDouble();

          final double value =
              sensorData?[_AppFirestore.fieldOutputPowerW] != null
              ? rawPowerW / 1000.0
              : (panelData[_AppFirestore.fieldPowerKwh] ??
                        panelData[_AppFirestore.fieldPowerW] ??
                        panelData[_AppFirestore.fieldPower] ??
                        0.0)
                    .toDouble();

          children.add(
            _SwipeablePanelCard(
              key: ValueKey<String>('swipe_panel_$panelId'),
              panelId: panelId,
              title: displayPanelName,
              value: value,
              onRename: () => _showRenamePanelDialog(panelId, displayPanelName),
            ),
          );
        }
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Column(
        key: ValueKey<String>('panels_list_$selectedFilter'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  bool _isPanelInGroup(
    SystemJsonMap panelData,
    String groupKey,
    SystemJsonMap groupData,
  ) {
    final String groupName =
        (_connectedSitesMap[groupKey] ??
                groupData[_AppFirestore.fieldGroupName] ??
                groupData[_AppFirestore.fieldName] ??
                '')
            .toString();
    final String? panelGroup = panelData[_AppFirestore.fieldGroup]?.toString();
    final String? panelGroupName = panelData[_AppFirestore.fieldGroupName]
        ?.toString();
    final String? panelAggregatorId = panelData['aggregator_id']?.toString();

    if (panelAggregatorId != null && panelAggregatorId == groupKey) {
      return true;
    }

    if (panelGroup != null && panelGroup.isNotEmpty && panelGroup == groupKey) {
      return true;
    }

    if (groupName.isNotEmpty) {
      if (panelGroup == groupName) return true;
      if (panelGroupName == groupName) return true;
    }

    return false;
  }

  Widget _buildGroupSectionHeader(String groupName) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 17,
        right: 17,
        top: 14,
        bottom: _AppDimensions.spacingTiny,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(_AppDimensions.spacingMicro),
            decoration: BoxDecoration(
              color: _AppColors.midGreen.withValues(
                alpha: _AppDimensions.shadowAlphaIconBg,
              ),
              borderRadius: BorderRadius.circular(_AppDimensions.radiusBadge),
            ),
            child: const Icon(
              CupertinoIcons.rectangle_grid_2x2,
              size: _AppDimensions.iconSizeSmall,
              color: _AppColors.midGreen,
            ),
          ),
          const SizedBox(width: _AppDimensions.spacingTiny),
          Text(
            groupName,
            style: const TextStyle(
              fontSize: _AppDimensions.fontCardTitle,
              fontWeight: FontWeight.bold,
              color: _AppColors.textBlack87,
            ),
          ),
          const Spacer(),
          const Icon(
            CupertinoIcons.chevron_right,
            size: _AppDimensions.iconSizeSmall,
            color: _AppColors.textGrey,
          ),
        ],
      ),
    );
  }

  Widget topDashboard({required double soc, required double totalGenerated}) {
    return Container(
      height: _AppDimensions.dashboardHeight,
      decoration: const BoxDecoration(
        color: _AppColors.midGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_AppDimensions.radiusDashboard),
          bottomRight: Radius.circular(_AppDimensions.radiusDashboard),
        ),
        gradient: LinearGradient(
          colors: [_AppColors.darkGreen, _AppColors.midGreen],
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
              _AppStrings.houseDashAsset,
              fit: BoxFit.contain,
              alignment: Alignment.topRight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: _AppDimensions.spacingSmall,
              left: _AppDimensions.spacingStandard,
              right: _AppDimensions.spacingStandard,
            ),
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
                const SizedBox(height: _AppDimensions.spacingStandard),
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
                            totalGenerated.toStringAsFixed(2),
                            key: ValueKey<String>(
                              'total_gen_${selectedTimeRange}_$totalGenerated',
                            ),
                            style: const TextStyle(
                              fontSize: _AppDimensions.fontHeaderLarge,
                              fontWeight: FontWeight.bold,
                              color: _AppColors.iconWhite,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          _AppStrings.unitKwhUpper,
                          style: TextStyle(
                            fontSize: _AppDimensions.fontHeaderMedium,
                            fontWeight: FontWeight.bold,
                            color: _AppColors.iconWhite,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      _AppStrings.totalGeneratedLabel,
                      style: TextStyle(
                        fontSize: _AppDimensions.fontSectionHeader,
                        color: _AppColors.iconWhite,
                      ),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _AppColors.darkGreen,
        borderRadius: BorderRadius.circular(_AppDimensions.radiusDropdown),
        border: Border.all(
          color: _AppColors.borderGreen,
          width: _AppDimensions.borderWidthStandard,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedTimeRange,
          dropdownColor: _AppColors.darkGreen,
          icon: const Padding(
            padding: EdgeInsets.only(left: _AppDimensions.spacingMicro),
            child: Icon(
              CupertinoIcons.chevron_down,
              size: _AppDimensions.iconSizeSmall,
              color: _AppColors.iconWhite,
            ),
          ),
          style: const TextStyle(
            color: _AppColors.iconWhite,
            fontSize: _AppDimensions.fontBodySmall,
            fontWeight: FontWeight.w500,
          ),
          borderRadius: BorderRadius.circular(
            _AppDimensions.radiusDropdownMenu,
          ),
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
              Icon(
                CupertinoIcons.bolt_fill,
                size: _AppDimensions.iconSizeExtraLarge,
                color: _AppColors.iconWhite,
              ),
              Icon(
                CupertinoIcons.bolt_fill,
                size: _AppDimensions.iconSizeLarge,
                color: _AppColors.textBlack,
              ),
              Icon(
                CupertinoIcons.bolt_fill,
                size: _AppDimensions.iconSizeMediumLarge,
                color: _AppColors.boltYellow,
              ),
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
      height: _AppDimensions.appBarButtonSize,
      width: _AppDimensions.appBarButtonSize,
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _AppColors.borderGreen,
          width: _AppDimensions.borderWidthThick,
        ),
        boxShadow: [
          BoxShadow(
            color: _AppColors.textBlack.withValues(
              alpha: _AppDimensions.shadowAlphaBadge,
            ),
            blurRadius: 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: _AppDimensions.iconSizeMediumLarge,
        color: _AppColors.iconWhite,
      ),
    );
  }

  Widget _buildSideMenu(BuildContext context) {
    return Drawer(
      backgroundColor: _AppColors.backgroundWhite,
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(
              top: 60,
              left: _AppDimensions.spacingLarge,
              right: _AppDimensions.spacingLarge,
              bottom: 20,
            ),
            color: _AppColors.backgroundWhite,
            child: Row(
              children: [
                Container(
                  height: _AppDimensions.drawerHeaderIconSize,
                  width: _AppDimensions.drawerHeaderIconSize,
                  decoration: BoxDecoration(
                    color: _AppColors.drawerBgGrey,
                    borderRadius: BorderRadius.circular(
                      _AppDimensions.radiusDropdownFilter,
                    ),
                    border: Border.all(color: _AppColors.drawerBorderGrey),
                  ),
                  child: const Icon(
                    CupertinoIcons.bolt,
                    color: _AppColors.textBlack87,
                    size: _AppDimensions.iconSizeStandard,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  _AppStrings.menuHeader,
                  style: TextStyle(
                    color: _AppColors.textBlack,
                    fontSize: _AppDimensions.fontDrawerMenu,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _AppDimensions.spacingLarge,
            ),
            child: Divider(color: _AppColors.drawerBorderGrey, height: 1),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: _AppDimensions.spacingMedium,
                vertical: _AppDimensions.spacingMedium,
              ),
              children: [
                _buildSectionHeader(_AppStrings.sectionDashboards),
                _buildDrawerItem(
                  icon: CupertinoIcons.chart_pie,
                  title: _AppStrings.menuOverview,
                  isSelected: true,
                  onTap: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
                _buildDrawerItem(
                  icon: CupertinoIcons.graph_square,
                  title: _AppStrings.menuMetrics,
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
                _buildSectionHeader(_AppStrings.sectionSetup),
                _buildDrawerItem(
                  icon: CupertinoIcons.plus_square,
                  title: _AppStrings.menuAddSetup,
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
                const SizedBox(height: 20),
                _buildSectionHeader(_AppStrings.sectionSettingsAccount),
                _buildDrawerItem(
                  icon: CupertinoIcons.gear,
                  title: _AppStrings.menuSettings,
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
                  title: _AppStrings.menuLogOut,
                  isDestructive: true,
                  onTap: _handleLogout,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(_AppDimensions.spacingLarge),
            child: Text(
              _AppStrings.appVersion,
              style: TextStyle(
                color: _AppColors.textGrey500,
                fontSize: _AppDimensions.fontBodySmall,
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
      padding: const EdgeInsets.only(
        left: 12,
        bottom: _AppDimensions.spacingTiny,
        top: _AppDimensions.spacingMicro,
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: _AppColors.textSubtleGrey,
          fontSize: _AppDimensions.fontSectionHeader,
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
        ? _AppColors.destructiveRed
        : (isSelected ? _AppColors.textPrimaryDark : _AppColors.textSubtleGrey);

    final Color textColor = isDestructive
        ? _AppColors.destructiveRed
        : (isSelected ? _AppColors.textBlack : _AppColors.textDarkGrey);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        tileColor: isSelected ? _AppColors.drawerBgGrey : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        dense: true,
        leading: Icon(
          icon,
          color: iconColor,
          size: _AppDimensions.iconSizeDrawer,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: _AppDimensions.fontBodyMedium,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: _AppDimensions.radiusIndicatorDot,
                height: _AppDimensions.radiusIndicatorDot,
                decoration: const BoxDecoration(
                  color: _AppColors.activeIndicatorGreen,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final List<String> targetUids = ['all'];
    if (currentUser != null && currentUser.uid.isNotEmpty) {
      targetUids.add(currentUser.uid);
    }

    return AppBar(
      toolbarHeight: _AppDimensions.appBarHeight,
      leadingWidth: _AppDimensions.appBarHeight,
      backgroundColor: _AppColors.darkGreen,
      leading: Center(
        child: GestureDetector(
          onTap: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          child: Container(
            height: _AppDimensions.appBarButtonSize,
            width: _AppDimensions.appBarButtonSize,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: _AppColors.borderGreen,
                width: _AppDimensions.borderWidthStandard,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              CupertinoIcons.line_horizontal_3_decrease,
              size: _AppDimensions.iconSizeStandard,
              color: _AppColors.iconWhite,
            ),
          ),
        ),
      ),
      actions: [
        Center(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('targetUid', whereIn: targetUids)
                .snapshots(),
            builder: (context, snapshot) {
              bool hasUnread = false;
              if (snapshot.hasData && snapshot.data != null) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final isReadRaw = data['isRead'];
                  bool isRead = false;
                  if (isReadRaw is bool) {
                    isRead = isReadRaw;
                  } else if (isReadRaw is String) {
                    isRead = isReadRaw.toLowerCase() == 'true';
                  }
                  if (!isRead) {
                    hasUnread = true;
                    break;
                  }
                }
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: _AppDimensions.appBarButtonSize,
                      height: _AppDimensions.appBarButtonSize,
                      margin: const EdgeInsets.only(right: 15),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _AppColors.borderGreen,
                          width: _AppDimensions.borderWidthStandard,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        CupertinoIcons.bell,
                        size: _AppDimensions.iconSizeMedium,
                        color: _AppColors.iconWhite,
                      ),
                    ),
                    if (hasUnread)
                      Positioned(
                        top: 2,
                        right: 17,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _AppColors.destructiveRed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _AppColors.darkGreen,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardBoxDecoration() {
    return BoxDecoration(
      color: _AppColors.backgroundWhite,
      borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
      boxShadow: [
        BoxShadow(
          color: _AppColors.cardShadow.withValues(
            alpha: _AppDimensions.shadowAlphaCard,
          ),
          spreadRadius: 2,
          blurRadius: 3,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

class _SwipeablePanelCard extends StatefulWidget {
  final String panelId;
  final String title;
  final double value;
  final VoidCallback onRename;

  const _SwipeablePanelCard({
    super.key,
    required this.panelId,
    required this.title,
    required this.value,
    required this.onRename,
  });

  @override
  State<_SwipeablePanelCard> createState() => _SwipeablePanelCardState();
}

class _SwipeablePanelCardState extends State<_SwipeablePanelCard> {
  double _dragOffset = 0.0;
  static const double _actionsWidth = 85.0;

  void _close() {
    if (mounted) {
      setState(() {
        _dragOffset = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double cardWidth =
        MediaQuery.of(context).size.width * _AppDimensions.cardWidthFactorPanel;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Transform.translate(
            offset: Offset(0, (1 - animValue) * 12),
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            height: _AppDimensions.panelMetricCardHeight,
            width: cardWidth,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        _AppDimensions.radiusCard,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () {
                            _close();
                            widget.onRename();
                          },
                          child: Container(
                            width: _actionsWidth,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2B88D8),
                              borderRadius: BorderRadius.circular(
                                _AppDimensions.radiusCard,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Rename',
                              style: TextStyle(
                                color: _AppColors.backgroundWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOutCubic,
                  top: 0,
                  bottom: 0,
                  left: _dragOffset,
                  right: -_dragOffset,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _dragOffset = (_dragOffset + details.delta.dx).clamp(
                          -_actionsWidth,
                          0.0,
                        );
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      setState(() {
                        if (_dragOffset < -_actionsWidth / 2) {
                          _dragOffset = -_actionsWidth;
                        } else {
                          _dragOffset = 0.0;
                        }
                      });
                    },
                    onTap: () {
                      if (_dragOffset < 0) {
                        _close();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MonitoringScreen(panelId: widget.panelId),
                          ),
                        );
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _AppColors.backgroundWhite,
                        borderRadius: BorderRadius.circular(
                          _AppDimensions.radiusCard,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _AppColors.cardShadow.withValues(
                              alpha: _AppDimensions.shadowAlphaCard,
                            ),
                            spreadRadius: 2,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: _AppDimensions.spacingStandard),
                          Expanded(
                            child: Transform.translate(
                              offset: Offset(-_dragOffset, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    _AppStrings.individualValueLabel,
                                    style: TextStyle(
                                      fontSize: _AppDimensions.fontCaption,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.0, 0.1),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Text(
                                  widget.value < 1.0
                                      ? widget.value.toStringAsFixed(2)
                                      : widget.value.toStringAsFixed(1),
                                  key: ValueKey<double>(widget.value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: _AppDimensions.fontValueLarge,
                                  ),
                                ),
                              ),
                              const Text(
                                _AppStrings.unitKwhUpper,
                                style: TextStyle(
                                  fontSize: _AppDimensions.fontSubtitle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: _AppDimensions.spacingStandard),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
