import 'package:flutter/material.dart';

import '../../../../gitlab_status.dart';
import '../../../../models/project_models.dart';
import '../../../../shared/widgets/status_badge.dart';

class KanbanCard extends StatefulWidget {
  final CardModel card;
  final VoidCallback onDelete;

  const KanbanCard({super.key, required this.card, required this.onDelete});

  @override
  State<KanbanCard> createState() => _KanbanCardState();
}

class _KanbanCardState extends State<KanbanCard> {
  bool _hovered = false;

  @override
  void didUpdateWidget(covariant KanbanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id ||
        oldWidget.card.status.apiValue != widget.card.status.apiValue ||
        oldWidget.card.issue != widget.card.issue ||
        oldWidget.card.commitSha != widget.card.commitSha ||
        oldWidget.card.updatedAt != widget.card.updatedAt) {
      setState(() {});
    }
  }

  String _formatCardTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.card.status;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFF3A3A3A) : const Color(0xFF333333),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _hovered ? const Color(0xFF555555) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.card.eventTag != null &&
                          widget.card.eventTag!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 6, bottom: 6),
                          child: Builder(
                            builder: (context) {
                              final c = switch (widget.card.status.source) {
                                GitLabStatusSource.pipeline => const Color(
                                  0xFF3B82F6,
                                ),
                                GitLabStatusSource.job => const Color(
                                  0xFF94A3B8,
                                ),
                                GitLabStatusSource.mergeRequest => const Color(
                                  0xFFA855F7,
                                ),
                                GitLabStatusSource.issue => const Color(
                                  0xFFF59E0B,
                                ),
                              };
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: c.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: c.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  widget.card.eventTag!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: c,
                                    letterSpacing: 0.03,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      if (widget.card.projectName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF4A7C2F,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(
                                  0xFF4A7C2F,
                                ).withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              widget.card.projectName!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9FD68A),
                                letterSpacing: 0.04,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    widget.card.issue,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFD4D4D4),
                      height: 1.45,
                    ),
                  ),
                  if (widget.card.commitSha != null &&
                      widget.card.commitSha!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(
                            0xFF3B82F6,
                          ).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        widget.card.commitSha!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF93C5FD),
                        ),
                      ),
                    ),
                  ],
                  if (widget.card.issueKind != null &&
                      widget.card.issueKind!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Builder(
                        builder: (context) {
                          final c = switch (widget.card.issueKind!) {
                            'Erro' => const Color(0xFFEF4444),
                            'Manutenção' => const Color(0xFF94A3B8),
                            'Review' => const Color(0xFFA855F7),
                            'Feature' => const Color(0xFF22C55E),
                            'Docs' => const Color(0xFF3B82F6),
                            'Dúvida' => const Color(0xFFF59E0B),
                            _ => const Color(0xFF888888),
                          };
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: c.withValues(alpha: 0.55),
                              ),
                            ),
                            child: Text(
                              widget.card.issueKind!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: c,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (_bodyText(widget.card) != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _bodyText(widget.card)!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF999999),
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      StatusBadge(status: status),
                      if (widget.card.updatedAt != null) ...[
                        const Spacer(),
                        Icon(
                          Icons.schedule,
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatCardTime(widget.card.updatedAt),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (_hovered)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _bodyText(CardModel card) {
  if (card.issueDescription != null && card.issueDescription!.isNotEmpty) {
    return card.issueDescription;
  }
  if (card.commitMessage != null && card.commitMessage!.isNotEmpty) {
    return card.commitMessage;
  }
  return null;
}
