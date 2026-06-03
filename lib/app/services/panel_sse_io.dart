import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

Stream<void> boardEventStream({
  required String baseUrl,
  void Function(bool connected)? onConnectionChanged,
}) async* {
  final root = baseUrl.replaceAll(RegExp(r'/+$'), '');
  int backoffSeconds = 1; // Backoff inicial: 1 segundo

  while (true) {
    http.Client? client;
    try {
      client = http.Client();
      final request = http.Request('GET', Uri.parse('$root/api/events/stream'))
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache';

      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw StateError('SSE ${response.statusCode}');
      }

      // Ao conectar com sucesso, reseta o backoff
      backoffSeconds = 1;
      onConnectionChanged?.call(true);
      yield null; // refresh ao conectar / reconectar
      var buffer = '';

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        while (buffer.contains('\n\n')) {
          final split = buffer.indexOf('\n\n');
          final block = buffer.substring(0, split);
          buffer = buffer.substring(split + 2);

          for (final line in block.split('\n')) {
            if (line.startsWith('data: ')) {
              yield null;
            }
          }
        }
      }
      onConnectionChanged?.call(false);
    } catch (_) {
      onConnectionChanged?.call(false);
      // Aguarda com backoff exponencial (máximo 30 segundos)
      await Future<void>.delayed(Duration(seconds: backoffSeconds));
      // Dobra o backoff para a próxima tentativa
      backoffSeconds = (backoffSeconds * 2).clamp(1, 30);
    } finally {
      client?.close();
    }
  }
}
