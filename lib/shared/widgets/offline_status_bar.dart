import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:flutter/material.dart';
import '../../core/services/offline_queue_service.dart';

/// Non-intrusive, reactive floating status pill that notifies users of offline state,
/// active synchronizations, and successful sync flushes without displacing the AppBar.
class OfflineStatusBar extends StatelessWidget {
  const OfflineStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final queueService = OfflineQueueService.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([
        queueService.isOnlineNotifier,
        queueService.isSyncingNotifier,
        queueService.pendingCountNotifier,
        queueService.justSyncedNotifier,
        queueService.justReconnectedNotifier,
      ]),
      builder: (context, _) {
        final isOnline = queueService.isOnline;
        final isSyncing = queueService.isSyncing;
        final pending = queueService.pendingCount;
        final justSynced = queueService.justSynced;
        final justReconnected = queueService.justReconnected;

        // If online, not syncing, nothing pending, and not flashing success/reconnect: hide completely
        if (isOnline &&
            !isSyncing &&
            pending == 0 &&
            !justSynced &&
            !justReconnected) {
          return const SizedBox.shrink();
        }

        Color bgColor;
        Color fgColor;
        Color borderColor;
        Widget leadingIcon;
        String title;
        String subtitle;
        Widget? trailingAction;

        if (justReconnected) {
          bgColor = const Color(0xFF065F46); // Emerald 800
          fgColor = Colors.white;
          borderColor = const Color(0xFF10B981);
          leadingIcon = const Icon(
            Icons.wifi_rounded,
            color: Color(0xFF6EE7B7),
            size: 18,
          );
          title = 'Back online';
          subtitle = 'Internet connection restored';
        } else if (justSynced) {
          bgColor = const Color(0xFF065F46); // Emerald 800
          fgColor = Colors.white;
          borderColor = const Color(0xFF10B981);
          leadingIcon = const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF6EE7B7),
            size: 18,
          );
          title = 'All changes synced';
          subtitle = 'Offline records successfully uploaded to cloud';
        } else if (isSyncing) {
          bgColor = const Color(0xFF312E81); // Indigo 900
          fgColor = Colors.white;
          borderColor = const Color(0xFF6366F1);
          leadingIcon = const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
          title = 'Reconnected & Syncing';
          subtitle = pending > 0
              ? 'Uploading $pending offline record${pending > 1 ? "s" : ""}...'
              : 'Synchronizing with cloud...';
        } else if (!isOnline) {
          bgColor = const Color(0xFF1E293B); // Slate 800
          fgColor = const Color(0xFFF8FAFC);
          borderColor = const Color(0xFFF59E0B); // Amber 500
          leadingIcon = const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFFFBBF24),
            size: 18,
          );
          title = 'Offline Mode';
          subtitle = pending > 0
              ? '$pending change${pending > 1 ? "s" : ""} saved locally'
              : 'Changes save locally and sync automatically';
          trailingAction = InkWell(
            onTap: () => queueService.syncNow(),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x33F59E0B),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x66F59E0B)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.refresh,
                    color: Color(0xFFFDE68A),
                    size: 14,
                  ),
                  Gap(4),
                  Text(
                    'Retry',
                    style: TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Online with pending items waiting for sync trigger
          bgColor = const Color(0xFF1E1B4B);
          fgColor = Colors.white;
          borderColor = const Color(0xFF818CF8);
          leadingIcon = const Icon(
            Icons.sync_problem_rounded,
            color: Color(0xFFA5B4FC),
            size: 18,
          );
          title = 'Pending upload';
          subtitle = '$pending record${pending > 1 ? "s" : ""} queued for sync';
          trailingAction = InkWell(
            onTap: () => queueService.syncNow(),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x446366F1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Sync Now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }

        return SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  leadingIcon,
                  const Gap(10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: fgColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fgColor.withValues(alpha: 0.85),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailingAction != null) ...[
                    const Gap(8),
                    trailingAction,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
