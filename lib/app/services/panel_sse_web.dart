import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

Stream<void> boardEventStream({
  required String baseUrl,
  void Function(bool connected)? onConnectionChanged,
}) {
  final root = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final controller = StreamController<void>();

  html.EventSource? source;
  Timer? retry;
  StreamSubscription<html.Event>? openSub;
  StreamSubscription<html.MessageEvent>? messageSub;
  StreamSubscription<html.Event>? errorSub;
  void Function(html.Event)? boardHandler;

  void emitUpdate() {
    if (!controller.isClosed) controller.add(null);
  }

  void setConnected(bool connected) {
    debugPrint('[panel] SSE conexão: $connected');
    onConnectionChanged?.call(connected);
    if (connected) emitUpdate();
  }

  void teardown() {
    openSub?.cancel();
    messageSub?.cancel();
    errorSub?.cancel();
    openSub = null;
    messageSub = null;
    errorSub = null;
    if (source != null && boardHandler != null) {
      source!.removeEventListener('board_update', boardHandler);
    }
    boardHandler = null;
    source?.close();
    source = null;
  }

  void connect() {
    retry?.cancel();
    teardown();

    source = html.EventSource('$root/api/events/stream');
    final es = source!;

    openSub = es.onOpen.listen((_) => setConnected(true));

    messageSub = es.onMessage.listen((event) {
      final data = event.data;
      if (data != null && data.toString().isNotEmpty) {
        final preview = data.toString();
        debugPrint(
          '[panel] SSE onMessage: ${preview.length > 120 ? '${preview.substring(0, 120)}…' : preview}',
        );
        emitUpdate();
      }
    });

    boardHandler = (html.Event event) {
      debugPrint('[panel] SSE board_update event');
      if (event is html.MessageEvent) {
        final data = event.data;
        if (data != null && data.toString().isNotEmpty) {
          emitUpdate();
          return;
        }
      }
      emitUpdate();
    };
    es.addEventListener('board_update', boardHandler);

    errorSub = es.onError.listen((_) {
      setConnected(false);
      teardown();
      retry = Timer(const Duration(seconds: 2), connect);
    });
  }

  connect();

  controller.onCancel = () {
    retry?.cancel();
    teardown();
    onConnectionChanged?.call(false);
  };

  return controller.stream;
}
