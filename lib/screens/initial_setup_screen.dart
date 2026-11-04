import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Type definition for document snapshots
typedef SystemDocumentSnapshot = DocumentSnapshot<Map<String, dynamic>>;

/// Centralized UI Colors
abstract class _AppColors {
  static const Color headerGreen = Color(0xFF10CE2C);
  static const Color buttonGreen = Color(0xFF4CAE50);
  static const Color inputBg = Color(0xFFD9D9D9);
  static const Color darkGreen = Color(0xFF092508);
  static const Color backgroundWhite = Colors.white;
  static final Color whiteTranslucent = Colors.white.withValues(alpha: 0.2);
  static const Color textBlack = Colors.black;
  static const Color textBlack54 = Colors.black54;
  static const Color textBlack87 = Colors.black87;
  static const Color textBlack26 = Colors.black26;
  static const Color textBlack45 = Colors.black45;
  static const Color errorRed = Colors.red;
  static final Color errorRedShade900 = Colors.red.shade900;
  static const Color greenAccent = Colors.greenAccent;
}

/// Centralized Text Strings
abstract class _AppStrings {
  static const String hardwareSetupTitle = 'Hardware Setup';
  static const String connectedPanelsTitle = 'Connected Solar Panels';
  static const String addSetupButton = 'Add A Setup';
  static const String connectingNodeTitle = 'Connecting Node...';
  static const String connectingNodeSubtitle =
      'Establishing real-time telemetry stream with Firebase Firestore.';
  static const String noHardwareLinked =
      'No hardware linked yet. Tap "Add A Setup" below to claim a node.';
  static const String setupInstructions =
      'Power on your Orange Pi / Microcontroller node and connect to Wi-Fi before proceeding.';
  static const String defaultPanelName = 'Solar Panel';
  static const String defaultStatusOnline = 'Online';
  static const String unitWatts = 'Watts';

  static const String enterInfoTitle = 'Enter your info.';
  static const String hintPanelIdentifier = 'Panel Identifier';
  static const String hintRatedCapacity = 'Rated Max Capacity (Watts)';
  static const String hintNodeId = 'Microcontroller Node ID';
  static const String continueButton = 'Continue';

  static const String valPanelName = 'Please give your panel a name';
  static const String valCapacity = 'Enter rated wattage';
  static const String valNodeId = 'Enter hardware Device ID';

  static const String errMustBeLoggedIn =
      'You must be logged in to claim a device.';
  static const String errDeviceNotFoundPrefix = 'Device ID "';
  static const String errDeviceNotFoundSuffix =
      '" not found. Make sure your Orange Pi / Microcontroller is powered on and configured.';
  static const String errDeviceAlreadyLinked =
      'This device is already linked to another account.';
  static const String errClaimingPrefix = 'Error claiming device: ';
  static const String errExceptionPrefix = 'Exception: ';
  static const String msgHardwareLinkedSuccess =
      'Solar Hardware Linked Successfully!';
}

/// Centralized Layout Dimensions & Numeric Defaults
abstract class _AppDimensions {
  static const double fontHeader = 24.0;
  static const double fontTitleLarge = 22.0;
  static const double fontSectionHeader = 18.0;
  static const double fontButtonText = 16.0;
  static const double fontBodyBold = 14.0;
  static const double fontBodyMedium = 13.0;
  static const double fontSubtitle = 12.0;

  static const double buttonHeight = 52.0;
  static const double progressIndicatorSize = 44.0;
  static const double progressStrokeWidth = 3.5;
  static const double statusDotSize = 10.0;
  static const double handleWidth = 40.0;
  static const double handleHeight = 4.0;

  static const double radiusCurvedTop = 36.0;
  static const double radiusSnackBar = 16.0;
  static const double radiusCard = 12.0;
  static const double radiusHandle = 10.0;

  static const double spacingExtraLarge = 32.0;
  static const double spacingCurvedPadding = 28.0;
  static const double spacingLarge = 24.0;
  static const double spacingMediumLarge = 20.0;
  static const double spacingMedium = 16.0;
  static const double spacingStandard = 14.0;
  static const double spacingSmall = 12.0;
  static const double spacingTiny = 8.0;
  static const double spacingMicro = 2.0;

  static const double defaultCapacityWatts = 300.0;
  static const int defaultPanelOrder = 0;
}

/// Centralized Firestore Collection Names & Field Constants
abstract class _AppFirestore {
  static const String collectionSystemStatus = 'system_status';
  static const String docCurrent = 'current';

  static const String collectionDevices = 'devices';
  static const String collectionUsers = 'users';
  static const String subCollectionPanels = 'panels';

  static const String fieldOwnerUid = 'owner_uid';
  static const String fieldOwnerUidCamel = 'ownerUid';
  static const String fieldDeviceCode = 'device_code';
  static const String fieldClaimedAt = 'claimed_at';
  static const String fieldDefaultPanelId = 'defaultPanelId';
  static const String fieldPairedDevices = 'pairedDevices';

  static const String fieldNodeId = 'node_id';
  static const String fieldName = 'name';
  static const String fieldCapacity = 'capacity';
  static const String fieldLinkedAt = 'linked_at';
  static const String fieldStatus = 'status';

  static const String fieldPanels = 'panels';
  static const String fieldPanelId = 'panel_id';
  static const String fieldPanelName = 'panel_name';
  static const String fieldGroup = 'group';
  static const String fieldPanelOrder = 'panel_order';
  static const String fieldMetadata = 'metadata';
  static const String fieldRatedPowerW = 'rated_power_w';
}

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isConfiguring = false;

  // Cached Stream Instance & Auth Subscription
  Stream<SystemDocumentSnapshot>? _panelsStream;
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
                .collection(_AppFirestore.collectionSystemStatus)
                .doc(_AppFirestore.docCurrent)
                .snapshots(includeMetadataChanges: false);
          } else {
            _panelsStream = null;
          }
        });
      }
    });
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? _AppColors.errorRedShade900
            : _AppColors.darkGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_AppDimensions.radiusSnackBar),
        ),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: isError
                  ? _AppColors.backgroundWhite
                  : _AppColors.greenAccent,
            ),
            const SizedBox(width: _AppDimensions.spacingSmall),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _AppColors.backgroundWhite,
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
      _showSnackBar(context, _AppStrings.errMustBeLoggedIn, isError: true);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _AddPanelBottomSheet(
        onSubmitted: (panelName, capacity, nodeId) async {
          Navigator.pop(modalContext);
          if (!mounted) return;

          setState(() {
            _isConfiguring = true;
          });

          try {
            await FirebaseFirestore.instance.runTransaction((
              transaction,
            ) async {
              final deviceRef = FirebaseFirestore.instance
                  .collection(_AppFirestore.collectionDevices)
                  .doc(nodeId);

              final docSnap = await transaction.get(deviceRef);

              if (!docSnap.exists) {
                throw Exception(
                  '${_AppStrings.errDeviceNotFoundPrefix}$nodeId${_AppStrings.errDeviceNotFoundSuffix}',
                );
              }

              final data = docSnap.data();
              final existingOwner =
                  data?[_AppFirestore.fieldOwnerUid] ??
                  data?[_AppFirestore.fieldOwnerUidCamel] ??
                  '';

              if (existingOwner.toString().isNotEmpty &&
                  existingOwner != _currentUid) {
                throw Exception(_AppStrings.errDeviceAlreadyLinked);
              }

              final double parsedCapacity =
                  double.tryParse(capacity) ??
                  _AppDimensions.defaultCapacityWatts;

              // 1. Claim device in global devices collection
              transaction.set(deviceRef, {
                _AppFirestore.fieldOwnerUid: _currentUid,
                _AppFirestore.fieldDeviceCode: nodeId,
                _AppFirestore.fieldClaimedAt: FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              // 2. Update user root document with defaultPanelId and array of paired devices
              final userDocRef = FirebaseFirestore.instance
                  .collection(_AppFirestore.collectionUsers)
                  .doc(_currentUid);

              transaction.set(userDocRef, {
                _AppFirestore.fieldDefaultPanelId: nodeId,
                _AppFirestore.fieldPairedDevices: FieldValue.arrayUnion([
                  nodeId,
                ]),
              }, SetOptions(merge: true));

              // 3. Save linked panel details under user profile subcollection
              final userPanelRef = userDocRef
                  .collection(_AppFirestore.subCollectionPanels)
                  .doc(nodeId);

              transaction.set(userPanelRef, {
                _AppFirestore.fieldNodeId: nodeId,
                _AppFirestore.fieldName: panelName,
                _AppFirestore.fieldCapacity: parsedCapacity,
                _AppFirestore.fieldLinkedAt: FieldValue.serverTimestamp(),
                _AppFirestore.fieldStatus: _AppStrings.defaultStatusOnline,
              });

              // 4. Register panel in system_status/current for live telemetry updates
              final statusRef = FirebaseFirestore.instance
                  .collection(_AppFirestore.collectionSystemStatus)
                  .doc(_AppFirestore.docCurrent);

              transaction.set(statusRef, {
                _AppFirestore.fieldPanels: {
                  nodeId: {
                    _AppFirestore.fieldPanelId: nodeId,
                    _AppFirestore.fieldPanelName: panelName,
                    _AppFirestore.fieldOwnerUid: _currentUid,
                    _AppFirestore.fieldGroup: null,
                    _AppFirestore.fieldPanelOrder:
                        _AppDimensions.defaultPanelOrder,
                    _AppFirestore.fieldMetadata: {
                      _AppFirestore.fieldRatedPowerW: parsedCapacity,
                    },
                  },
                },
              }, SetOptions(merge: true));
            });

            if (!mounted) return;
            _showSnackBar(context, _AppStrings.msgHardwareLinkedSuccess);
          } catch (e) {
            if (!mounted) return;
            final errorMsg = e is Exception
                ? e.toString().replaceAll(_AppStrings.errExceptionPrefix, '')
                : '${_AppStrings.errClaimingPrefix}$e';

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
    super.build(context);
    return Scaffold(
      backgroundColor: _AppColors.headerGreen,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ==================== 1. GREEN HEADER ====================
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _AppDimensions.spacingLarge,
                vertical: _AppDimensions.spacingMediumLarge,
              ),
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        margin: const EdgeInsets.only(
                          right: _AppDimensions.spacingSmall,
                        ),
                        padding: const EdgeInsets.all(
                          _AppDimensions.spacingTiny,
                        ),
                        decoration: BoxDecoration(
                          color: _AppColors.whiteTranslucent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: _AppColors.backgroundWhite,
                          size: 20,
                        ),
                      ),
                    ),
                  const Text(
                    _AppStrings.hardwareSetupTitle,
                    style: TextStyle(
                      fontSize: _AppDimensions.fontHeader,
                      fontWeight: FontWeight.bold,
                      color: _AppColors.backgroundWhite,
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
                  color: _AppColors.backgroundWhite,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(_AppDimensions.radiusCurvedTop),
                    topRight: Radius.circular(_AppDimensions.radiusCurvedTop),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(
                    _AppDimensions.spacingCurvedPadding,
                  ),
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

                      const SizedBox(height: _AppDimensions.spacingMedium),

                      // ==================== 3. ACTION BUTTON ====================
                      SizedBox(
                        width: double.infinity,
                        height: _AppDimensions.buttonHeight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _AppColors.buttonGreen,
                            foregroundColor: _AppColors.backgroundWhite,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                _AppDimensions.radiusCard,
                              ),
                            ),
                          ),
                          onPressed: () => _showAddPanelWizard(context),
                          child: const Text(
                            _AppStrings.addSetupButton,
                            style: TextStyle(
                              fontSize: _AppDimensions.fontButtonText,
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

  Widget _buildLoadingState() {
    return Container(
      key: const ValueKey('loading'),
      padding: const EdgeInsets.all(_AppDimensions.spacingExtraLarge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: _AppDimensions.progressIndicatorSize,
            height: _AppDimensions.progressIndicatorSize,
            child: CircularProgressIndicator(
              color: _AppColors.buttonGreen,
              strokeWidth: _AppDimensions.progressStrokeWidth,
              strokeCap: StrokeCap.round,
            ),
          ),
          const SizedBox(height: _AppDimensions.spacingLarge),
          const Text(
            _AppStrings.connectingNodeTitle,
            style: TextStyle(
              fontSize: _AppDimensions.fontSectionHeader,
              fontWeight: FontWeight.bold,
              color: _AppColors.textBlack,
            ),
          ),
          const SizedBox(height: _AppDimensions.spacingTiny),
          const Text(
            _AppStrings.connectingNodeSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _AppDimensions.fontBodyMedium,
              color: _AppColors.textBlack54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupState(BuildContext context) {
    return Column(
      key: const ValueKey('setup'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: _AppDimensions.spacingTiny),
        const Text(
          _AppStrings.connectedPanelsTitle,
          style: TextStyle(
            fontSize: _AppDimensions.fontTitleLarge,
            fontWeight: FontWeight.bold,
            color: _AppColors.textBlack,
          ),
        ),
        const SizedBox(height: _AppDimensions.spacingCurvedPadding),

        StreamBuilder<SystemDocumentSnapshot>(
          stream: _panelsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(_AppDimensions.spacingLarge),
                  child: CircularProgressIndicator(
                    color: _AppColors.buttonGreen,
                  ),
                ),
              );
            }

            final statusData = snapshot.data?.data() ?? {};
            final panelsMap =
                statusData[_AppFirestore.fieldPanels]
                    as Map<String, dynamic>? ??
                {};

            if (panelsMap.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(
                  _AppDimensions.spacingMediumLarge,
                ),
                margin: const EdgeInsets.only(
                  bottom: _AppDimensions.spacingMedium,
                ),
                decoration: BoxDecoration(
                  color: _AppColors.inputBg,
                  borderRadius: BorderRadius.circular(
                    _AppDimensions.radiusCard,
                  ),
                ),
                child: const Center(
                  child: Text(
                    _AppStrings.noHardwareLinked,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: _AppDimensions.fontBodyMedium,
                      color: _AppColors.textBlack54,
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
                    pData[_AppFirestore.fieldPanelName] ??
                    pData[_AppFirestore.fieldName] ??
                    _AppStrings.defaultPanelName;
                final pCapacity =
                    pData[_AppFirestore.fieldMetadata]?[_AppFirestore
                            .fieldRatedPowerW]
                        ?.toString() ??
                    _AppDimensions.defaultCapacityWatts.toInt().toString();

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: _AppDimensions.spacingSmall,
                  ),
                  child: _buildPanelNodeTile(
                    id: pId,
                    name: pName,
                    capacity: '$pCapacity ${_AppStrings.unitWatts}',
                    nodeId: pId,
                    status: _AppStrings.defaultStatusOnline,
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: _AppDimensions.spacingSmall),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(_AppDimensions.spacingMedium),
          decoration: BoxDecoration(
            color: _AppColors.inputBg,
            borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
          ),
          child: const Text(
            _AppStrings.setupInstructions,
            style: TextStyle(
              fontSize: _AppDimensions.fontBodyMedium,
              color: _AppColors.textBlack87,
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
    String status = _AppStrings.defaultStatusOnline,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _AppDimensions.spacingMediumLarge,
        vertical: _AppDimensions.spacingMedium,
      ),
      decoration: BoxDecoration(
        color: _AppColors.inputBg,
        borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
      ),
      child: Row(
        children: [
          Container(
            width: _AppDimensions.statusDotSize,
            height: _AppDimensions.statusDotSize,
            decoration: const BoxDecoration(
              color: _AppColors.buttonGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: _AppDimensions.spacingStandard),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: _AppDimensions.fontBodyBold,
                    fontWeight: FontWeight.bold,
                    color: _AppColors.textBlack87,
                  ),
                ),
                const SizedBox(height: _AppDimensions.spacingMicro),
                Text(
                  '$nodeId • $capacity',
                  style: const TextStyle(
                    fontSize: _AppDimensions.fontSubtitle,
                    color: _AppColors.textBlack54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: const TextStyle(
              fontSize: _AppDimensions.fontBodyMedium,
              fontWeight: FontWeight.bold,
              color: _AppColors.buttonGreen,
            ),
          ),
        ],
      ),
    );
  }
}

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
          color: _AppColors.backgroundWhite,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(_AppDimensions.radiusCurvedTop),
          ),
        ),
        padding: const EdgeInsets.all(_AppDimensions.spacingCurvedPadding),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: _AppDimensions.handleWidth,
                    height: _AppDimensions.handleHeight,
                    margin: const EdgeInsets.only(
                      bottom: _AppDimensions.spacingMediumLarge,
                    ),
                    decoration: BoxDecoration(
                      color: _AppColors.textBlack26,
                      borderRadius: BorderRadius.circular(
                        _AppDimensions.radiusHandle,
                      ),
                    ),
                  ),
                ),
                const Text(
                  _AppStrings.enterInfoTitle,
                  style: TextStyle(
                    fontSize: _AppDimensions.fontTitleLarge,
                    fontWeight: FontWeight.bold,
                    color: _AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: _AppDimensions.spacingCurvedPadding),

                _buildCleanTextField(
                  controller: _panelNameController,
                  hint: _AppStrings.hintPanelIdentifier,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? _AppStrings.valPanelName
                      : null,
                ),
                const SizedBox(height: _AppDimensions.spacingMedium),
                _buildCleanTextField(
                  controller: _capacityController,
                  hint: _AppStrings.hintRatedCapacity,
                  keyboardType: TextInputType.number,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? _AppStrings.valCapacity
                      : null,
                ),
                const SizedBox(height: _AppDimensions.spacingMedium),
                _buildCleanTextField(
                  controller: _nodeIdController,
                  hint: _AppStrings.hintNodeId,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? _AppStrings.valNodeId
                      : null,
                ),

                const SizedBox(height: _AppDimensions.spacingExtraLarge),

                SizedBox(
                  width: double.infinity,
                  height: _AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AppColors.buttonGreen,
                      foregroundColor: _AppColors.backgroundWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          _AppDimensions.radiusCard,
                        ),
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
                      _AppStrings.continueButton,
                      style: TextStyle(
                        fontSize: _AppDimensions.fontButtonText,
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
        color: _AppColors.textBlack87,
        fontSize: _AppDimensions.fontBodyBold,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: _AppColors.textBlack45,
          fontSize: _AppDimensions.fontBodyBold,
        ),
        filled: true,
        fillColor: _AppColors.inputBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: _AppDimensions.spacingMediumLarge,
          vertical: _AppDimensions.spacingMedium,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
          borderSide: const BorderSide(
            color: _AppColors.buttonGreen,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
          borderSide: const BorderSide(color: _AppColors.errorRed, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
          borderSide: const BorderSide(color: _AppColors.errorRed, width: 1.5),
        ),
      ),
    );
  }
}
