import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/app_constants.dart';
import '../models/awareness_event.dart';

abstract class AwarenessSocket {
  Stream<AwarenessEvent> get events;
  Stream<Map<String, String>> get models;
  Stream<void> get closed;
  Future<void> connect(String backend);
  void sendFrame(Uint8List jpeg);
  void sendAudio(Uint8List pcm16, {int channels});
  void requestStatus();
  Future<void> close();
}

class WsClient implements AwarenessSocket {
  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  final _events = StreamController<AwarenessEvent>.broadcast();
  final _models = StreamController<Map<String, String>>.broadcast();
  final _closed = StreamController<void>.broadcast();
  bool _open = false;

  @override
  Stream<AwarenessEvent> get events => _events.stream;
  @override
  Stream<Map<String, String>> get models => _models.stream;
  @override
  Stream<void> get closed => _closed.stream;

  static Uri buildUri(String backend) {
    var s = backend.trim();
    if (s.startsWith('http://')) s = 'ws://${s.substring(7)}';
    if (s.startsWith('https://')) s = 'wss://${s.substring(8)}';
    if (!s.startsWith('ws://') && !s.startsWith('wss://')) s = 'ws://$s';
    final u = Uri.parse(s);
    return (u.path.isEmpty || u.path == '/') ? u.replace(path: '/ws/awareness') : u;
  }

  @override
  Future<void> connect(String backend) async {
    await close();
    final ch = WebSocketChannel.connect(buildUri(backend));
    _ch = ch;
    await ch.ready.timeout(AppConstants.connectTimeout);
    _open = true;
    _sub = ch.stream.listen(_onMessage, onDone: _onClosed, onError: (_) => _onClosed());
  }

  void _onClosed() {
    if (_open) {
      _open = false;
      _closed.add(null);
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final m = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (m['type']) {
        case 'events':
          for (final e in (m['events'] as List)) {
            _events.add(AwarenessEvent.fromJson(Map<String, dynamic>.from(e as Map)));
          }
          break;
        case 'ready':
        case 'status':
          final models = (m['models'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString()));
          if (models != null) _models.add(models);
          break;
      }
    } catch (_) {
      // ignore malformed server messages
    }
  }

  void _send(Map<String, dynamic> m) {
    if (!_open) return;
    try {
      _ch?.sink.add(jsonEncode(m));
    } catch (_) {}
  }

  @override
  void sendFrame(Uint8List jpeg) => _send({'type': 'frame', 'data': base64Encode(jpeg)});

  @override
  void sendAudio(Uint8List pcm16, {int channels = 1}) =>
      _send({'type': 'audio', 'data': base64Encode(pcm16), 'channels': channels});

  @override
  void requestStatus() => _send({'type': 'status'});

  @override
  Future<void> close() async {
    _open = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _ch?.sink.close();
    } catch (_) {}
    _ch = null;
  }
}
