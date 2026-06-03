import 'dart:async';

import 'package:flutter/foundation.dart';

import '../gitlab_status.dart';
import '../models/activity_notification.dart';
import '../models/project_models.dart';
import 'panel_activity_service.dart';
import 'panel_api_client.dart';

typedef RealtimeStatusCallback = void Function(bool connected);
typedef RealtimeUpdateCallback = void Function();

/// Carrega dados do backend (GitLab via webhook) ou fallback local.
class PanelRepository {
  PanelRepository({PanelApiClient? api, PanelActivityService? local})
      : _api = api ?? PanelApiClient(),
        _local = local ?? PanelActivityService();

  final PanelApiClient _api;
  final PanelActivityService _local;
  StreamSubscription<void>? _realtimeSub;
  int _loadGen = 0;

  bool apiConnected = false;
  bool realtimeConnected = false;
  String? connectionError;
  List<ProjectPanel> projects = [];
  List<ActivityNotification> activities = [];
  bool telegramEnabled = false;
  GitlabSetupInfo? gitlabSetup;
  DateTime? lastBoardSyncAt;
  int _boardRefreshCount = 0;
  int boardRevision = 0;
  String _mrFingerprint = '';

  Future<ProjectPanel> addMonitor({
    required String gitlabUrl,
    String? name,
  }) async {
    if (!apiConnected) {
      throw StateError('API offline');
    }
    final created = await _api.addProject(gitlabUrl: gitlabUrl, name: name);
    final panel = created.toProjectPanel();
    final i = projects.indexWhere((p) => p.name == panel.name);
    if (i >= 0) {
      projects[i] = panel;
    } else {
      projects.add(panel);
    }
    return panel;
  }

  Future<void> syncWebhookSecret(String secret) async {
    if (!apiConnected) {
      throw StateError('API offline');
    }
    await _api.syncWebhookSecret(secret);
    gitlabSetup = await _api.fetchGitlabSetup();
  }

  Future<void> load() async {
    final gen = ++_loadGen;
    try {
      await _api.health();
      if (gen != _loadGen) return;
      final apiProjects = await _api.fetchProjects();
      if (gen != _loadGen) return;
      projects = apiProjects.map((p) => p.toProjectPanel()).toList();
      activities = await _api.fetchActivities();
      if (gen != _loadGen) return;
      telegramEnabled = await _api.fetchTelegramEnabled();
      gitlabSetup = await _api.fetchGitlabSetup();
      if (gen != _loadGen) return;
      apiConnected = true;
      connectionError = null;
      lastBoardSyncAt = DateTime.now();
    } catch (e) {
      if (gen != _loadGen) return;
      apiConnected = false;
      realtimeConnected = false;
      gitlabSetup = null;
      connectionError = e.toString();
      if (projects.isEmpty) {
        _loadLocalFallback();
      }
    }
  }

  /// Atualização leve do quadro (1 request) — usada em tempo real via SSE/poll.
  Future<void> refreshBoard() async {
    try {
      final apiProjects = await _api.fetchProjects();
      projects = apiProjects.map((p) => p.toProjectPanel()).toList();
      apiConnected = true;
      connectionError = null;
      lastBoardSyncAt = DateTime.now();
      _boardRefreshCount++;
      _trackMergeFingerprint();
      _debugLogBoard('refreshBoard #$_boardRefreshCount');
      if (_boardRefreshCount % 5 == 0) {
        try {
          gitlabSetup = await _api.fetchGitlabSetup();
        } catch (_) {}
      }
    } catch (e, st) {
      debugPrint('[panel] refreshBoard FALHOU: $e');
      debugPrint('[panel] $st');
    }
  }

  String _mergeFingerprint() {
    final parts = <String>[];
    for (final p in projects) {
      for (final col in p.columns) {
        if (!col.id.contains('merge')) continue;
        for (final c in col.cards) {
          parts.add(
            '${p.name}:${c.id}:${c.status.apiValue}:${c.updatedAt?.millisecondsSinceEpoch ?? 0}',
          );
        }
      }
    }
    parts.sort();
    return parts.join('|');
  }

  void _trackMergeFingerprint() {
    final mrFp = _mergeFingerprint();
    if (mrFp != _mrFingerprint) {
      if (kDebugMode) {
        debugPrint(
          '[panel] MR fingerprint mudou:\n  antes: $_mrFingerprint\n  agora: $mrFp',
        );
      }
      _mrFingerprint = mrFp;
      boardRevision++;
    }
  }

  void _debugLogBoard(String tag) {
    if (!kDebugMode) return;
    final buf = StringBuffer('[panel] $tag @ ${lastBoardSyncAt?.toLocal()}');
    for (final p in projects) {
      buf.write('\n  projeto ${p.name}:');
      for (final col in p.columns) {
        final n = col.cards.length;
        if (n == 0) continue;
        buf.write(' ${col.title}=$n');
        if (col.id.contains('merge')) {
          for (final c in col.cards) {
            buf.write(
              ' [${c.issue.length > 40 ? '${c.issue.substring(0, 40)}…' : c.issue} | ${c.status.apiValue}]',
            );
          }
        }
      }
    }
    debugPrint(buf.toString());
  }

  void startRealtime({
    required RealtimeUpdateCallback onUpdate,
    RealtimeStatusCallback? onStatus,
  }) {
    _realtimeSub?.cancel();
    if (!apiConnected) {
      realtimeConnected = false;
      onStatus?.call(false);
      return;
    }

    _realtimeSub = _api
        .boardEventStream(
          onConnectionChanged: (connected) {
            realtimeConnected = connected;
            onStatus?.call(connected);
          },
        )
        .listen((_) {
          debugPrint('[panel] SSE → agenda refresh do quadro');
          onUpdate();
        });
  }

  void stopRealtime() {
    _realtimeSub?.cancel();
    _realtimeSub = null;
    realtimeConnected = false;
  }

  void _loadLocalFallback() {
    projects = [
      mockProject('panel', 'panel'),
      mockProject('log', 'log'),
      mockProject('farm', 'farm'),
    ];
    activities = _local.seedMockData();
    telegramEnabled = _local.telegramEnabled;
  }

  ProjectPanel mockProject(String id, String name) {
    return ProjectPanel(
      id: id,
      name: name,
      columns: [
        ColumnModel(id: '$id-pipeline', title: 'Pipeline', cards: []),
        ColumnModel(id: '$id-job', title: 'Jobs', cards: []),
        ColumnModel(id: '$id-merge_request', title: 'Merge requests', cards: []),
        ColumnModel(id: '$id-issue', title: 'Issues', cards: []),
      ],
    );
  }

  Future<void> upsertBoardCard({
    required String projectName,
    required String issue,
    required String message,
    required GitLabCardStatus status,
  }) async {
    if (!apiConnected) return;
    await _api.upsertBoardCard(
      projectName: projectName,
      issue: issue,
      message: message,
      status: status,
    );
  }

  Future<void> deleteBoardCard({
    required String projectName,
    required String columnId,
    required String cardId,
  }) async {
    if (!apiConnected) return;
    await _api.deleteBoardCard(
      projectName: projectName,
      columnId: columnId,
      cardId: cardId,
    );
  }

  Future<void> publishUpdate({
    required String projectName,
    required String issue,
    required String message,
    required GitLabCardStatus status,
  }) async {
    if (apiConnected) {
      final created = await _api.createActivity(
        projectName: projectName,
        issue: issue,
        message: message,
        status: status,
      );
      final i = activities.indexWhere((a) => a.projectName == projectName);
      if (i >= 0) {
        activities[i] = created;
      } else {
        activities.add(created);
      }
      return;
    }
    await _local.publishAndNotify(
      projectName: projectName,
      issue: issue,
      message: message,
      status: status,
    );
    activities = List.from(_local.activities);
    telegramEnabled = _local.telegramEnabled;
  }
}
