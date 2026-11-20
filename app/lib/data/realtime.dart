import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// Một sự kiện realtime từ server.
class RtEvent {
  RtEvent(this.method, this.data);
  final String method;
  final Map<String, dynamic> data;
}

/// Kết nối SignalR tới /hubs/chat và /hubs/notifications (tự kết nối lại khi rớt mạng).
class Realtime extends ChangeNotifier {
  HubConnection? _chat;
  HubConnection? _notify;
  final _events = StreamController<RtEvent>.broadcast();
  final Set<String> online = {};

  Stream<RtEvent> get events => _events.stream;
  bool get connected => _notify?.state == HubConnectionState.Connected;

  static const _chatMethods = ['MessageReceived', 'MessageRead', 'Typing', 'ConversationCreated'];
  static const _notifyMethods = ['Notification', 'PostCreated', 'SyncHint', 'PresenceChanged'];

  Future<void> connect(String baseUrl, Future<String> Function() token) async {
    await disconnect();
    HubConnection build(String path) => HubConnectionBuilder()
        .withUrl('$baseUrl$path', options: HttpConnectionOptions(accessTokenFactory: token))
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 20000, 30000])
        .build();

    _chat = build('/hubs/chat');
    _notify = build('/hubs/notifications');
    for (final m in _chatMethods) {
      _chat!.on(m, (args) => _emit(m, args));
    }
    for (final m in _notifyMethods) {
      _notify!.on(m, (args) => _emit(m, args));
    }
    for (final c in [_chat!, _notify!]) {
      c.onreconnected(({connectionId}) => notifyListeners());
      c.onclose(({error}) => notifyListeners());
    }
    try {
      await Future.wait([_chat!.start()!, _notify!.start()!]);
    } catch (e) {
      debugPrint('SignalR: $e');
    }
    notifyListeners();
  }

  void _emit(String method, List<Object?>? args) {
    final raw = args != null && args.isNotEmpty ? args.first : null;
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    if (method == 'PresenceChanged') {
      final id = data['userId'] as String?;
      if (id != null) data['isOnline'] == true ? online.add(id) : online.remove(id);
      notifyListeners();
    }
    _events.add(RtEvent(method, data));
  }

  Future<void> disconnect() async {
    final c = _chat, n = _notify;
    _chat = _notify = null;
    try {
      await c?.stop();
      await n?.stop();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> joinConversation(String id) async {
    if (_chat?.state == HubConnectionState.Connected) await _chat!.invoke('JoinConversation', args: [id]);
  }

  Future<void> leaveConversation(String id) async {
    if (_chat?.state == HubConnectionState.Connected) await _chat!.invoke('LeaveConversation', args: [id]);
  }

  Future<void> typing(String conversationId, bool isTyping) async {
    if (_chat?.state == HubConnectionState.Connected) {
      await _chat!.send('Typing', args: [conversationId, isTyping]);
    }
  }
}
