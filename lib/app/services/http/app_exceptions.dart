/// Exceção padronizada para todas as operações HTTP.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Object? originalError;

  const ApiException({
    this.statusCode,
    required this.message,
    this.originalError,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}
