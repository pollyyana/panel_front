import '../gitlab_status.dart';
import '../models/activity_notification.dart';
import 'telegram_notifier.dart';

/// Centraliza o feed de atividade e dispara Telegram em cada atualização.
class PanelActivityService {
  PanelActivityService({TelegramNotifier? telegram})
      : _telegram = telegram ?? TelegramNotifier();

  final TelegramNotifier _telegram;
  final List<ActivityNotification> activities = [];
  int _nextId = 1;

  bool get telegramEnabled => _telegram.isEnabled;

  /// Registra no feed e notifica o Telegram (se `.telegram_enabled` existir).
  Future<void> publish({
    required String projectName,
    required String issue,
    required String message,
    required GitLabCardStatus status,
  }) async {
    final notification = ActivityNotification(
      id: 'n${_nextId++}',
      projectName: projectName,
      issue: issue,
      message: message,
      status: status,
      timeAgo: 'agora',
    );

    final i = activities.indexWhere((a) => a.projectName == projectName);
    if (i >= 0) {
      activities[i] = notification;
    } else {
      activities.add(notification);
    }
  }

  Future<bool> publishAndNotify({
    required String projectName,
    required String issue,
    required String message,
    required GitLabCardStatus status,
  }) async {
    await publish(
      projectName: projectName,
      issue: issue,
      message: message,
      status: status,
    );
    return _telegram.notifyActivity(activities.first);
  }

  List<ActivityNotification> seedMockData() {
    activities
      ..clear()
      ..addAll([
        ActivityNotification(
          id: 'n1',
          projectName: 'panel',
          issue: '#142',
          message: 'Pipeline concluído: deploy em staging OK.',
          status: GitLabCardStatus.pipeline(GitLabCiStatus.success),
          timeAgo: 'agora',
        ),
        ActivityNotification(
          id: 'n2',
          projectName: 'log',
          issue: '#89',
          message: 'Job "test:unit" falhou — 3 testes quebrados.',
          status: GitLabCardStatus.job(GitLabCiStatus.failed),
          timeAgo: '2 min',
        ),
        ActivityNotification(
          id: 'n3',
          projectName: 'farm',
          issue: '#56',
          message: 'MR aprovado por @devops — aguardando merge.',
          status: GitLabCardStatus.mergeRequest(GitLabMrState.opened),
          timeAgo: '8 min',
        ),
      ]);
    _nextId = 10;
    return activities;
  }
}
