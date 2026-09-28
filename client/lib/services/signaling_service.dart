import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config.dart';

/// Owns the socket.io connection used for presence and WebRTC signaling.
class SignalingService extends ChangeNotifier {
  io.Socket? _socket;
  final Set<String> _onlineUserIds = {};
  bool _connected = false;

  bool get connected => _connected;
  Set<String> get onlineUserIds => Set.unmodifiable(_onlineUserIds);
  bool isOnline(String userId) => _onlineUserIds.contains(userId);

  final Map<String, void Function(Map<String, dynamic>)> _handlers = {};

  void on(String event, void Function(Map<String, dynamic>) handler) {
    _handlers[event] = handler;
    _socket?.on(event, (data) => handler(Map<String, dynamic>.from(data as Map)));
  }

  void connect(String accessToken) {
    disconnect();

    final socket = io.io(
      apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': accessToken})
          .build(),
    );

    socket.onConnect((_) {
      _connected = true;
      notifyListeners();
    });
    socket.onDisconnect((_) {
      _connected = false;
      _onlineUserIds.clear();
      notifyListeners();
    });

    socket.on('presence:snapshot', (data) {
      _onlineUserIds
        ..clear()
        ..addAll(List<String>.from((data as Map)['onlineUserIds'] as List));
      notifyListeners();
    });

    socket.on('presence:update', (data) {
      final map = data as Map;
      final userId = map['userId'] as String;
      (map['online'] as bool) ? _onlineUserIds.add(userId) : _onlineUserIds.remove(userId);
      notifyListeners();
    });

    _handlers.forEach((event, handler) {
      socket.on(event, (data) => handler(Map<String, dynamic>.from(data as Map)));
    });

    _socket = socket..connect();
  }

  void emit(String event, Map<String, dynamic> payload) => _socket?.emit(event, payload);

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connected = false;
    _onlineUserIds.clear();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
