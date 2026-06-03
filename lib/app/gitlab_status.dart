import 'package:flutter/material.dart';

/// De onde veio o status na API do GitLab.
enum GitLabStatusSource {
  /// `GET /projects/:id/pipelines` → campo `status`
  pipeline,

  /// `GET /projects/:id/jobs` → campo `status` (mesmos valores do pipeline)
  job,

  /// `GET /projects/:id/merge_requests` → campo `state`
  mergeRequest,

  /// Webhook `issue` / `work_item` → campo `state` + `action`
  issue,
}

/// Status de pipeline/job — valores exatos da API GitLab.
/// https://docs.gitlab.com/ee/api/jobs.html#list-project-jobs
enum GitLabCiStatus {
  created,
  waitingForResource,
  preparing,
  pending,
  running,
  success,
  failed,
  canceled,
  skipped,
  manual,
  unknown;

  /// Valor enviado/recebido pela API (`snake_case`).
  String get apiValue => switch (this) {
        GitLabCiStatus.created => 'created',
        GitLabCiStatus.waitingForResource => 'waiting_for_resource',
        GitLabCiStatus.preparing => 'preparing',
        GitLabCiStatus.pending => 'pending',
        GitLabCiStatus.running => 'running',
        GitLabCiStatus.success => 'success',
        GitLabCiStatus.failed => 'failed',
        GitLabCiStatus.canceled => 'canceled',
        GitLabCiStatus.skipped => 'skipped',
        GitLabCiStatus.manual => 'manual',
        GitLabCiStatus.unknown => 'unknown',
      };

  /// Rótulo amigável no painel (PT-BR).
  String get labelPt => switch (this) {
        GitLabCiStatus.created => 'Criada',
        GitLabCiStatus.waitingForResource => 'Aguardando recurso',
        GitLabCiStatus.preparing => 'Preparando',
        GitLabCiStatus.pending => 'Pendente',
        GitLabCiStatus.running => 'Em execução',
        GitLabCiStatus.success => 'Aprovada',
        GitLabCiStatus.failed => 'Reprovada',
        GitLabCiStatus.canceled => 'Cancelada',
        GitLabCiStatus.skipped => 'Ignorada',
        GitLabCiStatus.manual => 'Manual',
        GitLabCiStatus.unknown => 'Desconhecido',
      };

  Color get color => switch (this) {
        GitLabCiStatus.success => const Color(0xFF22C55E),
        GitLabCiStatus.failed => const Color(0xFFEF4444),
        GitLabCiStatus.running ||
        GitLabCiStatus.preparing ||
        GitLabCiStatus.pending =>
          const Color(0xFFF59E0B),
        GitLabCiStatus.created ||
        GitLabCiStatus.waitingForResource =>
          const Color(0xFF3B82F6),
        GitLabCiStatus.canceled ||
        GitLabCiStatus.skipped =>
          const Color(0xFF888888),
        GitLabCiStatus.manual => const Color(0xFF8B5CF6),
        GitLabCiStatus.unknown => const Color(0xFF6B7280),
      };

  static GitLabCiStatus fromApi(String? raw) {
    final key = raw?.trim().toLowerCase().replaceAll('-', '_') ?? '';
    return switch (key) {
      'created' => GitLabCiStatus.created,
      'waiting_for_resource' => GitLabCiStatus.waitingForResource,
      'preparing' => GitLabCiStatus.preparing,
      'pending' => GitLabCiStatus.pending,
      'running' => GitLabCiStatus.running,
      'success' => GitLabCiStatus.success,
      'failed' => GitLabCiStatus.failed,
      'canceled' => GitLabCiStatus.canceled,
      'cancelled' => GitLabCiStatus.canceled,
      'skipped' => GitLabCiStatus.skipped,
      'manual' => GitLabCiStatus.manual,
      // aliases legados / internos
      'aprovada' || 'aprovado' || 'passed' => GitLabCiStatus.success,
      'reprovada' || 'reprovado' || 'error' => GitLabCiStatus.failed,
      _ => GitLabCiStatus.unknown,
    };
  }
}

/// Estado de merge request — campo `state` na API.
/// https://docs.gitlab.com/ee/api/merge_requests.html
enum GitLabMrState {
  opened,
  closed,
  locked,
  merged,
  unknown;

  String get apiValue => switch (this) {
        GitLabMrState.opened => 'opened',
        GitLabMrState.closed => 'closed',
        GitLabMrState.locked => 'locked',
        GitLabMrState.merged => 'merged',
        GitLabMrState.unknown => 'unknown',
      };

  String get labelPt => switch (this) {
        GitLabMrState.opened => 'Aberta',
        GitLabMrState.closed => 'Fechada',
        GitLabMrState.locked => 'Bloqueada',
        GitLabMrState.merged => 'Mesclada',
        GitLabMrState.unknown => 'Desconhecido',
      };

  Color get color => switch (this) {
        GitLabMrState.merged => const Color(0xFF22C55E),
        GitLabMrState.opened => const Color(0xFF3B82F6),
        GitLabMrState.closed => const Color(0xFF888888),
        GitLabMrState.locked => const Color(0xFFF59E0B),
        GitLabMrState.unknown => const Color(0xFF6B7280),
      };

  static GitLabMrState fromApi(String? raw) {
    final key = raw?.trim().toLowerCase() ?? '';
    return switch (key) {
      'opened' => GitLabMrState.opened,
      'closed' => GitLabMrState.closed,
      'locked' => GitLabMrState.locked,
      'merged' => GitLabMrState.merged,
      _ => GitLabMrState.unknown,
    };
  }
}

/// Estado de issue / item de trabalho (webhook GitLab).
enum GitLabIssueState {
  opened,
  closed,
  reopened,
  updated,
  unknown;

  String get apiValue => switch (this) {
        GitLabIssueState.opened => 'opened',
        GitLabIssueState.closed => 'closed',
        GitLabIssueState.reopened => 'reopened',
        GitLabIssueState.updated => 'updated',
        GitLabIssueState.unknown => 'unknown',
      };

  String get labelPt => switch (this) {
        GitLabIssueState.opened => 'Aberta',
        GitLabIssueState.closed => 'Fechada',
        GitLabIssueState.reopened => 'Reaberta',
        GitLabIssueState.updated => 'Atualizada',
        GitLabIssueState.unknown => 'Desconhecido',
      };

  Color get color => switch (this) {
        GitLabIssueState.opened => const Color(0xFF3B82F6),
        GitLabIssueState.closed => const Color(0xFF888888),
        GitLabIssueState.reopened => const Color(0xFF22C55E),
        GitLabIssueState.updated => const Color(0xFFF59E0B),
        GitLabIssueState.unknown => const Color(0xFF6B7280),
      };

  static GitLabIssueState fromApi(String? raw, {String? action}) {
    final act = action?.trim().toLowerCase() ?? '';
    if (act == 'reopen') return GitLabIssueState.reopened;
    if (act == 'close') return GitLabIssueState.closed;
    if (act == 'open') return GitLabIssueState.opened;
    if (act == 'update') return GitLabIssueState.updated;

    return switch (raw?.trim().toLowerCase() ?? '') {
      'opened' => GitLabIssueState.opened,
      'closed' => GitLabIssueState.closed,
      'reopened' => GitLabIssueState.reopened,
      'updated' => GitLabIssueState.updated,
      _ => GitLabIssueState.unknown,
    };
  }
}

/// Status unificado exibido no cartão do painel.
class GitLabCardStatus {
  final GitLabStatusSource source;
  final GitLabCiStatus? ci;
  final GitLabMrState? mr;
  final GitLabIssueState? issue;

  const GitLabCardStatus._({
    required this.source,
    this.ci,
    this.mr,
    this.issue,
  });

  factory GitLabCardStatus.pipeline(GitLabCiStatus status) =>
      GitLabCardStatus._(source: GitLabStatusSource.pipeline, ci: status);

  factory GitLabCardStatus.job(GitLabCiStatus status) =>
      GitLabCardStatus._(source: GitLabStatusSource.job, ci: status);

  factory GitLabCardStatus.mergeRequest(GitLabMrState state) =>
      GitLabCardStatus._(source: GitLabStatusSource.mergeRequest, mr: state);

  factory GitLabCardStatus.issue(GitLabIssueState state) =>
      GitLabCardStatus._(source: GitLabStatusSource.issue, issue: state);

  /// Parse genérico para integração com a API.
  factory GitLabCardStatus.fromApi(
    String? raw, {
    required GitLabStatusSource source,
  }) {
    switch (source) {
      case GitLabStatusSource.pipeline:
        return GitLabCardStatus.pipeline(GitLabCiStatus.fromApi(raw));
      case GitLabStatusSource.job:
        return GitLabCardStatus.job(GitLabCiStatus.fromApi(raw));
      case GitLabStatusSource.mergeRequest:
        return GitLabCardStatus.mergeRequest(GitLabMrState.fromApi(raw));
      case GitLabStatusSource.issue:
        return GitLabCardStatus.issue(GitLabIssueState.fromApi(raw));
    }
  }

  String get labelPt =>
      ci?.labelPt ?? mr?.labelPt ?? issue?.labelPt ?? 'Desconhecido';

  /// Valor original da API (útil em debug / tooltip futuro).
  String get apiValue =>
      ci?.apiValue ?? mr?.apiValue ?? issue?.apiValue ?? 'unknown';

  Color get color =>
      ci?.color ?? mr?.color ?? issue?.color ?? const Color(0xFF6B7280);

  /// Ex.: `success` · pipeline
  String get subtitle => '$apiValue · ${source.name}';

  String get columnTitlePt => switch (source) {
        GitLabStatusSource.pipeline => 'Pipeline',
        GitLabStatusSource.job => 'Jobs',
        GitLabStatusSource.mergeRequest => 'Merge',
        GitLabStatusSource.issue => 'Issues',
      };
}
