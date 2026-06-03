import 'package:panel/app/gitlab_status.dart';


/// Evento global — mesmo feed em todos os projetos (webhook / push / Telegram).
class ActivityNotification {
  final String id;
  final String projectName;
  final String issue;
  final String message;
  final GitLabCardStatus status;
  final String timeAgo;
  final String? eventTag;
  final String? commitSha;
  final String? commitMessage;
  final String? issueKind;
  final String? issueDescription;

  const ActivityNotification({
    required this.id,
    required this.issue,
    required this.message,
    required this.projectName,
    required this.status,
    required this.timeAgo,
    this.eventTag,
    this.commitSha,
    this.commitMessage,
    this.issueKind,
    this.issueDescription,
  });
}
