import 'package:dio/dio.dart';

/// Injeta headers customizados em requisições.
class AuthInterceptor extends Interceptor {
  final Map<String, String> headers;

  AuthInterceptor(this.headers);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    for (final entry in headers.entries) {
      options.headers[entry.key] = entry.value;
    }
    handler.next(options);
  }
}
