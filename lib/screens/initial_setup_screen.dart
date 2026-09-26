import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  // Theme Color Constants
  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color cardBg = Colors.white;
  static const Color pageBg = Color(0xFFF8FAF8);

  bool _isConfiguring = false;

  // Helper SnackBar for visual feedback
  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent.shade700 : darkGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: isError ? Colors.white : Colors.greenAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPanelWizard(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final panelNameController = TextEditingController();
    final capacityController = TextEditingController();
    final nodeIdController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Text(
                    'Link Solar Hardware',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: darkGreen,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Configure your solar array telemetry node.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 28),

                  _buildModernTextField(
                    controller: panelNameController,
                    label: 'Panel Identifier',
                    hint: 'e.g., Roof Array - Panel 3',
                    icon: Icons.solar_power_rounded,
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Please give your panel a name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: capacityController,
                    label: 'Rated Max Capacity (Watts)',
                    hint: 'e.g., 300',
                    icon: Icons.bolt_rounded,
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Enter rated wattage'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: nodeIdController,
                    label: 'Microcontroller Node ID',
                    hint: 'e.g., SOLAR-3C71BF',
                    icon: Icons.developer_board_rounded,
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Enter hardware Device ID'
                        : null,
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          final String? currentUid =
                              FirebaseAuth.instance.currentUser?.uid;

                          if (currentUid == null) {
                            _showSnackBar(
                              context,
                              'You must be logged in to claim a device.',
                              isError: true,
                            );
                            return;
                          }

                          final String panelName = panelNameController.text
                              .trim();
                          final String capacity = capacityController.text
                              .trim();
                          final String nodeId = nodeIdController.text
                              .trim()
                              .toUpperCase();

                          Navigator.pop(context); // Close bottom sheet
                          setState(() {
                            _isConfiguring = true;
                          });

                          try {
                            // 1. Check if the device exists in Firestore `devices` collection
                            final deviceRef = FirebaseFirestore.instance
                                .collection('devices')
                                .doc(nodeId);
                            final docSnap = await deviceRef.get();

                            if (!docSnap.exists) {
                              if (mounted) {
                                _showSnackBar(
                                  context,
                                  'Device ID "$nodeId" not found. Make sure the ESP32 is powered on!',
                                  isError: true,
                                );
                              }
                              return;
                            }

                            final data = docSnap.data();
                            final existingOwner = data?['owner_uid'] ?? '';

                            // 2. Check if device is already claimed by another user
                            if (existingOwner.isNotEmpty &&
                                existingOwner != currentUid) {
                              if (mounted) {
                                _showSnackBar(
                                  context,
                                  'This device is already linked to another account.',
                                  isError: true,
                                );
                              }
                              return;
                            }

                            // 3. Claim device in `devices` collection
                            await deviceRef.set({
                              'owner_uid': currentUid,
                              'device_code': nodeId,
                              'claimed_at': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            // 4. Save linked panel under User's profile (`users/{uid}/panels/{nodeId}`)
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUid)
                                .collection('panels')
                                .doc(nodeId)
                                .set({
                                  'node_id': nodeId,
                                  'name': panelName,
                                  'capacity': double.tryParse(capacity) ?? 0.0,
                                  'linked_at': FieldValue.serverTimestamp(),
                                  'status': 'Online',
                                });

                            if (mounted) {
                              _showSnackBar(
                                context,
                                'Solar Hardware Linked Successfully!',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              _showSnackBar(
                                context,
                                'Error claiming device: $e',
                                isError: true,
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isConfiguring = false;
                              });
                            }
                          }
                        }
                      },
                      child: const Text(
                        'Initialize Telemetry Sync',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w500, color: darkGreen),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: midGreen, size: 22),
        filled: true,
        fillColor: const Color(0xFFF4F7F4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: midGreen, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(
        children: [
          // ==================== 1. GREEN HERO HEADER ====================
          Container(
            width: double.infinity,
            height: 250,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
            decoration: const BoxDecoration(
              color: darkGreen,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
              gradient: LinearGradient(
                colors: [darkGreen, midGreen],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Hardware Setup',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: darkGreen,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ),

          // ==================== 2. OVERLAPPING MAIN CONTENT CARD ====================
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 110),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isConfiguring
                            ? _buildLoadingState()
                            : _buildSetupState(context),
                      ),
                    ),
                  ),
                ),

                // ==================== 3. STICKY BOTTOM BUTTON ====================
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: midGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => _showAddPanelWizard(context),
                      child: const Text(
                        'Add A Setup',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

  // --- FLOATING CARD LOADING STATE ---
  Widget _buildLoadingState() {
    return Container(
      key: const ValueKey('loading'),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              color: midGreen,
              strokeWidth: 3.5,
              strokeCap: StrokeCap.round,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Connecting Node...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Establishing real-time telemetry stream with Firebase Firestore.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // --- MAIN SETUP STATE (DYNAMICALLY STREAMS CLAIMED HARDWARE) ---
  Widget _buildSetupState(BuildContext context) {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      key: const ValueKey('setup'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          'CONNECTED SOLAR PANELS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),

        // Live stream of panels claimed by the logged-in user
        StreamBuilder<QuerySnapshot>(
          stream: currentUid != null
              ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUid)
                    .collection('panels')
                    .snapshots()
              : null,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: midGreen),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    'No hardware linked yet. Tap "Add A Setup" below to claim an ESP32 node.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildPanelNodeTile(
                    id: doc.id,
                    name: data['name'] ?? 'Solar Panel',
                    capacity: '${data['capacity']?.toString() ?? '300'} Watts',
                    nodeId: data['node_id'] ?? doc.id,
                    status: data['status'] ?? 'Online',
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Power on your ESP32 / Arduino node and connect to Wi-Fi before proceeding.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelNodeTile({
    required String id,
    required String name,
    required String capacity,
    required String nodeId,
    String status = 'Online',
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: midGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$nodeId • $capacity',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: midGreen,
            ),
          ),
        ],
      ),
    );
  }
}
