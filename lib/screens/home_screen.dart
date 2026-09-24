import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ADDED: Cloud Firestore
import 'package:firebase_auth/firebase_auth.dart'; // ADDED: For logout support
import 'login_screen.dart'; // ADDED: For logout navigation

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

  // ADDED: Stream to listen to real-time Firestore telemetry updates
  final Stream<DocumentSnapshot> _telemetryStream = FirebaseFirestore.instance
      .collection('system_status')
      .doc('current')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _telemetryStream,
      builder: (context, snapshot) {
        // Extract live telemetry values with fallback defaults
        final Map<String, dynamic> data =
            (snapshot.hasData && snapshot.data!.data() != null)
            ? snapshot.data!.data() as Map<String, dynamic>
            : {};

        // Parse key live metrics safely from Firestore document
        final double soc =
            (data['battery_soc'] ?? data['soc'] ?? widget.currentPercentage)
                .toDouble();
        final double totalGenerated =
            (data['total_generated_kwh'] ?? data['total_kwh'] ?? 69.32)
                .toDouble();
        final double peakOutput =
            (data['peak_output_kw'] ?? data['peak_power'] ?? 20.0).toDouble();
        final double estimatedSavings =
            (data['estimated_savings'] ?? data['savings_php'] ?? 0.0)
                .toDouble();

        // Parse dynamic solar panels list if available, else fall back to cardCount
        final List<dynamic> panelsData =
            (data['panels'] as List<dynamic>?) ?? [];

        return Scaffold(
          key: _scaffoldKey,
          drawer: _buildSideMenu(context),
          appBar: appBar(),
          body: Container(
            decoration: const BoxDecoration(color: Colors.white),
            child: ListView(
              children: [
                // Live Top Dashboard with battery SoC & Total Generated
                topDashboard(soc: soc, totalGenerated: totalGenerated),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // PEAK OUTPUT CARD
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const SizedBox(width: 10),
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
                                ),
                              ],
                            ),
                          ),

                          // ESTIMATED SAVINGS CARD
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
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

                // Dynamic Solar Monitoring Cards from Firestore or Widget Fallback
                Column(
                  children: [
                    const SizedBox(height: 8),
                    if (panelsData.isNotEmpty)
                      ...panelsData.map((panel) {
                        final String name = panel['name'] ?? 'Solar Panel';
                        final double val =
                            (panel['power_kwh'] ?? panel['power_w'] ?? 30.0)
                                .toDouble();
                        return metricCard(title: name, value: val);
                      })
                    else
                      ...List.generate(widget.cardCount, (index) {
                        return metricCard(
                          title: 'Solar Panel ${index + 1}',
                          value: 30.0,
                        );
                      }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
                  children: const [
                    Text(
                      'Menu',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
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
                  onTap: () async {
                    Navigator.pop(context); // Close Drawer
                    await FirebaseAuth.instance
                        .signOut(); // ADDED: Logout action
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const SlickLoginScreen(),
                        ),
                      );
                    }
                  },
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

  // MODIFIED: Parameterized to accept live dynamic metric values
  Widget metricCard({required String title, required double value}) {
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
                children: [
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2.5),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 21,
                      ),
                    ),
                  ),
                  const Text('Individual Value', style: TextStyle(fontSize: 9)),
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
                    child: Text(
                      value.toStringAsFixed(0),
                      style: const TextStyle(
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

  // MODIFIED: Parameterized with live dynamic values from Firestore
  Widget topDashboard({required double soc, required double totalGenerated}) {
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
                    // Live dynamic charging segment bar
                    dynamicChargingBar(soc),
                    const SizedBox(height: 4),
                    Text(
                      '${soc.toStringAsFixed(0)}% Charged',
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

  // MODIFIED: Accepts live battery percentage to dynamically highlight bar segments
  Row dynamicChargingBar(double socPercentage) {
    const int totalSegment = 10;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSegment, (index) {
        final double segmentStart = index * 10.0;
        final double segmentEnd = (index + 1) * 10.0;

        final bool isFullyFilled = socPercentage >= segmentEnd;
        final bool isPartiallyFilled =
            socPercentage > segmentStart && socPercentage < segmentEnd;

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
