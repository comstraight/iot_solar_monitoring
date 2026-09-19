import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../screens/home_screen.dart';

enum NotificationType {
  info, // Green: Updates, TOS, General Reminders
  warning, // Yellow: Degradation prevention (dust, shading, cleaning)
  critical, // Red: Fires, Sensor nonfunctional/wiring failures
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String timestamp;
  final NotificationType type;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
  });
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const Color pageBg = Color(0xFFF8FAF8);

  // Initialized Dataset for the 3 Categories
  final List<NotificationItem> _notifications = [
    // 1. CRITICAL (RED)
    NotificationItem(
      id: 'n1',
      title: 'Sensor Nonfunctional',
      message:
          'Voltage Sensor #2 is nonfunctional. This may be caused by defective or bad wiring.',
      timestamp: '10m ago',
      type: NotificationType.critical,
      isRead: false,
    ),
    NotificationItem(
      id: 'n2',
      title: 'Critical Temperature Hazard',
      message:
          'Thermal anomaly detected on Array B. Extreme heat detected (possible fire risk). Check panel immediately.',
      timestamp: '1h ago',
      type: NotificationType.critical,
      isRead: false,
    ),

    // 2. DEGRADATION WARNING (YELLOW)
    NotificationItem(
      id: 'n3',
      title: 'Dust & Debris Accumulation',
      message:
          'Panel efficiency dropped by 4%. Dust layer detected—clean panels soon to prevent further output degradation.',
      timestamp: '3h ago',
      type: NotificationType.warning,
      isRead: false,
    ),
    NotificationItem(
      id: 'n4',
      title: 'Partial Shading Alert',
      message:
          'Persistent shading detected on Panel 3 between 8 AM - 10 AM. Trim nearby foliage to avoid cell hotspots.',
      timestamp: '1d ago',
      type: NotificationType.warning,
      isRead: true,
    ),

    // 3. INFO / REMINDER / NEWS (GREEN)
    NotificationItem(
      id: 'n5',
      title: 'System Firmware Update',
      message:
          'Solar Control App v1.0.3 and IoT Sensor Node updates are ready for installation.',
      timestamp: '2d ago',
      type: NotificationType.info,
      isRead: true,
    ),
    NotificationItem(
      id: 'n6',
      title: 'Updated Terms of Service',
      message:
          'We have updated our Privacy Policy and Terms of Service regarding local data storage.',
      timestamp: '3d ago',
      type: NotificationType.info,
      isRead: true,
    ),
  ];

  void _markAllAsRead() {
    setState(() {
      for (var item in _notifications) {
        item.isRead = true;
      }
    });
  }

  void _removeItem(String id) {
    setState(() {
      _notifications.removeWhere((item) => item.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final int unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: _buildAppBar(context, unreadCount),
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final item = _notifications[index];
                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _removeItem(item.id),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      CupertinoIcons.trash,
                      color: Color(0xFFDC2626),
                      size: 22,
                    ),
                  ),
                  child: _buildNotificationCard(item),
                );
              },
            ),
    );
  }

  AppBar _buildAppBar(BuildContext context, int unreadCount) {
    return AppBar(
      backgroundColor: pageBg,
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
            'Notifications',
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
                color: const Color(0xFF20831B),
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
            onPressed: _markAllAsRead,
            child: const Text(
              'Read All',
              style: TextStyle(
                color: Color(0xFF20831B),
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
      case NotificationType.critical: // Red
        iconColor = const Color(0xFFDC2626);
        iconData = CupertinoIcons.exclamationmark_triangle_fill;
        break;
      case NotificationType.warning: // Yellow
        iconColor = const Color(0xFFD97706);
        iconData = CupertinoIcons.bolt_horizontal_circle_fill;
        break;
      case NotificationType.info: // Green
        iconColor = const Color(0xFF16A34A);
        iconData = CupertinoIcons.info_circle_fill;
        break;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          item.isRead = true;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, // Pure white box with zero background tint
          borderRadius: BorderRadius.circular(16),
          // Border removed entirely for a minimal floating appearance
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clean Icon
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Icon(iconData, color: iconColor, size: 22),
            ),

            // Content Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        ),
                      ),
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

            // Unread Indicator Dot
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
              color: Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.bell_slash,
              size: 40,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You have no new notifications.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
