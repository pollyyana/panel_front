import 'package:flutter/material.dart';

import '../../../../models/activity_notification.dart';

class ActivityFeedBar extends StatelessWidget {
  final List<String> projectNames;
  final List<ActivityNotification> activities;
  final String? selectedProject;
  final bool telegramEnabled;

  const ActivityFeedBar({
    super.key,
    required this.projectNames,
    required this.activities,
    this.selectedProject,
    this.telegramEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final byProject = {for (final a in activities) a.projectName: a};
    final names = projectNames;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Última atividade por projeto',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      width: 1,
                      height: 14,
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  Icon(
                    telegramEnabled ? Icons.send_rounded : Icons.send_outlined,
                    size: 13,
                    color: telegramEnabled
                        ? const Color(0xFF4ADE80)
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    telegramEnabled ? 'Telegram' : 'Telegram off',
                    style: TextStyle(
                      fontSize: 11,
                      color: telegramEnabled
                          ? const Color(0xFF86EFAC)
                          : Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 88,
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < names.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Builder(
                        builder: (_) {
                          final name = names[i];
                          final notification = byProject[name];
                          final dimmed =
                              selectedProject != null &&
                              selectedProject != name;
                          if (notification == null) {
                            return _ProjectActivityPlaceholder(
                              projectName: name,
                              dimmed: dimmed,
                              highlighted: selectedProject == name,
                            );
                          }
                          return _PushNotificationTile(
                            notification: notification,
                            dimmed: dimmed,
                            highlighted: selectedProject == name,
                          );
                        },
                      ),
                    ],
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

class _ProjectActivityPlaceholder extends StatelessWidget {
  final String projectName;
  final bool dimmed;
  final bool highlighted;

  const _ProjectActivityPlaceholder({
    required this.projectName,
    this.dimmed = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: Container(
        width: 200,
        height: 88,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted
                ? const Color(0xFF6BC04A)
                : const Color(0xFF333333),
            width: highlighted ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              projectName,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF666666),
              ),
            ),
            const Spacer(),
            const Text(
              'Sem atualização',
              style: TextStyle(fontSize: 12, color: Color(0xFF555555)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PushNotificationTile extends StatelessWidget {
  final ActivityNotification notification;
  final bool dimmed;
  final bool highlighted;

  const _PushNotificationTile({
    required this.notification,
    this.dimmed = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = notification.status.color;

    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: Container(
        width: 260,
        height: 88,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted
                ? const Color(0xFF6BC04A)
                : color.withValues(alpha: 0.35),
            width: highlighted ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  notification.projectName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFAAAAAA),
                  ),
                ),
                const Text(' · ', style: TextStyle(color: Color(0xFF555555))),
                Text(
                  notification.status.columnTitlePt,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9FD68A),
                  ),
                ),
                const Text(' · ', style: TextStyle(color: Color(0xFF555555))),
                Expanded(
                  child: Text(
                    notification.issue,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD4D4D4),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  notification.timeAgo,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                notification.status.labelPt,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                notification.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB0B0B0),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
