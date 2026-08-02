import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/chat_message.dart';

/// Live-delivery layer on top of the REST messaging API (see [ChatService]).
/// REST is the source of truth — this only makes new messages, and typing
/// indicators, appear instantly while a thread is open; if it's disconnected
/// or the peer is offline, the message is already safely persisted via REST.
class SocketService {
  static const _url = 'https://familywatchtoday.com';

  io.Socket? _socket;

  void Function(ChatMessage message)? onMessage;
  void Function(String reason)? onSendError;
  void Function(Map<String, dynamic> data)? onTyping;
  void Function(Map<String, dynamic> data)? onStopTyping;

  bool get isConnected => _socket?.connected ?? false;

  /// Connects and registers [userId] so the server can address this socket
  /// directly. The server keys online users by this raw scalar value —
  /// emitting an object instead silently breaks addressing.
  void connect(int userId) {
    _socket = io.io(
      _url,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) => _socket!.emit('register', userId));

    _socket!.on('private_message', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final messageJson = Map<String, dynamic>.from(map['message'] as Map);
      final message = ChatMessage.fromJson(messageJson).copyWithIsMine(false);
      onMessage?.call(message);
    });

    _socket!.on('pm_error', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      onSendError?.call(map['reason'] as String? ?? 'unknown');
    });

    _socket!.on('isTyping', (data) => onTyping?.call(Map<String, dynamic>.from(data as Map)));
    _socket!.on('stopTyping', (data) => onStopTyping?.call(Map<String, dynamic>.from(data as Map)));

    _socket!.connect();
  }

  /// [to] must be the recipient's user id (not a patient_id).
  void sendPrivateMessage({required int to, required Map<String, dynamic> message}) {
    _socket?.emit('private_message', {'to': to, 'message': message});
  }

  void emitTyping({required int patientId, required int senderId}) {
    _socket?.emit('isTyping', {'patient_id': patientId, 'sender_id': senderId});
  }

  void emitStopTyping({required int patientId, required int senderId}) {
    _socket?.emit('stopTyping', {'patient_id': patientId, 'sender_id': senderId});
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
