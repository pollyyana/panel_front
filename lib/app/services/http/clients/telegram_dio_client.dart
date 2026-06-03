import 'package:dio/dio.dart';

import '../interceptors/error_interceptor.dart';
import '../interceptors/log_interceptor.dart';

/// Singleton Dio client para Telegram API.
class TelegramDioClient {
  static final TelegramDioClient _instance = TelegramDioClient._();

  late final Dio dio;

  factory TelegramDioClient() => _instance;

  TelegramDioClient._() {
    final token = const String.fromEnvironment('TELEGRAM_BOT_TOKEN', defaultValue: '');

    dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.telegram.org/bot$token',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    // Adiciona interceptors: log -> error
    dio.interceptors.addAll([
      AppLogInterceptor(),
      AppErrorInterceptor(),
    ]);
  }

  /// Timeout padrão para operações Telegram (10s).
  Options get defaultTimeout => Options(
        receiveTimeout: const Duration(seconds: 10),
      );
}
