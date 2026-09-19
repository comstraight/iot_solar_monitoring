import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../screens/analytics_screen.dart';
import '../screens/initial_setup_screen.dart';
import '../screens/groups_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/login_screen.dart';
import '../screens/notification_screen.dart';

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

  // Dropdown state variables
  String selectedTimeRange = 'This Week';
  String selectedFilter = 'View All';

  final List<String> timeRanges = [
    'Today',
    'This Week',
    'This Month',
    'This Year',
  ];

  final List<String> filterOptions = ['View All', 'Home 1', 'Home 2', 'Work'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildSideMenu(context),
      appBar: appBar(),
      body: Container(
        decoration: const BoxDecoration(color: Colors.white),
        child: ListView(
          children: [
            topDashboard(),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Container(
                        alignment: const Alignment(0, -0.8),
                        height: 120,
                        width: MediaQuery.of(context).size.width * 0.46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.3),
                              spreadRadius: 2,
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 10, bottom: 10),
                              child: Text(
                                'Peak Output',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              margin: const EdgeInsets.only(
                                top: 10,
                                bottom: 10,
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: const [
                                    SizedBox(width: 28),
                                    Text(
                                      '20',
                                      style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 10),
                                      child: Text('kw/h'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        alignment: const Alignment(0, -0.8),
                        height: 120,
                        width: MediaQuery.of(context).size.width * 0.46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.3),
                              spreadRadius: 2,
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 10, bottom: 10),
                              child: Text(
                                'Estimated Savings',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              margin: const EdgeInsets.only(
                                top: 10,
                                bottom: 10,
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: const [
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 10),
                                      child: Text('P'),
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      '1',
                                      style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
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
            ),

            // Monitoring Section Header with Dropdown
            Padding(
              padding: const EdgeInsets.only(left: 17, right: 15, top: 12),
              child: Row(
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
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedFilter,
                      dropdownColor: Colors.white,
                      icon: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          CupertinoIcons.chevron_down,
                          size: 14,
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
                        if (newValue != null) {
                          setState(() {
                            selectedFilter = newValue;
                          });
                        }
                      },
                      items: filterOptions.map<DropdownMenuItem<String>>((
                        String value,
                      ) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            Column(
              children: [
                const SizedBox(height: 8),
                ...List.generate(widget.cardCount, (index) {
                  return metricCard();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- CLEAN WHITE & BLACK SIDE MENU DRAWER ---
  Widget _buildSideMenu(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Menu',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: Color(0xFFE5E7EB), height: 1),
          ),

          // Categorized Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                _buildSectionHeader('DASHBOARDS'),
                _buildDrawerItem(
                  icon: CupertinoIcons.chart_pie,
                  title: 'Overview',
                  isSelected: true,
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  icon: CupertinoIcons.graph_square,
                  title: 'Metrics',
                  onTap: () => Navigator.pop(context),
                ),

                const SizedBox(height: 20),
                _buildSectionHeader('SETUP'),
                _buildDrawerItem(
                  icon: CupertinoIcons.plus_square,
                  title: 'Add a Setup',
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  icon: CupertinoIcons.rectangle_grid_2x2,
                  title: 'Edit Groups',
                  onTap: () => Navigator.pop(context),
                ),

                const SizedBox(height: 20),
                _buildSectionHeader('SETTINGS AND ACCOUNT'),
                _buildDrawerItem(
                  icon: CupertinoIcons.gear,
                  title: 'Settings',
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  icon: CupertinoIcons.square_arrow_right,
                  title: 'Log Out',
                  isDestructive: true,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Footer
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

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF3F4F6) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
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

  Row metricCard() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          height: 100,
          width: MediaQuery.of(context).size.width * 0.93,
          decoration: BoxDecoration(
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
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SizedBox(height: 22),
                  Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 2.5),
                    child: Text(
                      'Solar Panel',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 21,
                      ),
                    ),
                  ),
                  Text('Individual Value', style: TextStyle(fontSize: 9)),
                ],
              ),
              const Spacer(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    alignment: Alignment.bottomCenter,
                    child: const Text(
                      '30',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 30,
                      ),
                    ),
                  ),
                  Container(
                    alignment: Alignment.topCenter,
                    child: const Text('KW/H', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(width: 15),
            ],
          ),
        ),
      ],
    );
  }

  Widget topDashboard() {
    return Container(
      height: 300,
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
                    Container(
                      margin: const EdgeInsets.only(
                        right: 3,
                        top: 3,
                        bottom: 3,
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: const [
                          Icon(
                            CupertinoIcons.bolt_fill,
                            size: 27,
                            color: Colors.white,
                          ),
                          Icon(
                            CupertinoIcons.bolt_fill,
                            size: 24,
                            color: Colors.black,
                          ),
                          Icon(
                            CupertinoIcons.bolt_fill,
                            size: 23,
                            color: Colors.yellow,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF20341E),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      margin: const EdgeInsets.all(3),
                      alignment: Alignment.center,
                      child: const Icon(
                        CupertinoIcons.exclamationmark_triangle,
                        size: 23,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF20341E),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      margin: const EdgeInsets.all(3),
                      alignment: Alignment.center,
                      child: const Icon(
                        CupertinoIcons.battery_100,
                        size: 23,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),

                    // Top Time Range Dropdown Container
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF092508),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF20341E),
                          width: 1.5,
                        ),
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
                            }
                          },
                          items: timeRanges.map<DropdownMenuItem<String>>((
                            String value,
                          ) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: const [
                        Text(
                          '69.32',
                          style: TextStyle(
                            fontSize: 35,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
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
                    const SizedBox(height: 30),
                    const Text(
                      'Charging',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    dynamicChargingBar(),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.currentPercentage.toStringAsFixed(0)}% Charged',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
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

  AppBar appBar() {
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
            onTap: () {},
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

  Row dynamicChargingBar() {
    const int totalSegment = 10;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSegment, (index) {
        final double segmentStart = index * 10.0;
        final double segmentEnd = (index + 1) * 10.0;

        final bool isFullyFilled = widget.currentPercentage >= segmentEnd;
        final bool isPartiallyFilled =
            widget.currentPercentage > segmentStart &&
            widget.currentPercentage < segmentEnd;

        Color segmentColor;
        List<BoxShadow> shadowList = [];

        if (isFullyFilled) {
          segmentColor = const Color(0xFF00FF22);
          shadowList = [
            BoxShadow(
              color: const Color(0xFF00FF22).withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ];
        } else if (isPartiallyFilled) {
          segmentColor = const Color(0xFF00FF22).withValues(alpha: 0.35);
        } else {
          segmentColor = const Color(0xFF1C7A18).withValues(alpha: 0.4);
        }

        return Container(
          width: 15,
          height: 27,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: segmentColor,
            boxShadow: shadowList,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
