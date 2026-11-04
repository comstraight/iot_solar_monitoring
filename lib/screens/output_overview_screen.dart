// output_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'analytics_screen.dart';

/// Type definitions to prevent generic angle-bracket stripping issues
typedef SystemDocumentSnapshot = DocumentSnapshot<SystemJsonMap>;
typedef SystemJsonMap = Map<String, dynamic>;

/// Centralized UI Colors
abstract class _AppColors {
  static const Color backgroundWhite = Colors.white;
  static const Color iconButtonBg = Color(0xFFE5E7EB);
  static const Color textBlack = Colors.black;
  static const Color textBlack87 = Colors.black87;
  static const Color textBlack54 = Colors.black54;
}

/// Centralized Text Strings
abstract class _AppStrings {
  static const String screenTitle = 'Output Overview';
  static const String fallbackSiteName = 'Site Name';
  static const String unitKwh = 'kWh';

  static const String fallbackGroupId1 = 'group_01';
  static const String fallbackGroupId2 = 'group_02';
  static const String fallbackGroupId3 = 'group_03';
  static const String fallbackGroupId4 = 'group_04';
}

/// Centralized Layout Dimensions & Numeric Defaults
abstract class _AppDimensions {
  static const double appBarHeight = 80.0;
  static const double appBarHorizontalPadding = 20.0;
  static const double appBarVerticalPadding = 12.0;

  static const double iconButtonSize = 42.0;
  static const double iconSizeBack = 20.0;
  static const double iconSizeChart = 22.0;
  static const double iconSizeChevron = 26.0;

  static const double fontScreenTitle = 18.0;
  static const double fontSiteName = 16.0;
  static const double fontKwhValue = 14.0;

  static const double listHorizontalPadding = 24.0;
  static const double listVerticalPadding = 24.0;
  static const double listSeparatorHeight = 36.0;
  static const double itemVerticalPadding = 4.0;
  static const double spacingWidthMedium = 12.0;

  static const double fallbackKwh = 200.0;
}

/// Centralized Firestore Collection Names & Field Constants
abstract class _AppFirestore {
  static const String collectionSystemStatus = 'system_status';
  static const String docCurrent = 'current';

  static const String fieldGroups = 'groups';
  static const String fieldOutputOverview = 'output_overview';
  static const String fieldDaily = 'daily';
  static const String fieldName = 'name';
  static const String fieldGroupName = 'group_name';
  static const String fieldGroupId = 'group_id';
  static const String fieldTotalKwh = 'totalKwh';
  static const String fieldOutputKwh = 'output_kwh';
  static const String fieldTotalKwhSnake = 'total_kwh';
  static const String fieldKwh = 'kwh';
}

class SiteOutputItem {
  final String id;
  final String name;
  final double totalKwh;

  SiteOutputItem({
    required this.id,
    required this.name,
    required this.totalKwh,
  });

  factory SiteOutputItem.fromMap(String id, SystemJsonMap data) {
    return SiteOutputItem(
      id: id,
      name:
          (data[_AppFirestore.fieldGroupName] ??
                  data[_AppFirestore.fieldName] ??
                  _AppStrings.fallbackSiteName)
              .toString(),
      totalKwh:
          ((data[_AppFirestore.fieldKwh] ??
                      data[_AppFirestore.fieldTotalKwh] ??
                      data[_AppFirestore.fieldOutputKwh] ??
                      data[_AppFirestore.fieldTotalKwhSnake] ??
                      _AppDimensions.fallbackKwh)
                  as num)
              .toDouble(),
    );
  }
}

class OutputOverviewScreen extends StatefulWidget {
  const OutputOverviewScreen({super.key});

  @override
  State<OutputOverviewScreen> createState() => _OutputOverviewScreenState();
}

class _OutputOverviewScreenState extends State<OutputOverviewScreen> {
  List<SiteOutputItem> _getFallbackSites() {
    return [
      SiteOutputItem(
        id: _AppStrings.fallbackGroupId1,
        name: _AppStrings.fallbackSiteName,
        totalKwh: _AppDimensions.fallbackKwh,
      ),
      SiteOutputItem(
        id: _AppStrings.fallbackGroupId2,
        name: _AppStrings.fallbackSiteName,
        totalKwh: _AppDimensions.fallbackKwh,
      ),
      SiteOutputItem(
        id: _AppStrings.fallbackGroupId3,
        name: _AppStrings.fallbackSiteName,
        totalKwh: _AppDimensions.fallbackKwh,
      ),
      SiteOutputItem(
        id: _AppStrings.fallbackGroupId4,
        name: _AppStrings.fallbackSiteName,
        totalKwh: _AppDimensions.fallbackKwh,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.backgroundWhite,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(_AppDimensions.appBarHeight),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _AppDimensions.appBarHorizontalPadding,
              vertical: _AppDimensions.appBarVerticalPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: _AppDimensions.iconButtonSize,
                    height: _AppDimensions.iconButtonSize,
                    decoration: const BoxDecoration(
                      color: _AppColors.iconButtonBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: _AppColors.textBlack,
                      size: _AppDimensions.iconSizeBack,
                    ),
                  ),
                ),
                const Text(
                  _AppStrings.screenTitle,
                  style: TextStyle(
                    fontSize: _AppDimensions.fontScreenTitle,
                    fontWeight: FontWeight.bold,
                    color: _AppColors.textBlack,
                  ),
                ),
                Container(
                  width: _AppDimensions.iconButtonSize,
                  height: _AppDimensions.iconButtonSize,
                  decoration: const BoxDecoration(
                    color: _AppColors.iconButtonBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: _AppColors.textBlack,
                    size: _AppDimensions.iconSizeChart,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<SystemDocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection(_AppFirestore.collectionSystemStatus)
            .doc(_AppFirestore.docCurrent)
            .snapshots(includeMetadataChanges: false),
        builder: (context, snapshot) {
          List<SiteOutputItem> sites = [];

          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.exists) {
            final SystemJsonMap data =
                (snapshot.data!.data() ?? {}) as SystemJsonMap;

            // 1. Check pre-calculated output_overview['daily'] array
            final outputOverview =
                data[_AppFirestore.fieldOutputOverview] as SystemJsonMap?;
            if (outputOverview != null &&
                outputOverview[_AppFirestore.fieldDaily] is List) {
              final dailyList =
                  outputOverview[_AppFirestore.fieldDaily] as List;
              for (var item in dailyList) {
                if (item is Map) {
                  final itemMap = SystemJsonMap.from(item);
                  final gId = (itemMap[_AppFirestore.fieldGroupId] ?? '')
                      .toString();
                  sites.add(SiteOutputItem.fromMap(gId, itemMap));
                }
              }
            }

            // 2. Fallback to groups map if output_overview daily list is absent or empty
            if (sites.isEmpty) {
              final groupsMap =
                  data[_AppFirestore.fieldGroups] as SystemJsonMap? ?? {};

              groupsMap.forEach((key, value) {
                if (value is Map) {
                  sites.add(
                    SiteOutputItem.fromMap(key, SystemJsonMap.from(value)),
                  );
                }
              });
            }
          }

          if (sites.isEmpty) {
            sites = _getFallbackSites();
          }

          sites.sort((a, b) => b.totalKwh.compareTo(a.totalKwh));

          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: _AppDimensions.listHorizontalPadding,
              vertical: _AppDimensions.listVerticalPadding,
            ),
            itemCount: sites.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: _AppDimensions.listSeparatorHeight),
            itemBuilder: (context, index) {
              final site = sites[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnalyticsScreen(
                        initialSiteId: site.id,
                        initialSiteName: site.name,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: _AppDimensions.itemVerticalPadding,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        site.name,
                        style: const TextStyle(
                          fontSize: _AppDimensions.fontSiteName,
                          fontWeight: FontWeight.bold,
                          color: _AppColors.textBlack,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${site.totalKwh.toStringAsFixed(0)}${_AppStrings.unitKwh}',
                            style: const TextStyle(
                              fontSize: _AppDimensions.fontKwhValue,
                              fontWeight: FontWeight.w600,
                              color: _AppColors.textBlack87,
                            ),
                          ),
                          const SizedBox(
                            width: _AppDimensions.spacingWidthMedium,
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: _AppColors.textBlack54,
                            size: _AppDimensions.iconSizeChevron,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
