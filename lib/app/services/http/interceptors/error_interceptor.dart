import 'package:dio/dio.dart';

import '../app_exceptions.dart';

/// Mapeia exceções Dio para ApiException com mensagens descritivas.
class AppErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final apiException = _mapDioException(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: apiException,
      ),
    );
  }

  ApiException _mapDioException(DioException err) {
    final message = _getErrorMessage(err);
    return ApiException(
      statusCode: err.response?.statusCode,
      message: message,
      originalError: err.error,
    );
  }

  String _getErrorMessage(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Tempo limite excedido';
      case DioExceptionType.connectionError:
        return 'Sem conexão com o servidor';
      case DioExceptionType.badResponse:
        return _getBadResponseMessage(err.response?.statusCode, err.response?.data);
      default:
        return 'Erro desconhecido';
    }
  }

  String _getBadResponseMessage(int? statusCode, dynamic responseData) {
    final body = _extractErrorBody(responseData);
    switch (statusCode) {
      case 401:
        return 'Não autorizado';
      case 403:
        return 'Acesso negado';
      case 404:
        return 'Recurso não encontrado';
      case 500:
        return 'Erro interno do servidor';
      default:
        return 'Erro inesperado ($statusCode)${body.isNotEmpty ? ': $body' : ''}';
    }
  }

  String _extractErrorBody(dynamic responseData) {
    if (responseData is String) {
      return responseData.length > 100 ? responseData.substring(0, 100) : responseData;
    }
    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'] ?? responseData['error'] ?? '';
      return message.toString();
    }
    return '';
  }
}
