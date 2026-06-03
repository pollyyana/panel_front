import 'package:flutter/material.dart';

import '../../../../models/project_models.dart';
import 'kanban_card.dart';

class KanbanColumn extends StatelessWidget {
  final ColumnModel column;
  final VoidCallback onAddCard;
  final ValueChanged<CardModel> onDeleteCard;

  const KanbanColumn({
    super.key,
    required this.column,
    required this.onAddCard,
    required this.onDeleteCard,
  });

  bool get _isPipeline =>
      column.id == 'pipeline' || column.id.endsWith('-pipeline');

  bool get _isMerge =>
      column.id == 'merge_request' || column.id.endsWith('-merge_request');

  List<CardModel> get _displayCards => column.cards;

  @override
  Widget build(BuildContext context) {
    final accent = _isPipeline
        ? const Color(0xFF6BC04A)
        : _isMerge
        ? const Color(0xFF60A5FA)
        : const Color(0xFF888888);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: _isPipeline
            ? Border.all(color: const Color(0xFF4A7C2F).withValues(alpha: 0.55))
            : _isMerge
            ? Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.65),
                width: 1.5,
              )
            : Border.all(color: const Color(0xFF3A3A3A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Icon(
                  _isPipeline
                      ? Icons.play_circle_outline
                      : _isMerge
                      ? Icons.merge_type
                      : Icons.label_outline,
                  size: 14,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    column.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.02,
                      color: Color(0xFFE0E0E0),
                    ),
                  ),
                ),
                Text(
                  '${column.cards.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
          if (_displayCards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Nada aqui',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _displayCards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 6),
                    KanbanCard(
                      key: ValueKey(
                        '${_displayCards[i].id}|${_displayCards[i].status.apiValue}|${_displayCards[i].updatedAt?.millisecondsSinceEpoch ?? 0}',
                      ),
                      card: _displayCards[i],
                      onDelete: () => onDeleteCard(_displayCards[i]),
                    ),
                  ],
                ],
              ),
            ),
          InkWell(
            onTap: onAddCard,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.add, size: 16, color: Color(0xFF666666)),
                  SizedBox(width: 6),
                  Text(
                    'Adicionar',
                    style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
