import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'monitoring_screen.dart';

enum NotificationType {
  info, // Green: Updates, Patches, TOS, General Reminders
  warning, // Yellow: Degradation, dust, shading, high temp
  critical, // Red: Fires, Sensor failure, wiring failure
}

class NotificationItem {
  final String id;
  final String senderName;
  final String senderEmail;
  final String title;
  final String message;
  final String timestamp;
  final NotificationType type;
  final String category;
  final String? panelId;
  final String targetUid;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.senderName,
    required this.senderEmail,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.category = NotificationScreen.defaultCategory,
    this.panelId,
    this.targetUid = NotificationScreen.targetAll,
    this.isRead = false,
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    NotificationType parsedType = NotificationType.info;
    final typeStr =
        data[NotificationScreen.fieldType]?.toString().toLowerCase() ??
        NotificationScreen.typeInfoStr;
    if (typeStr == NotificationScreen.typeCriticalStr) {
      parsedType = NotificationType.critical;
    } else if (typeStr == NotificationScreen.typeWarningStr) {
      parsedType = NotificationType.warning;
    }

    String formattedTime = NotificationScreen.labelJustNow;
    final createdAt = data[NotificationScreen.fieldCreatedAt];
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) {
        formattedTime = NotificationScreen.labelJustNow;
      } else if (diff.inHours < 1) {
        formattedTime =
            '${diff.inMinutes}${NotificationScreen.suffixMinutesAgo}';
      } else if (diff.inDays < 1) {
        formattedTime = '${diff.inHours}${NotificationScreen.suffixHoursAgo}';
      } else {
        formattedTime = '${diff.inDays}${NotificationScreen.suffixDaysAgo}';
      }
    } else if (data[NotificationScreen.fieldTimestamp] != null) {
      formattedTime = data[NotificationScreen.fieldTimestamp].toString();
    }

    return NotificationItem(
      id: doc.id,
      senderName:
          data[NotificationScreen.fieldSenderName] ??
          NotificationScreen.defaultSenderName,
      senderEmail:
          data[NotificationScreen.fieldSenderEmail] ??
          NotificationScreen.defaultSenderEmail,
      title:
          data[NotificationScreen.fieldTitle] ??
          NotificationScreen.defaultTitle,
      message: data[NotificationScreen.fieldMessage] ?? '',
      timestamp: formattedTime,
      type: parsedType,
      category:
          data[NotificationScreen.fieldCategory] ??
          NotificationScreen.defaultCategorySystem,
      panelId: data[NotificationScreen.fieldPanelId],
      targetUid:
          data[NotificationScreen.fieldTargetUid] ??
          NotificationScreen.targetAll,
      isRead: data[NotificationScreen.fieldIsRead] ?? false,
    );
  }
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  // Theme & Styling Colors
  static const Color pageBg = Color(0xFFF8FAF8);
  static const Color colorCritical = Color(0xFFDC2626);
  static const Color colorWarning = Color(0xFFD97706);
  static const Color colorInfo = Color(0xFF16A34A);
  static const Color colorPrimaryGreen = Color(0xFF20831B);
  static const Color colorInspectButtonBg = Color(0xFF092508);
  static const Color colorSenderBg = Color(0xFFF4F6F4);
  static const Color colorDismissBg = Color(0xFFFEE2E2);
  static const Color colorEmptyCircleBg = Color(0xFFF0FDF4);
  static const Color colorModalHandle = Color(0xFFE0E0E0);

  // Firestore Collection & Field Constants
  static const String colNotifications = 'notifications';
  static const String fieldTargetUid = 'targetUid';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldTimestamp = 'timestamp';
  static const String fieldType = 'type';
  static const String fieldCategory = 'category';
  static const String fieldSenderName = 'senderName';
  static const String fieldSenderEmail = 'senderEmail';
  static const String fieldTitle = 'title';
  static const String fieldMessage = 'message';
  static const String fieldPanelId = 'panelId';
  static const String fieldIsRead = 'isRead';
  static const String targetAll = 'all';

  // Type & Option Strings
  static const String typeCriticalStr = 'critical';
  static const String typeWarningStr = 'warning';
  static const String typeInfoStr = 'info';

  // Fallback & Relative Time Strings
  static const String labelJustNow = 'Just now';
  static const String suffixMinutesAgo = 'm ago';
  static const String suffixHoursAgo = 'h ago';
  static const String suffixDaysAgo = 'd ago';
  static const String defaultSenderName = 'System Monitor';
  static const String defaultSenderEmail = 'no-reply@solarcontrol.com';
  static const String defaultTitle = 'Notice';
  static const String defaultCategory = 'General';
  static const String defaultCategorySystem = 'System';
  static const String defaultAvatarLetter = 'S';

  // UI Text & Button Labels
  static const String badgeCriticalLabel = 'CRITICAL SYSTEM ALERT';
  static const String badgeWarningLabel = 'WARNING';
  static const String badgeAnnouncementLabel = 'ANNOUNCEMENT';
  static const String titleScreen = 'Notifications';
  static const String btnReadAll = 'Read All';
  static const String btnInspectHardware = 'Inspect Affected Panel Hardware';
  static const String btnCloseMessage = 'Close Message';
  static const String titleEmptyState = 'All Caught Up!';
  static const String msgEmptyState = 'You have no new notifications.';
  static const String fromEmailPrefix = 'From: <';
  static const String fromEmailSuffix = '>';

  // Layout & Pagination Parameters
  static const int pageSize = 20;
  static const double scrollThresholdPx = 200.0;
  static const int loadMoreDelayMs = 300;
  static const double modalHeightFraction = 0.75;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentLimit = NotificationScreen.pageSize;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent -
                NotificationScreen.scrollThresholdPx &&
        !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
        _currentLimit += NotificationScreen.pageSize;
      });
      Future.delayed(
        const Duration(milliseconds: NotificationScreen.loadMoreDelayMs),
        () {
          if (mounted) {
            setState(() {
              _isLoadingMore = false;
            });
          }
        },
      );
    }
  }

  Future<void> _markAllAsRead(List<NotificationItem> notifications) async {
    final unreadItems = notifications.where((n) => !n.isRead).toList();
    if (unreadItems.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (var item in unreadItems) {
      final docRef = FirebaseFirestore.instance
          .collection(NotificationScreen.colNotifications)
          .doc(item.id);
      batch.update(docRef, {NotificationScreen.fieldIsRead: true});
    }

    try {
      await batch.commit();
    } catch (_) {}
  }

  Future<void> _updateReadStatusInFirestore(String id, bool isRead) async {
    try {
      await FirebaseFirestore.instance
          .collection(NotificationScreen.colNotifications)
          .doc(id)
          .update({NotificationScreen.fieldIsRead: isRead});
    } catch (_) {}
  }

  Future<void> _removeItem(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection(NotificationScreen.colNotifications)
          .doc(id)
          .delete();
    } catch (_) {}
  }

  void _openEmailReaderSheet(NotificationItem item) {
    if (!item.isRead) {
      _updateReadStatusInFirestore(item.id, true);
    }

    final Color badgeColor;
    final String badgeLabel;

    switch (item.type) {
      case NotificationType.critical:
        badgeColor = NotificationScreen.colorCritical;
        badgeLabel = NotificationScreen.badgeCriticalLabel;
        break;
      case NotificationType.warning:
        badgeColor = NotificationScreen.colorWarning;
        badgeLabel = NotificationScreen.badgeWarningLabel;
        break;
      case NotificationType.info:
        badgeColor = NotificationScreen.colorInfo;
        badgeLabel = NotificationScreen.badgeAnnouncementLabel;
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        height:
            MediaQuery.of(modalContext).size.height *
            NotificationScreen.modalHeightFraction,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: NotificationScreen.colorModalHandle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.category.toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  item.timestamp,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NotificationScreen.colorSenderBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: badgeColor,
                    radius: 18,
                    child: Text(
                      item.senderName.isNotEmpty
                          ? item.senderName[0].toUpperCase()
                          : NotificationScreen.defaultAvatarLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.senderName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '${NotificationScreen.fromEmailPrefix}${item.senderEmail}${NotificationScreen.fromEmailSuffix}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  item.message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            if (item.panelId != null && item.panelId!.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NotificationScreen.colorInspectButtonBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(
                    CupertinoIcons.graph_circle,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    NotificationScreen.btnInspectHardware,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    final nav = Navigator.of(modalContext);
                    nav.pop();
                    nav.push(
                      MaterialPageRoute(
                        builder: (context) =>
                            MonitoringScreen(panelId: item.panelId!),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: NotificationScreen.colorPrimaryGreen,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(modalContext),
                child: const Text(
                  NotificationScreen.btnCloseMessage,
                  style: TextStyle(
                    color: NotificationScreen.colorPrimaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final List<String> targetUids = [NotificationScreen.targetAll];
    if (currentUser != null) {
      targetUids.add(currentUser.uid);
    }

    return Scaffold(
      backgroundColor: NotificationScreen.pageBg,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(NotificationScreen.colNotifications)
            .where(NotificationScreen.fieldTargetUid, whereIn: targetUids)
            .orderBy(NotificationScreen.fieldCreatedAt, descending: true)
            .limit(_currentLimit)
            .snapshots(includeMetadataChanges: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: NotificationScreen.colorPrimaryGreen,
              ),
            );
          }

          final rawDocs = snapshot.data?.docs ?? [];
          final notifications = rawDocs
              .map((doc) => NotificationItem.fromFirestore(doc))
              .toList();

          final int unreadCount = notifications.where((n) => !n.isRead).length;

          return Scaffold(
            backgroundColor: NotificationScreen.pageBg,
            appBar: _buildAppBar(context, unreadCount, notifications),
            body: notifications.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: notifications.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == notifications.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: NotificationScreen.colorPrimaryGreen,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        );
                      }

                      final item = notifications[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _removeItem(item.id),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: NotificationScreen.colorDismissBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            CupertinoIcons.trash,
                            color: NotificationScreen.colorCritical,
                            size: 22,
                          ),
                        ),
                        child: _buildNotificationCard(item),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    int unreadCount,
    List<NotificationItem> notifications,
  ) {
    return AppBar(
      backgroundColor: NotificationScreen.pageBg,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            NotificationScreen.titleScreen,
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: NotificationScreen.colorPrimaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (unreadCount > 0)
          TextButton(
            onPressed: () => _markAllAsRead(notifications),
            child: const Text(
              NotificationScreen.btnReadAll,
              style: TextStyle(
                color: NotificationScreen.colorPrimaryGreen,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    final Color iconColor;
    final IconData iconData;

    switch (item.type) {
      case NotificationType.critical:
        iconColor = NotificationScreen.colorCritical;
        iconData = CupertinoIcons.exclamationmark_triangle_fill;
        break;
      case NotificationType.warning:
        iconColor = NotificationScreen.colorWarning;
        iconData = CupertinoIcons.bolt_horizontal_circle_fill;
        break;
      case NotificationType.info:
        iconColor = NotificationScreen.colorInfo;
        iconData = CupertinoIcons.info_circle_fill;
        break;
    }

    return GestureDetector(
      onTap: () => _openEmailReaderSheet(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.senderName} (${item.senderEmail})',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: item.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.timestamp,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: item.isRead
                          ? Colors.grey.shade600
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: NotificationScreen.colorEmptyCircleBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.bell_slash,
              size: 40,
              color: NotificationScreen.colorInfo,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            NotificationScreen.titleEmptyState,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            NotificationScreen.msgEmptyState,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
