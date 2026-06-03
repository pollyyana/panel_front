import 'dart:io';

import '../gitlab_status.dart';
import '../models/activity_notification.dart';
import 'http/clients/telegram_dio_client.dart';
import 'panel_api_client.dart';

/// Envia mensagens via API do Telegram usando config em botMessage/.
class TelegramNotifier {
  TelegramNotifier({String? botMessageRoot})
      : _root = botMessageRoot ?? _defaultRoot;

  static const _defaultRoot = '/home/polly/botMessage';

  final String _root;

  File get _enabledFlag => File('$_root/.telegram_enabled');
  File get _envFile => File('$_root/.telegram.env');

  bool get isEnabled => _enabledFlag.existsSync();

  Future<Map<String, String>?> _loadEnv() async {
    if (!await _envFile.exists()) return null;
    final map = <String, String>{};
    for (final line in await _envFile.readAsLines()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final i = trimmed.indexOf('=');
      if (i <= 0) continue;
      map[trimmed.substring(0, i).trim()] = trimmed.substring(i + 1).trim();
    }
    return map;
  }

  File get _projectsFilterFile => File('$_root/.telegram_notify_projects');

  /// `true` se não há filtro ou o projeto está na lista / modo `all`.
  bool shouldNotifyProject(String projectName) {
    final fromEnv = Platform.environment['TELEGRAM_NOTIFY_PROJECTS'];
    if (fromEnv != null && fromEnv.trim().isNotEmpty) {
      return _matchesFilter(fromEnv, projectName);
    }
    if (!_projectsFilterFile.existsSync()) return true;
    final lines = _projectsFilterFile
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return true;
    if (lines.length == 1 &&
        (lines.first.toLowerCase() == 'all' || lines.first == '*')) {
      return true;
    }
    final low = projectName.toLowerCase();
    return lines.any((l) => l.toLowerCase() == low);
  }

  bool _matchesFilter(String raw, String projectName) {
    final v = raw.trim().toLowerCase().replaceAll(' ', '');
    if (v == 'all' || v == '*') return true;
    final parts = raw.split(RegExp(r'[,;\s]+')).map((s) => s.trim()).where((s) => s.isNotEmpty);
    final low = projectName.toLowerCase();
    return parts.any((p) => p.toLowerCase() == low);
  }

  /// Mensagem HTML no mesmo formato de [panel_notify.sh] e do card do painel.
  static String formatMessage(ActivityNotification n) {
    final emoji = _emojiForStatus(n.status);
    final label = n.status.labelPt;
    final subtitle = _escapeHtml('${n.status.apiValue} · ${n.status.source.name}');
    final tag = _escapeHtml(
      (n.eventTag != null && n.eventTag!.isNotEmpty)
          ? n.eventTag!
          : _sourceLabelPt(statusSourceToApi(n.status.source)),
    );
    final project = _escapeHtml(n.projectName);
    final issueLine = _escapeHtml(_issueLine(n.issue, n.message, label));

    final buf = StringBuffer()
      ..write('$emoji <b>$tag</b> · <b>$project</b>')
      ..write('\n$issueLine');

    final sha = n.commitSha?.trim();
    if (sha != null && sha.isNotEmpty) {
      buf.write('\n<code>${_escapeHtml(sha)}</code>');
    }

    final body = _bodyLine(n, label);
    if (body.isNotEmpty) {
      buf.write('\n${_escapeHtml(body)}');
    }

    final kind = n.issueKind?.trim();
    if (kind != null && kind.isNotEmpty) {
      buf.write('\n<b>${_escapeHtml(kind)}</b>');
    }

    buf
      ..write('\n<b>${_escapeHtml(label)}</b>')
      ..write('\n$subtitle');

    return buf.toString();
  }

  static String _issueLine(String issue, String message, String statusLabel) {
    final i = issue.trim();
    final m = message.trim();
    if (m.isEmpty || i.contains(m)) return i;
    final detail = _detailLine(m, statusLabel);
    if (detail.isEmpty) return i;
    if (i.contains(detail)) return i;
    return '$i — $detail';
  }

  static String _bodyLine(ActivityNotification n, String statusLabel) {
    final commit = n.commitMessage?.trim();
    if (commit != null && commit.isNotEmpty) return commit;
    final desc = n.issueDescription?.trim();
    if (desc != null && desc.isNotEmpty) return desc;
    return _detailLine(n.message, statusLabel);
  }

  static String _detailLine(String message, String statusLabel) {
    var trimmed = message.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.toLowerCase() == statusLabel.toLowerCase()) return '';

    for (final sep in [' · ', ' - ', ' — ']) {
      for (final suffix in [statusLabel, statusLabel.toLowerCase()]) {
        if (trimmed.endsWith('$sep$suffix')) {
          trimmed = trimmed.substring(0, trimmed.length - sep.length - suffix.length).trim();
          break;
        }
      }
    }
    if (trimmed.isEmpty || trimmed.toLowerCase() == statusLabel.toLowerCase()) {
      return '';
    }
    return trimmed;
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  static String _sourceLabelPt(String source) {
    return switch (source) {
      'pipeline' => 'Pipeline',
      'job' => 'Job',
      'merge_request' => 'Merge request',
      'issue' => 'Issue',
      _ => source,
    };
  }

  static String _emojiForStatus(GitLabCardStatus status) {
    final ci = status.ci;
    if (ci != null) {
      return switch (ci) {
        GitLabCiStatus.success => '✅',
        GitLabCiStatus.failed => '❌',
        GitLabCiStatus.running => '🔄',
        GitLabCiStatus.pending ||
        GitLabCiStatus.created ||
        GitLabCiStatus.preparing ||
        GitLabCiStatus.waitingForResource =>
          '⏳',
        GitLabCiStatus.canceled || GitLabCiStatus.skipped => '⏸️',
        GitLabCiStatus.manual => '📋',
        GitLabCiStatus.unknown => '📋',
      };
    }
    final mr = status.mr;
    if (mr != null) {
      return switch (mr) {
        GitLabMrState.merged => '✅',
        GitLabMrState.opened => '🔀',
        GitLabMrState.closed => '⏸️',
        GitLabMrState.locked => '⏳',
        GitLabMrState.unknown => '📋',
      };
    }
    final issue = status.issue;
    if (issue != null) {
      return switch (issue) {
        GitLabIssueState.opened => '📌',
        GitLabIssueState.closed => '✔️',
        GitLabIssueState.reopened => '🔄',
        GitLabIssueState.updated => '✏️',
        GitLabIssueState.unknown => '📋',
      };
    }
    return '📋';
  }

  /// Tenta enviar via script bash (desktop/Linux) ou HTTP direto.
  Future<bool> notifyActivity(ActivityNotification notification) async {
    if (!isEnabled) return false;
    if (!shouldNotifyProject(notification.projectName)) return false;

    final message = formatMessage(notification);
    if (await _notifyViaShell(notification)) return true;
    return _notifyViaHttp(message);
  }

  Future<bool> _notifyViaShell(ActivityNotification notification) async {
    final script = File('$_root/panel_notify.sh');
    if (!Platform.isLinux && !Platform.isMacOS) return false;
    if (!await script.exists()) return false;

    try {
      final result = await Process.run(
        'bash',
        [
          script.path,
          notification.projectName,
          notification.issue,
          notification.status.apiValue,
          notification.message,
          statusSourceToApi(notification.status.source),
          notification.commitSha ?? '',
          notification.commitMessage ?? '',
          notification.issueKind ?? '',
          notification.issueDescription ?? '',
          notification.eventTag ?? '',
        ],
        runInShell: false,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _notifyViaHttp(String message) async {
    final env = await _loadEnv();
    if (env == null) return false;

    final token = env['TELEGRAM_BOT_TOKEN'];
    final chatId = env['TELEGRAM_CHAT_ID'];
    if (token == null ||
        token.isEmpty ||
        chatId == null ||
        chatId.isEmpty) {
      return false;
    }

    // Retry: máximo 2 tentativas adicionais (3 tentativas no total)
    int attempts = 0;
    const maxRetries = 2;
    const retryDelaySeconds = 3;

    while (attempts <= maxRetries) {
      try {
        final client = TelegramDioClient().dio;
        final response = await client.post(
          '/sendMessage',
          data: {
            'chat_id': chatId,
            'text': message,
            'parse_mode': 'HTML',
          },
          options: TelegramDioClient().defaultTimeout,
        );
        
        final json = response.data as Map<String, dynamic>;
        if (json['ok'] == true) {
          return true;
        }
        return false;
      } catch (e) {
        attempts++;
        if (attempts <= maxRetries) {
          await Future<void>.delayed(const Duration(seconds: retryDelaySeconds));
        } else {
          return false;
        }
      }
    }
    return false;
  }
}
