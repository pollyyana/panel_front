import 'package:flutter/material.dart';

import '../../gitlab_status.dart';

class StatusBadge extends StatelessWidget {
  final GitLabCardStatus status;

  const StatusBadge({required this.status, super.key});

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                status.labelPt,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 2),
            child: Text(
              status.subtitle,
              style: const TextStyle(fontSize: 9, color: Color(0xFF777777)),
            ),
          ),
        ],
      ),
    );
  }
}
