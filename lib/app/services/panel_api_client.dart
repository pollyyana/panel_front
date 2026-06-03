import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../gitlab_status.dart';
import '../models/activity_notification.dart';
import 'http/app_exceptions.dart';
import 'http/clients/panel_dio_client.dart';
import 'panel_api_models.dart';
import 'panel_sse.dart' as panel_sse;

class PanelApiClient {
  PanelApiClient({PanelDioClient? dioClient})
      : _dio = (dioClient ?? PanelDioClient()).dio;

  final Dio _dio;

  Future<void> health() async {
    try {
      await _dio.get(
        '/health',
        options: PanelDioClient().healthTimeout,
      );
    } catch (e) {
      if (e is DioException && e.error is ApiException) {
        final apiException = e.error as ApiException;
        throw PanelApiException(apiException.statusCode ?? 0, apiException.message);
      }
      rethrow;
    }
  }

  Future<ApiProject> addProject({
    required String gitlabUrl,
    String? name,
  }) async {
    try {
      final response = await _dio.post(
        '/api/projects',
        data: {
          'gitlabUrl': gitlabUrl,
          if (name != null && name.isNotEmpty) 'name': name,
        },
        options: PanelDioClient().writeTimeout,
      );
      return ApiProject.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is DioException && e.error is ApiException) {
        final apiException = e.error as ApiException;
        throw PanelApiException(apiException.statusCode ?? 0, apiException.message);
      }
      rethrow;
    }
  }

  Future<List<ApiProject>> fetchProjects() async {
    try {
      final response = await _dio.get(
        '/api/projects',
        options: PanelDioClient().defaultTimeout,
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => ApiProject.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is DioException && e.error is ApiException) {
        final apiException = e.error as ApiException;
        throw PanelApiException(apiException.statusCode ?? 0, apiException.message);
      }
      rethrow;
    }
  }

  Future<List<ActivityNotification>> fetchActivities() async {
    try {
      final response = await _dio.get(
        '/api/activities',
        options: PanelDioClient().defaultTimeout,
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => activityFromApiJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is DioException && e.error is ApiException) {
        final apiException = e.error as ApiException;
        throw PanelApiException(apiException.statusCode ?? 0, apiException.message);
      }
      rethrow;
    }
  }

  Future<ActivityNotification> createActivity({
    required String projectName,
    required String issue,
    required String message,
    required GitLabCardStatus status,
  }) async {
    try {
      final response = await _dio.post(
        '/api/activities',
        data: {
          'projectName': projectName,
          'issue': issue,
          'message': message,
          'statusApi': status.apiValue,
          'statusSource': statusSourceToApi(status.source),
        },
        options: PanelDioClient().writeTimeout,
      );
      return activityFromApiJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is DioException && e.error is ApiException) {
        final apiException = e.error as ApiException;
        throw PanelApiException(apiException.statusCode ?? 0, apiException.message);
      }
      rethrow;
    }
  }

  Future<void> upsertBoardCard({
    required String projectName,
    required String issue,
    required String message,
    required GitLabCardStatus status,
  }) async {
    try {
      await _dio.post(
        '/api/board/cards',
        data: {
          'projectName': projectName,
          'issue': issue,
          'message': message,
          'statusApi': status.apiValue,
          'statusSource': statusSourceToApi(status.source),
        },
        options: PanelDioClient().defaultTimeout,
      );
    } catch (e) {
      if (e is DioException && e.error is ApiException) {
        final apiException = e.error as ApiException;
        throw PanelApiException(apiException.statusCode ?? 0, apiException.message);
      }
      rethrow;
    }
  }

  Future<void> deleteBoardCard({
    required String projectName,
    required String columnId,
    required String cardId,
  }) async {
    try {
      await _dio.delete(
        '/api/board/cards',
        queryParameters: {
          'project': projectName,
          'column': columnId,
          'card': cardId,
        },
        options: PanelDioClient().defaultTimeout,
      );
    } catch (e) {
      if (e is DioException && e.error is ApiException) {
        final apiException = e.error as ApiException;
        throw PanelApiException(apiException.statusCode ?? 0, apiException.message);
      }
      rethrow;
    }
  }

  Future<bool> fetchTelegramEnabled() async {
    try {
      final response = await _dio.get(
        '/api/telegram/status',
        options: PanelDioClient().healthTimeout,
      );
      final json = response.data as Map<String, dynamic>;
      return json['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncWebhookSecret(String secret) async {
    try {
      await _dio.put(
        '/api/gitlab/webhook-secret',
        data: {'secret': secret},
        options: PanelDioClient().defaultTimeout,
      );
    } catch (e) {
      if (e is DioException && e.error is ApiException) {
        final apiException = e.error as ApiException;
        throw PanelApiException(apiException.statusCode ?? 0, apiException.message);
      }
      rethrow;
    }
  }

  Future<GitlabSetupInfo> fetchGitlabSetup() async {
    try {
      final response = await _dio.get(
        '/api/gitlab/setup',
        options: PanelDioClient().healthTimeout,
      );
      return GitlabSetupInfo.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is DioException && e.error is ApiException) {
        final apiException = e.error as ApiException;
        throw PanelApiException(apiException.statusCode ?? 0, apiException.message);
      }
      rethrow;
    }
  }

  /// SSE em tempo real — emite a cada evento GitLab / alteração no quadro.
  Stream<void> boardEventStream({
    void Function(bool connected)? onConnectionChanged,
  }) {
    final baseUrl = panelApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return panel_sse.boardEventStream(
      baseUrl: baseUrl,
      onConnectionChanged: onConnectionChanged,
    );
  }
}

String statusSourceToApi(GitLabStatusSource source) {
  return switch (source) {
    GitLabStatusSource.pipeline => 'pipeline',
    GitLabStatusSource.job => 'job',
    GitLabStatusSource.mergeRequest => 'merge_request',
    GitLabStatusSource.issue => 'issue',
  };
}

GitLabStatusSource statusSourceFromApi(String? raw) {
  switch (raw) {
    case 'job':
      return GitLabStatusSource.job;
    case 'merge_request':
      return GitLabStatusSource.mergeRequest;
    case 'issue':
    case 'work_item':
      return GitLabStatusSource.issue;
    default:
      return GitLabStatusSource.pipeline;
  }
}

ActivityNotification activityFromApiJson(Map<String, dynamic> json) {
  final statusApi = json['statusApi'] as String? ?? 'unknown';
  final statusSrc = json['statusSource'] as String? ?? 'pipeline';
  return ActivityNotification(
    id: json['id'] as String? ?? '',
    projectName: json['projectName'] as String? ?? '',
    issue: json['issue'] as String? ?? '',
    message: json['message'] as String? ?? '',
    status: GitLabCardStatus.fromApi(
      statusApi,
      source: statusSourceFromApi(statusSrc),
    ),
    timeAgo: json['timeAgo'] as String? ?? '',
    eventTag: json['eventTag'] as String?,
    commitSha: json['commitSha'] as String?,
    commitMessage: json['commitMessage'] as String?,
    issueKind: json['issueKind'] as String?,
    issueDescription: json['issueDescription'] as String?,
  );
}

class PanelApiException implements Exception {
  PanelApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'PanelApiException($statusCode): $body';
}

class WebhookStatusInfo {
  final bool lastOk;
  final int lastHttp;
  final String? lastMessage;
  final String? lastAt;
  final String? lastKind;
  final int secretLength;
  final bool overrideActive;

  WebhookStatusInfo({
    required this.lastOk,
    this.lastHttp = 0,
    this.lastMessage,
    this.lastAt,
    this.lastKind,
    this.secretLength = 0,
    this.overrideActive = false,
  });

  factory WebhookStatusInfo.fromJson(Map<String, dynamic> json) {
    return WebhookStatusInfo(
      lastOk: json['lastOk'] == true,
      lastHttp: json['lastHttp'] as int? ?? 0,
      lastMessage: json['lastMessage'] as String?,
      lastAt: json['lastAt'] as String?,
      lastKind: json['lastKind'] as String?,
      secretLength: json['secretLength'] as int? ?? 0,
      overrideActive: json['overrideActive'] == true,
    );
  }

  bool get needsSecretFix => !lastOk && lastHttp == 401;
}

class GitlabSetupInfo {
  final String webhookPath;
  final List<String> events;
  final bool secretConfigured;
  final String? publicBaseUrl;
  final String? flowHint;
  final WebhookStatusInfo? webhook;

  GitlabSetupInfo({
    required this.webhookPath,
    required this.events,
    required this.secretConfigured,
    this.publicBaseUrl,
    this.flowHint,
    this.webhook,
  });

  factory GitlabSetupInfo.fromJson(Map<String, dynamic> json) {
    final wh = json['webhook'];
    return GitlabSetupInfo(
      webhookPath: json['webhookPath'] as String? ?? '/api/webhooks/gitlab',
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      secretConfigured: json['secretConfigured'] == true,
      publicBaseUrl: json['publicBaseUrl'] as String?,
      flowHint: json['flowHint'] as String?,
      webhook: wh is Map<String, dynamic>
          ? WebhookStatusInfo.fromJson(wh)
          : null,
    );
  }

  String webhookUrl(String apiBase) {
    final base = (publicBaseUrl?.isNotEmpty == true)
        ? publicBaseUrl!
        : apiBase.replaceAll(RegExp(r'/+$'), '');
    return '$base$webhookPath';
  }
}
