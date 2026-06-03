import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Log centralizado de requisições e respostas (apenas em debug).
class AppLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('[→] ${options.method} ${options.path}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print('[←] ${response.statusCode} ${response.requestOptions.path}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      print('[✗] ${err.response?.statusCode ?? "?"} ${err.requestOptions.path} — ${err.message}');
    }
    handler.next(err);
  }
}
