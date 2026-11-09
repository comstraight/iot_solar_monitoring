// ==============================================================================
// initial_setup_screen.dart - Real-Time Firestore Aggregator Onboarding
// ==============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Type definition for document snapshots
typedef SystemDocumentSnapshot = DocumentSnapshot<Map<String, dynamic>>;

/// Centralized UI Colors matching existing application theme
abstract class _AppColors {
  static const Color headerGreen = Color(0xFF10CE2C);
  static const Color buttonGreen = Color(0xFF4CAE50);
  static const Color inputBg = Color(0xFFD5D5D5);
  static const Color darkGreen = Color(0xFF092508);
  static const Color backgroundWhite = Colors.white;
  static final Color whiteTranslucent = Colors.white.withValues(alpha: 0.2);
  static const Color textBlack = Colors.black;
  static const Color textBlack54 = Colors.black54;
  static const Color textBlack87 = Colors.white;
  static const Color textBlack26 = Colors.black26;
  static const Color textBlack45 = Colors.black45;
  static const Color emptyBgGrey = Color(0xFFF3F4F6);
  static const Color errorRed = Colors.red;
  static final Color errorRedShade900 = Colors.red.shade900;
  static const Color greenAccent = Colors.greenAccent;
}

/// Centralized Text Strings
abstract class _AppStrings {
  static const String infoSetupTitle = 'Info Setup Screen';
  static const String connectedSetupTitle = 'Connected Setup';
  static const String noHardwareLinked =
      'No hardware linked to your account yet.';
  static const String addOrangePiButton = 'Add an OrangePi';
  static const String addAggregatorButton = 'Add an aggregator';
  static const String connectToAggregatorTitle = 'Connect to the Orangepi';
  static const String aggregatorFormInstruction =
      'Enter the Aggregator ID and 6-digit passcode shown on the LCD screen.';
  static const String defaultAggregatorPrefix = 'Site ';

  static const String hintAggregatorId =
      'Aggregator Device ID (e.g. OPI_A1B2C3)';
  static const String hintPasscode = '6-Digit Passcode from LCD Screen';
  static const String continueButton = 'Continue';

  static const String valAggregatorId =
      'Please enter your Orange Pi Aggregator ID';
  static const String valPasscode = 'Please enter security passcode';

  static const String errMustBeLoggedIn =
      'You must be logged in to claim an aggregator.';
  static const String errAggregatorNotFoundPrefix = 'Aggregator ID "';
  static const String errAggregatorNotFoundSuffix =
      '" not found. Make sure your Orange Pi is powered on and running.';
  static const String errAggregatorOffline =
      'Orange Pi is currently OFFLINE. Please check power or internet connection.';
  static const String errAggregatorAlreadyLinked =
      'This Orange Pi is already linked to another account.';
  static const String errInvalidPasscode =
      'Invalid Passcode. Please verify the code displayed on your screen.';
  static const String errClaimingPrefix = 'Error claiming aggregator: ';
  static const String errExceptionPrefix = 'Exception: ';
  static const String msgAggregatorLinkedSuccess =
      'Orange Pi Aggregator Linked Successfully!';
}

/// Centralized Layout Dimensions & Defaults
abstract class _AppDimensions {
  static const double fontHeader = 22.0;
  static const double fontTitleLarge = 22.0;
  static const double fontSectionHeader = 18.0;
  static const double fontButtonText = 16.0;
  static const double fontBodyBold = 14.0;
  static const double fontBodyMedium = 13.0;
  static const double fontSubtitle = 12.0;

  static const double buttonHeight = 52.0;
  static const double progressIndicatorSize = 44.0;
  static const double progressStrokeWidth = 3.5;
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
}

/// Centralized Firestore Collections & Fields
abstract class _AppFirestore {
  static const String collectionAggregators = 'aggregators';
  static const String collectionSystemStatus = 'system_status';
  static const String docCurrent = 'current';

  static const String collectionDevices = 'devices';
  static const String collectionUsers = 'users';

  static const String fieldOwnerUid = 'owner_uid';
  static const String fieldAggregatorId = 'aggregator_id';
  static const String fieldAggregatorName = 'aggregator_name';
  static const String fieldDetectedPanels = 'detected_panels';
  static const String fieldStatus = 'status';
  static const String fieldLastSeen = 'last_seen';
  static const String fieldClaimedAt = 'claimed_at';
  static const String fieldPasscode = 'passcode';
  static const String fieldIsClaimed = 'is_claimed';
}

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isConfiguring = false;

  StreamSubscription<User?>? _authSubscription;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _aggregatorsStream;
  String? _currentUid;

  @override
  bool get wantKeepAlive => true;

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
            _aggregatorsStream = FirebaseFirestore.instance
                .collection(_AppFirestore.collectionAggregators)
                .where(_AppFirestore.fieldOwnerUid, isEqualTo: _currentUid)
                .snapshots();
          } else {
            _aggregatorsStream = null;
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

  void _showRenameDialog(String aggId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
          ),
          title: const Text(
            'Rename Site',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter new site name',
              filled: true,
              fillColor: _AppColors.inputBg,
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
                style: TextStyle(color: _AppColors.textBlack54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.buttonGreen,
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
                    await FirebaseFirestore.instance
                        .collection(_AppFirestore.collectionAggregators)
                        .doc(aggId)
                        .update({_AppFirestore.fieldAggregatorName: newName});
                    if (mounted) {
                      _showSnackBar(
                        context,
                        'Site renamed to "$newName" successfully!',
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      _showSnackBar(
                        context,
                        'Error renaming site: $e',
                        isError: true,
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

  void _showDeleteConfirmModal(String aggId, String siteName) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: _AppColors.errorRed),
              SizedBox(width: 8),
              Text(
                'Disconnect Site',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to disconnect "$siteName"?\n\nThis will un-link the Orange Pi setup from your account and revert it to displaying its ID and passcode on the LCD screen.',
            style: const TextStyle(fontSize: 14, color: _AppColors.textBlack87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _AppColors.textBlack54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.errorRed,
                foregroundColor: _AppColors.backgroundWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    _AppDimensions.radiusCard,
                  ),
                ),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  final newPasscode =
                      (100000 +
                              (DateTime.now().millisecondsSinceEpoch % 900000))
                          .toString();
                  await FirebaseFirestore.instance
                      .collection(_AppFirestore.collectionAggregators)
                      .doc(aggId)
                      .update({
                        _AppFirestore.fieldOwnerUid: '',
                        _AppFirestore.fieldIsClaimed: false,
                        _AppFirestore.fieldPasscode: newPasscode,
                      });
                  if (mounted) {
                    _showSnackBar(
                      context,
                      '"$siteName" disconnected successfully.',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    _showSnackBar(
                      context,
                      'Error disconnecting site: $e',
                      isError: true,
                    );
                  }
                }
              },
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );
  }

  void _showAddAggregatorWizard(BuildContext context) {
    if (_currentUid == null) {
      _showSnackBar(context, _AppStrings.errMustBeLoggedIn, isError: true);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _AddAggregatorBottomSheet(
        onSubmitted: (aggregatorId, passcode) async {
          Navigator.pop(modalContext);
          if (!mounted) return;

          setState(() {
            _isConfiguring = true;
          });

          try {
            await FirebaseFirestore.instance.runTransaction((
              transaction,
            ) async {
              final aggRef = FirebaseFirestore.instance
                  .collection(_AppFirestore.collectionAggregators)
                  .doc(aggregatorId);

              final docSnap = await transaction.get(aggRef);

              if (!docSnap.exists) {
                throw Exception(
                  '${_AppStrings.errAggregatorNotFoundPrefix}$aggregatorId${_AppStrings.errAggregatorNotFoundSuffix}',
                );
              }

              final aggData = docSnap.data();
              final existingOwner = aggData?[_AppFirestore.fieldOwnerUid] ?? '';
              final storedPasscode =
                  aggData?[_AppFirestore.fieldPasscode] ?? '';
              final bool isClaimed =
                  aggData?[_AppFirestore.fieldIsClaimed] ?? false;
              final status = aggData?[_AppFirestore.fieldStatus] ?? 'Offline';
              final Timestamp? lastSeen =
                  aggData?[_AppFirestore.fieldLastSeen] as Timestamp?;

              if (existingOwner.toString().isNotEmpty &&
                      existingOwner != _currentUid ||
                  isClaimed) {
                throw Exception(_AppStrings.errAggregatorAlreadyLinked);
              }

              if (storedPasscode.toString().isNotEmpty &&
                  storedPasscode.toString() != passcode) {
                throw Exception(_AppStrings.errInvalidPasscode);
              }

              bool isOnline = status == 'Online';
              if (lastSeen != null) {
                final diffSec = DateTime.now()
                    .difference(lastSeen.toDate())
                    .inSeconds;
                if (diffSec > 120) isOnline = false;
              }

              if (!isOnline) {
                throw Exception(_AppStrings.errAggregatorOffline);
              }

              final userAggsQuery = await FirebaseFirestore.instance
                  .collection(_AppFirestore.collectionAggregators)
                  .where(_AppFirestore.fieldOwnerUid, isEqualTo: _currentUid)
                  .get();

              final siteNumber = userAggsQuery.docs.length + 1;
              final existingName =
                  aggData?[_AppFirestore.fieldAggregatorName] as String?;
              final defaultSiteName =
                  (existingName == null ||
                      existingName.trim().isEmpty ||
                      existingName == 'Orangepi Device')
                  ? '${_AppStrings.defaultAggregatorPrefix}$siteNumber'
                  : existingName;

              transaction.set(aggRef, {
                _AppFirestore.fieldOwnerUid: _currentUid,
                _AppFirestore.fieldIsClaimed: true,
                _AppFirestore.fieldPasscode: '',
                _AppFirestore.fieldAggregatorName: defaultSiteName,
                _AppFirestore.fieldClaimedAt: FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              final userDocRef = FirebaseFirestore.instance
                  .collection(_AppFirestore.collectionUsers)
                  .doc(_currentUid);

              transaction.set(userDocRef, {
                'activeAggregatorId': aggregatorId,
              }, SetOptions(merge: true));
            });

            if (!mounted) return;
            _showSnackBar(context, _AppStrings.msgAggregatorLinkedSuccess);
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
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _aggregatorsStream,
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            final bool hasLinkedDevice = docs.isNotEmpty;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _AppDimensions.spacingLarge,
                    vertical: _AppDimensions.spacingMediumLarge,
                  ),
                  child: Row(
                    children: [
                      if (Navigator.canPop(context))
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
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
                        _AppStrings.infoSetupTitle,
                        style: TextStyle(
                          fontSize: _AppDimensions.fontHeader,
                          fontWeight: FontWeight.bold,
                          color: _AppColors.backgroundWhite,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: _AppColors.backgroundWhite,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(
                          _AppDimensions.radiusCurvedTop,
                        ),
                        topRight: Radius.circular(
                          _AppDimensions.radiusCurvedTop,
                        ),
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
                                duration: const Duration(milliseconds: 350),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: _isConfiguring
                                    ? _buildLoadingState()
                                    : _buildAggregatorListStep(
                                        context,
                                        docs,
                                        snapshot.connectionState,
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(height: _AppDimensions.spacingMedium),

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
                              onPressed: () =>
                                  _showAddAggregatorWizard(context),
                              child: Text(
                                hasLinkedDevice
                                    ? _AppStrings.addAggregatorButton
                                    : _AppStrings.addOrangePiButton,
                                style: const TextStyle(
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
            );
          },
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
        children: const [
          SizedBox(
            width: _AppDimensions.progressIndicatorSize,
            height: _AppDimensions.progressIndicatorSize,
            child: CircularProgressIndicator(
              color: _AppColors.buttonGreen,
              strokeWidth: _AppDimensions.progressStrokeWidth,
              strokeCap: StrokeCap.round,
            ),
          ),
          SizedBox(height: _AppDimensions.spacingLarge),
          Text(
            'Verifying Aggregator...',
            style: TextStyle(
              fontSize: _AppDimensions.fontSectionHeader,
              fontWeight: FontWeight.bold,
              color: _AppColors.textBlack,
            ),
          ),
          SizedBox(height: _AppDimensions.spacingTiny),
          Text(
            'Establishing handshake with Orange Pi site controller.',
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

  Widget _buildAggregatorListStep(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ConnectionState connectionState,
  ) {
    if (connectionState == ConnectionState.waiting && docs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(_AppDimensions.spacingLarge),
          child: CircularProgressIndicator(color: _AppColors.buttonGreen),
        ),
      );
    }

    return Column(
      key: const ValueKey('aggregatorListStep'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: _AppDimensions.spacingTiny),
        const Text(
          _AppStrings.connectedSetupTitle,
          style: TextStyle(
            fontSize: _AppDimensions.fontTitleLarge,
            fontWeight: FontWeight.bold,
            color: _AppColors.textBlack,
          ),
        ),
        const SizedBox(height: _AppDimensions.spacingCurvedPadding),

        if (docs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(_AppDimensions.spacingLarge),
            decoration: BoxDecoration(
              color: _AppColors.emptyBgGrey,
              borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
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
          )
        else
          Column(
            children: docs.asMap().entries.map((entry) {
              final idx = entry.key;
              final claimedDoc = entry.value;
              final aggData = claimedDoc.data();
              final rawName = aggData[_AppFirestore.fieldAggregatorName]
                  ?.toString();
              final aggName =
                  (rawName != null &&
                      rawName.trim().isNotEmpty &&
                      rawName != 'Orangepi Device')
                  ? rawName
                  : '${_AppStrings.defaultAggregatorPrefix}${idx + 1}';
              final aggId =
                  aggData[_AppFirestore.fieldAggregatorId] ?? claimedDoc.id;
              final List<dynamic> detectedPanels =
                  aggData[_AppFirestore.fieldDetectedPanels]
                      as List<dynamic>? ??
                  [];

              return _SwipeableAggregatorCard(
                key: ValueKey<String>('swipe_agg_$aggId'),
                aggId: aggId.toString(),
                name: aggName,
                panelCount: detectedPanels.length,
                onRename: () => _showRenameDialog(aggId.toString(), aggName),
                onDelete: () =>
                    _showDeleteConfirmModal(aggId.toString(), aggName),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _SwipeableAggregatorCard extends StatefulWidget {
  final String aggId;
  final String name;
  final int panelCount;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _SwipeableAggregatorCard({
    super.key,
    required this.aggId,
    required this.name,
    required this.panelCount,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_SwipeableAggregatorCard> createState() =>
      _SwipeableAggregatorCardState();
}

class _SwipeableAggregatorCardState extends State<_SwipeableAggregatorCard> {
  double _dragOffset = 0.0;
  static const double _actionsWidth = 150.0;

  void _close() {
    if (mounted) {
      setState(() {
        _dragOffset = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 76.0,
      margin: const EdgeInsets.only(bottom: _AppDimensions.spacingSmall),
      child: Stack(
        children: [
          // Background Action Buttons
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_AppDimensions.radiusCard),
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
                      width: 75.0,
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2B88D8),
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(8.0),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Rename',
                        style: TextStyle(
                          color: _AppColors.backgroundWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _close();
                      widget.onDelete();
                    },
                    child: Container(
                      width: 75.0,
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        color: _AppColors.errorRed,
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(_AppDimensions.radiusCard),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: _AppColors.backgroundWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Front Card Body
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
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: _AppDimensions.spacingMediumLarge,
                  vertical: _AppDimensions.spacingSmall,
                ),
                decoration: BoxDecoration(
                  color: _AppColors.backgroundWhite,
                  borderRadius: BorderRadius.circular(
                    _AppDimensions.radiusCard,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.panelCount} Panels Connected',
                      style: const TextStyle(
                        fontSize: _AppDimensions.fontSubtitle,
                        color: _AppColors.textBlack54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddAggregatorBottomSheet extends StatefulWidget {
  final Function(String aggregatorId, String passcode) onSubmitted;

  const _AddAggregatorBottomSheet({required this.onSubmitted});

  @override
  State<_AddAggregatorBottomSheet> createState() =>
      _AddAggregatorBottomSheetState();
}

class _AddAggregatorBottomSheetState extends State<_AddAggregatorBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _passcodeController;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController();
    _passcodeController = TextEditingController();
  }

  @override
  void dispose() {
    _idController.dispose();
    _passcodeController.dispose();
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
                  _AppStrings.connectToAggregatorTitle,
                  style: TextStyle(
                    fontSize: _AppDimensions.fontTitleLarge,
                    fontWeight: FontWeight.bold,
                    color: _AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: _AppDimensions.spacingSmall),
                const Text(
                  _AppStrings.aggregatorFormInstruction,
                  style: TextStyle(
                    fontSize: _AppDimensions.fontBodyMedium,
                    color: _AppColors.textBlack54,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: _AppDimensions.spacingCurvedPadding),

                _buildCleanTextField(
                  controller: _idController,
                  hint: _AppStrings.hintAggregatorId,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? _AppStrings.valAggregatorId
                      : null,
                ),
                const SizedBox(height: _AppDimensions.spacingMedium),
                _buildCleanTextField(
                  controller: _passcodeController,
                  hint: _AppStrings.hintPasscode,
                  obscureText: true,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? _AppStrings.valPasscode
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
                          _idController.text.trim(),
                          _passcodeController.text.trim(),
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
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
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
