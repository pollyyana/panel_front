import '../gitlab_status.dart';
import '../models/project_models.dart';
import 'http/app_exceptions.dart';
import 'panel_api_client.dart';

class ApiProject {
  final String id;
  final String name;
  final String? gitlabUrl;
  final String? gitlabPath;
  final List<ApiColumn> columns;

  ApiProject({
    required this.id,
    required this.name,
    this.gitlabUrl,
    this.gitlabPath,
    required this.columns,
  });

  factory ApiProject.fromJson(Map<String, dynamic> json) {
    try {
      return ApiProject(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        gitlabUrl: json['gitlabUrl'] as String?,
        gitlabPath: json['gitlabPath'] as String?,
        columns: (json['columns'] as List<dynamic>?)
                ?.map((e) => ApiColumn.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
    } catch (e) {
      throw ApiException(
        message: 'Erro ao parsear ApiProject: $e',
        originalError: e,
      );
    }
  }

  ProjectPanel toProjectPanel() {
    return ProjectPanel(
      id: id,
      name: name,
      gitlabUrl: gitlabUrl,
      gitlabPath: gitlabPath,
      columns: columns.map((c) => c.toColumnModel()).toList(),
    );
  }
}

class ApiColumn {
  final String id;
  final String title;
  final List<ApiCard> cards;

  ApiColumn({required this.id, required this.title, required this.cards});

  factory ApiColumn.fromJson(Map<String, dynamic> json) {
    try {
      return ApiColumn(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        cards: (json['cards'] as List<dynamic>?)
                ?.map((e) => ApiCard.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
    } catch (e) {
      throw ApiException(
        message: 'Erro ao parsear ApiColumn: $e',
        originalError: e,
      );
    }
  }

  ColumnModel toColumnModel() {
    return ColumnModel(
      id: id,
      title: columnDisplayTitle(id, title),
      cards: cards.map((c) => c.toCardModel()).toList(),
    );
  }
}

/// Títulos amigáveis das colunas do quadro GitLab.
String columnDisplayTitle(String columnId, String fallback) {
  if (columnId.endsWith('-pipeline')) return 'Pipeline';
  if (columnId.endsWith('-job')) return 'Jobs';
  if (columnId.endsWith('-merge_request')) return 'Merge requests';
  if (columnId.endsWith('-issue')) return 'Issues';
  return fallback;
}

class ApiCard {
  final String id;
  final String issue;
  final String statusApi;
  final String statusSource;
  final String statusLabelPt;
  final String eventTag;
  final String commitSha;
  final String commitMessage;
  final String issueKind;
  final String issueDescription;
  final DateTime? updatedAt;

  ApiCard({
    required this.id,
    required this.issue,
    required this.statusApi,
    required this.statusSource,
    required this.statusLabelPt,
    this.eventTag = '',
    this.commitSha = '',
    this.commitMessage = '',
    this.issueKind = '',
    this.issueDescription = '',
    this.updatedAt,
  });

  factory ApiCard.fromJson(Map<String, dynamic> json) {
    try {
      DateTime? parsedAt;
      final rawAt = json['updatedAt'] as String?;
      if (rawAt != null && rawAt.isNotEmpty) {
        final parsed = DateTime.tryParse(rawAt);
        if (parsed != null && parsed.year >= 2000) {
          parsedAt = parsed;
        }
      }
      return ApiCard(
        id: json['id'] as String? ?? '',
        issue: json['issue'] as String? ?? '',
        statusApi: json['statusApi'] as String? ?? 'pending',
        statusSource: json['statusSource'] as String? ?? 'pipeline',
        statusLabelPt: json['statusLabelPt'] as String? ?? '',
        eventTag: json['eventTag'] as String? ?? '',
        commitSha: json['commitSha'] as String? ?? '',
        commitMessage: json['commitMessage'] as String? ?? '',
        issueKind: json['issueKind'] as String? ?? '',
        issueDescription: json['issueDescription'] as String? ?? '',
        updatedAt: parsedAt,
      );
    } catch (e) {
      throw ApiException(
        message: 'Erro ao parsear ApiCard: $e',
        originalError: e,
      );
    }
  }

  CardModel toCardModel() {
    return CardModel(
      id: id,
      issue: issue,
      eventTag: eventTag.isNotEmpty ? eventTag : null,
      commitSha: commitSha.isNotEmpty ? commitSha : null,
      commitMessage: commitMessage.isNotEmpty ? commitMessage : null,
      issueKind: issueKind.isNotEmpty ? issueKind : null,
      issueDescription:
          issueDescription.isNotEmpty ? issueDescription : null,
      updatedAt: updatedAt,
      status: GitLabCardStatus.fromApi(
        statusApi,
        source: statusSourceFromApi(statusSource),
      ),
    );
  }
}
