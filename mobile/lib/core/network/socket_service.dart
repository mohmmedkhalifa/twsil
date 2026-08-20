import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../config.dart';
import 'api_client.dart';

/// Realtime channel to the NestJS Socket.io gateway.
/// One connection per app session; auto-reconnects when the network drops.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  socket_io.Socket? _socket;
  final _listeners = <String, List<Function(dynamic)>>{};
  bool _connecting = false;

  bool get isConnected => _socket?.connected == true;

  void connect() {
    final token = ApiClient.instance.token;
    if (token.isEmpty) return;
    if (_socket != null && (_socket!.connected || _connecting)) return;

    _connecting = true;
    _socket = socket_io.io(
      socketBaseUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .build(),
    );

    _socket!.onConnect((_) {
      _connecting = false;
      // Re-register local listeners on a reconnect (socket_io_client 3.x
      // keeps `on` callbacks, but re-attaching is harmless).
      for (final entry in _listeners.entries) {
        for (final cb in entry.value) {
          _socket!.on(entry.key, (data) => cb(data));
        }
      }
    });

    _socket!.onConnectError((_) {
      _connecting = false;
    });

    _socket!.onDisconnect((_) {
      _connecting = false;
    });

    _socket!.onAny((event, data) {
      triggerEvent(event, data);
    });
  }

  void on(String event, Function(dynamic) callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
    if (_socket != null) {
      _socket!.on(event, (data) => callback(data));
    }
  }

  void off(String event) {
    _listeners.remove(event);
    _socket?.off(event);
  }

  void emit(String event, Map<String, dynamic> data) {
    if (event == 'tracking:update') {
      final orderId = data['orderId'] as String?;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (orderId != null && lat != null && lng != null) {
        ApiClient.instance.patch('/orders/$orderId/location', body: {'lat': lat, 'lng': lng});
      }
    }
    if (_socket != null && _socket!.connected) {
      _socket!.emit(event, data);
    }
  }

  void joinOrder(String orderId) => emit('order:join', {'orderId': orderId});

  void joinConversation(String conversationId) =>
      emit('chat:join', {'conversationId': conversationId});

  void sendTracking(String orderId, double lat, double lng) =>
      emit('tracking:update', {'orderId': orderId, 'lat': lat, 'lng': lng});

  void sendTyping(String conversationId, bool typing) =>
      emit('chat:typing', {'conversationId': conversationId, 'typing': typing});

  void triggerEvent(String event, dynamic data) {
    final callbacks = _listeners[event];
    if (callbacks != null) {
      for (final cb in List.of(callbacks)) {
        cb(data);
      }
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connecting = false;
    _listeners.clear();
  }

  void dispose() {
    disconnect();
  }
}