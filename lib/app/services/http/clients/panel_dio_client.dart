import 'package:dio/dio.dart';

import '../../../config/api_config.dart';
import '../interceptors/auth_interceptor.dart';
import '../interceptors/error_interceptor.dart';
import '../interceptors/log_interceptor.dart';

/// Singleton Dio client para Panel API.
class PanelDioClient {
  static final PanelDioClient _instance = PanelDioClient._();

  late final Dio dio;

  factory PanelDioClient() => _instance;

  PanelDioClient._() {
    final baseUrl = panelApiBaseUrl.replaceAll(RegExp(r'/+$'), '');

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Adiciona interceptors na ordem: auth -> log -> error
    dio.interceptors.addAll([
      AuthInterceptor({}), // Panel sem autenticação por enquanto
      AppLogInterceptor(),
      AppErrorInterceptor(),
    ]);
  }

  /// Retorna uma opção de timeout customizado por endpoint.
  Options _optionsWithTimeout(Duration timeout) => Options(
        receiveTimeout: timeout,
      );

  /// Timeout para health check (5s).
  Options get healthTimeout => _optionsWithTimeout(const Duration(seconds: 5));

  /// Timeout para operações padrão (10s).
  Options get defaultTimeout => _optionsWithTimeout(const Duration(seconds: 10));

  /// Timeout para operações de escrita (15s).
  Options get writeTimeout => _optionsWithTimeout(const Duration(seconds: 15));
}
