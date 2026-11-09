// top_notification_service.dart
import 'package:flutter/material.dart';
import '../screens/monitoring_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void showGlobalTopNotification({
  required String title,
  required String message,
  String type = 'info',
  String? panelId,
}) {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  // Match notification colors from notification_screen.dart
  Color accentColor;
  IconData iconData;

  switch (type) {
    case 'critical':
      accentColor = const Color(0xFFDC2626);
      iconData = Icons.warning_rounded;
      break;
    case 'warning':
      accentColor = const Color(0xFFD97706);
      iconData = Icons.error_outline_rounded;
      break;
    case 'info':
    default:
      accentColor = const Color(0xFF16A34A);
      iconData = Icons.info_outline_rounded;
      break;
  }

  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {
            if (overlayEntry.mounted) overlayEntry.remove();

            // Optional: Route to specific hardware panel if provided
            if (panelId != null && panelId.isNotEmpty) {
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => MonitoringScreen(panelId: panelId),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white, // Pure white background
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Left accent indicator badge
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Overlay.of(context).insert(overlayEntry);

  // Auto dismiss after 4 seconds
  Future.delayed(const Duration(seconds: 4), () {
    if (overlayEntry.mounted) {
      overlayEntry.remove();
    }
  });
}
