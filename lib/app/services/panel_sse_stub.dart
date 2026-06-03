import 'dart:async';

Stream<void> boardEventStream({
  required String baseUrl,
  void Function(bool connected)? onConnectionChanged,
}) {
  onConnectionChanged?.call(false);
  return const Stream.empty();
}
