import 'package:panel/app/gitlab_status.dart';


class CardModel {
  String id;
  String issue;
  GitLabCardStatus status;
  /// Tag do tipo: Pipeline, Merge, Issue, Job…
  String? eventTag;
  /// SHA curto do commit (ex.: a1b2c3d4).
  String? commitSha;
  /// Primeira linha da mensagem do commit.
  String? commitMessage;
  /// Categoria: Erro, Manutenção, Review, Feature…
  String? issueKind;
  /// Descrição ou comentário da issue.
  String? issueDescription;
  /// Projeto de origem (panel, log, farm) no quadro centralizado.
  String? projectName;
  /// Coluna original no backend (`panel-pipeline`, etc.).
  String? columnId;
  /// Última atualização do evento GitLab neste cartão.
  DateTime? updatedAt;

  CardModel({
    required this.id,
    required this.issue,
    required this.status,
    this.eventTag,
    this.commitSha,
    this.commitMessage,
    this.issueKind,
    this.issueDescription,
    this.projectName,
    this.columnId,
    this.updatedAt,
  });

  factory CardModel.fromGitLab({
    required String id,
    required String issue,
    required String rawStatus,
    required GitLabStatusSource source,
  }) =>
      CardModel(
        id: id,
        issue: issue,
        status: GitLabCardStatus.fromApi(rawStatus, source: source),
      );
}

class ColumnModel {
  String id;
  String title;
  List<CardModel> cards;

  ColumnModel({required this.id, required this.title, required this.cards});
}

class ProjectPanel {
  String id;
  String name;
  String? gitlabUrl;
  String? gitlabPath;
  List<ColumnModel> columns;

  ProjectPanel({
    required this.id,
    required this.name,
    this.gitlabUrl,
    this.gitlabPath,
    required this.columns,
  });
}

/// Ordem padrão quando projetos não têm ordem definida.
const defaultProjectOrder = ['panel', 'log', 'farm'];

List<String> projectNamesOrdered(List<ProjectPanel> projects) {
  final names = projects.map((p) => p.name).toList();
  names.sort((a, b) {
    final ia = defaultProjectOrder.indexOf(a);
    final ib = defaultProjectOrder.indexOf(b);
    final ai = ia < 0 ? 99 : ia;
    final bi = ib < 0 ? 99 : ib;
    return ai.compareTo(bi);
  });
  return names;
}

const _boardKinds = [
  ('pipeline', 'Pipeline'),
  ('job', 'Jobs'),
  ('merge_request', 'Merge requests'),
  ('issue', 'Issues'),
];

/// Quadro único: mesmas 4 colunas com cartões de panel, log e farm juntos.
/// [filterProject] — se informado, só cartões desse projeto.
List<ColumnModel> buildCentralizedBoard(
  List<ProjectPanel> projects, {
  String? filterProject,
}) {
  var ordered = [...projects]
    ..sort((a, b) {
      final ia = defaultProjectOrder.indexOf(a.name);
      final ib = defaultProjectOrder.indexOf(b.name);
      final ai = ia < 0 ? 99 : ia;
      final bi = ib < 0 ? 99 : ib;
      return ai.compareTo(bi);
    });

  if (filterProject != null && filterProject.isNotEmpty) {
    ordered = ordered.where((p) => p.name == filterProject).toList();
  }

  return _boardKinds.map((kind) {
    final kindId = kind.$1;
    final cards = <CardModel>[];
    for (final project in ordered) {
      ColumnModel? col;
      for (final c in project.columns) {
        if (c.id.endsWith('-$kindId')) {
          col = c;
          break;
        }
      }
      if (col == null) continue;
      for (final card in col.cards) {
        cards.add(CardModel(
          id: card.id,
          issue: card.issue,
          status: card.status,
          eventTag: card.eventTag,
          commitSha: card.commitSha,
          commitMessage: card.commitMessage,
          issueKind: card.issueKind,
          issueDescription: card.issueDescription,
          projectName: project.name,
          columnId: col.id,
          updatedAt: card.updatedAt,
        ));
      }
    }
    return ColumnModel(id: kindId, title: kind.$2, cards: cards);
  }).toList();
}
