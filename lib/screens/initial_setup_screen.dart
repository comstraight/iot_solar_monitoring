import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen>
    with AutomaticKeepAliveClientMixin {
  // Theme Color Constants (Aligned with modern design system)
  static const Color headerGreen = Color(0xFF10CE2C);
  static const Color buttonGreen = Color(0xFF4CAE50);
  static const Color inputBg = Color(0xFFD9D9D9);
  static const Color darkGreen = Color(0xFF092508);
  static const Color cardBg = Colors.white;

  bool _isConfiguring = false;

  // Cached Stream Instance & Auth Subscription
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _panelsStream;
  StreamSubscription<User?>? _authSubscription;
  String? _currentUid;

  @override
  bool get wantKeepAlive => true; // Prevents state disposal when navigating

  @override
  void initState() {
    super.initState();
    _listenToAuthAndInitStream();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _listenToAuthAndInitStream() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user?.uid != _currentUid) {
        setState(() {
          _currentUid = user?.uid;
          if (_currentUid != null) {
            _panelsStream = FirebaseFirestore.instance
                .collection('system_status')
                .doc('current')
                .snapshots(includeMetadataChanges: false);
          } else {
            _panelsStream = null;
          }
        });
      }
    });
  }

  // Helper SnackBar for visual feedback
  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade900 : darkGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    if (_currentUid == null) {
      _showSnackBar(
        context,
        'You must be logged in to claim a device.',
        isError: true,
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _AddPanelBottomSheet(
        onSubmitted: (panelName, capacity, nodeId) async {
          Navigator.pop(modalContext); // Close bottom sheet
          if (!mounted) return;

          setState(() {
            _isConfiguring = true;
          });

          try {
            // Firestore Transaction ensures atomic read-and-write operation
            await FirebaseFirestore.instance.runTransaction((
              transaction,
            ) async {
              final deviceRef = FirebaseFirestore.instance
                  .collection('devices')
                  .doc(nodeId);

              final docSnap = await transaction.get(deviceRef);

              if (!docSnap.exists) {
                throw Exception(
                  'Device ID "$nodeId" not found. Make sure the ESP32 is powered on!',
                );
              }

              final data = docSnap.data();
              final existingOwner = data?['owner_uid'] ?? '';

              if (existingOwner.toString().isNotEmpty &&
                  existingOwner != _currentUid) {
                throw Exception(
                  'This device is already linked to another account.',
                );
              }

              // 1. Claim device in global devices collection
              transaction.set(deviceRef, {
                'owner_uid': _currentUid,
                'device_code': nodeId,
                'claimed_at': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              // 2. Save linked panel under user profile
              final userPanelRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(_currentUid)
                  .collection('panels')
                  .doc(nodeId);

              transaction.set(userPanelRef, {
                'node_id': nodeId,
                'name': panelName,
                'capacity': double.tryParse(capacity) ?? 0.0,
                'linked_at': FieldValue.serverTimestamp(),
                'status': 'Online',
              });

              // 3. Register panel in system_status/current so server.py accepts telemetry
              final statusRef = FirebaseFirestore.instance
                  .collection('system_status')
                  .doc('current');

              transaction.set(statusRef, {
                'panels': {
                  nodeId: {
                    'panel_id': nodeId,
                    'panel_name': panelName,
                    'group': null,
                    'panel_order': 0,
                    'metadata': {
                      'rated_power_w': double.tryParse(capacity) ?? 300.0,
                    },
                  },
                },
              }, SetOptions(merge: true));
            });

            if (!mounted) return;
            _showSnackBar(context, 'Solar Hardware Linked Successfully!');
          } catch (e) {
            if (!mounted) return;
            final errorMsg = e is Exception
                ? e.toString().replaceAll('Exception: ', '')
                : 'Error claiming device: $e';

            _showSnackBar(context, errorMsg, isError: true);
          } finally {
            if (mounted) {
              setState(() {
                _isConfiguring = false;
              });
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: headerGreen,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ==================== 1. GREEN HEADER ====================
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  const Text(
                    'Hardware Setup',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // ==================== 2. WHITE CURVED BODY CONTAINER ====================
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _isConfiguring
                                ? _buildLoadingState()
                                : _buildSetupState(context),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==================== 3. ACTION BUTTON ====================
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
              color: buttonGreen,
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
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Establishing real-time telemetry stream with Firebase Firestore.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // --- MAIN SETUP STATE ---
  Widget _buildSetupState(BuildContext context) {
    return Column(
      key: const ValueKey('setup'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Connected Solar Panels',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 28),

        // Cached stream builder reference
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _panelsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: buttonGreen),
                ),
              );
            }

            final statusData = snapshot.data?.data() ?? {};
            final panelsMap =
                statusData['panels'] as Map<String, dynamic>? ?? {};

            if (panelsMap.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No hardware linked yet. Tap "Add A Setup" below to claim an ESP32 node.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: panelsMap.entries.map((entry) {
                final pId = entry.key;
                final pData = entry.value as Map<String, dynamic>? ?? {};
                final pName =
                    pData['panel_name'] ?? pData['name'] ?? 'Solar Panel';
                final pCapacity =
                    pData['metadata']?['rated_power_w']?.toString() ?? '300';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPanelNodeTile(
                    id: pId,
                    name: pName,
                    capacity: '$pCapacity Watts',
                    nodeId: pId,
                    status: 'Online',
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Power on your ESP32 / Arduino node and connect to Wi-Fi before proceeding.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: buttonGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$nodeId • $capacity',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: buttonGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone StatefulWidget for Modal Bottom Sheet to manage controller lifecycles safely
class _AddPanelBottomSheet extends StatefulWidget {
  final Function(String panelName, String capacity, String nodeId) onSubmitted;

  const _AddPanelBottomSheet({required this.onSubmitted});

  @override
  State<_AddPanelBottomSheet> createState() => _AddPanelBottomSheetState();
}

class _AddPanelBottomSheetState extends State<_AddPanelBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _panelNameController;
  late final TextEditingController _capacityController;
  late final TextEditingController _nodeIdController;

  static const Color buttonGreen = Color(0xFF4CAE50);
  static const Color inputBg = Color(0xFFD9D9D9);

  @override
  void initState() {
    super.initState();
    _panelNameController = TextEditingController();
    _capacityController = TextEditingController();
    _nodeIdController = TextEditingController();
  }

  @override
  void dispose() {
    _panelNameController.dispose();
    _capacityController.dispose();
    _nodeIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        padding: const EdgeInsets.all(28.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const Text(
                  'Enter your info.',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 28),

                _buildCleanTextField(
                  controller: _panelNameController,
                  hint: 'Panel Identifier',
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Please give your panel a name'
                      : null,
                ),
                const SizedBox(height: 16),
                _buildCleanTextField(
                  controller: _capacityController,
                  hint: 'Rated Max Capacity (Watts)',
                  keyboardType: TextInputType.number,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Enter rated wattage'
                      : null,
                ),
                const SizedBox(height: 16),
                _buildCleanTextField(
                  controller: _nodeIdController,
                  hint: 'Microcontroller Node ID',
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Enter hardware Device ID'
                      : null,
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        widget.onSubmitted(
                          _panelNameController.text.trim(),
                          _capacityController.text.trim(),
                          _nodeIdController.text.trim().toUpperCase(),
                        );
                      }
                    },
                    child: const Text(
                      'Continue',
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
    );
  }

  Widget _buildCleanTextField({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontWeight: FontWeight.w500,
        color: Colors.black87,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: buttonGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
} 