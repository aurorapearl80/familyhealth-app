import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_channel.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'auth_service.dart';

/// The result of a successful group-chat send: [mine] is the sender's own copy
/// (for optimistic UI), [recipients] is what to loop over when relaying the
/// message live over the socket — the channel relay has no server-side fan-out.
class ChannelSendResult {
  final ChatMessage mine;
  final List<ChannelRecipientMessage> recipients;
  const ChannelSendResult({required this.mine, required this.recipients});
}

class ChannelRecipientMessage {
  final int recipientId;
  final ChatMessage message;
  const ChannelRecipientMessage({required this.recipientId, required this.message});
}

/// Backs the chat list (admin) and message thread screens against the
/// real messaging API documented in the "Chat API Reference".
class ChatService extends ChangeNotifier {
  static const _base = 'https://familywatchtoday.com/api';

  List<Conversation> _conversations = [];
  List<ChatMessage> _messages = [];
  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;
  String? _error;

  List<ChatChannel> _channels = [];
  List<ChatMessage> _channelMessages = [];
  bool _isLoadingChannels = false;
  bool _isLoadingChannelMessages = false;
  int _totalChannelUnreadCount = 0;
  String? _channelError;
  String? _channelMessagesError;

  List<Conversation> get conversations => _conversations;
  List<ChatMessage> get messages => _messages;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get error => _error;

  List<ChatChannel> get channels => _channels;
  List<ChatMessage> get channelMessages => _channelMessages;
  bool get isLoadingChannels => _isLoadingChannels;
  bool get isLoadingChannelMessages => _isLoadingChannelMessages;
  int get totalChannelUnreadCount => _totalChannelUnreadCount;
  String? get channelError => _channelError;
  String? get channelMessagesError => _channelMessagesError;

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  /// Some endpoints may return a bare list, others `{ data: [...] }` — accept both.
  List<dynamic> _asList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic> && decoded['data'] is List) {
      return decoded['data'] as List<dynamic>;
    }
    return const [];
  }

  /// A 200 with a non-JSON body (HTML login page, SPA fallback, etc.) means the
  /// request didn't actually reach the API as an authenticated JSON call — decoding
  /// that as JSON throws a cryptic FormatException, so detect it up front instead.
  dynamic _decodeJsonOrThrow(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('json')) {
      final snippet = response.body.trim().substring(0, response.body.trim().length.clamp(0, 200));
      debugPrint('[ChatService] non-JSON response (status=${response.statusCode}, '
          'content-type=$contentType): $snippet');
      throw FormatException(
          'Server returned ${response.statusCode} with content-type "$contentType" instead of JSON '
          '— likely an auth redirect or missing route, not the documented API response.');
    }
    return jsonDecode(response.body);
  }

  /// Admin-only: every patient conversation with a last-message preview + unread count.
  Future<void> fetchConversations() async {
    _isLoadingConversations = true;
    _error = null;
    notifyListeners();
    try {
      final response = await http
          .get(Uri.parse('$_base/admin/messaging/conversations'), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        _conversations = _asList(_decodeJsonOrThrow(response))
            .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 403) {
        _error = 'Admin access required to view conversations.';
      } else {
        _error = 'Failed to load conversations (${response.statusCode})';
      }
    } catch (e) {
      _error = e is FormatException ? e.message : 'Network error: $e';
      debugPrint('[ChatService] fetchConversations error: $e');
    }
    _isLoadingConversations = false;
    notifyListeners();
  }

  /// Loads a thread. Admins pass [patientId]; patients omit it (auto-resolved server-side).
  Future<void> fetchMessages({required bool isAdmin, int? patientId}) async {
    _isLoadingMessages = true;
    _error = null;
    notifyListeners();
    try {
      final uri = isAdmin
          ? Uri.parse('$_base/admin/patients/$patientId/messages')
          : Uri.parse('$_base/patient/messages');
      final response = await http.get(uri, headers: await _headers()).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        _messages = _asList(_decodeJsonOrThrow(response))
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _error = 'Failed to load messages (${response.statusCode})';
      }
    } catch (e) {
      _error = e is FormatException ? e.message : 'Network error: $e';
      debugPrint('[ChatService] fetchMessages error: $e');
    }
    _isLoadingMessages = false;
    notifyListeners();
  }

  /// Sends a text message. Admins pass [patientId]; patients omit it.
  Future<ChatMessage?> sendMessage({
    required bool isAdmin,
    int? patientId,
    required String body,
  }) async {
    try {
      final uri = isAdmin
          ? Uri.parse('$_base/admin/patients/$patientId/messages')
          : Uri.parse('$_base/patient/messages');
      final response = await http
          .post(uri, headers: await _headers(), body: jsonEncode({'body': body}))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = _decodeJsonOrThrow(response);
        final messageJson = decoded is Map<String, dynamic> && decoded['data'] is Map
            ? decoded['data'] as Map<String, dynamic>
            : decoded as Map<String, dynamic>;
        final message = ChatMessage.fromJson(messageJson);
        _messages.add(message);
        notifyListeners();
        return message;
      }
      debugPrint('[ChatService] sendMessage failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('[ChatService] sendMessage error: $e');
    }
    return null;
  }

  /// Merges a message delivered live over the `private_message` socket event
  /// into the open thread. Guards against the REST POST's own copy of the
  /// same message already being in the list.
  void receiveLiveMessage(ChatMessage message) {
    if (_messages.any((m) => m.id == message.id)) return;
    _messages.add(message);
    notifyListeners();
  }

  /// Every group chat the current user participates in (admin or patient).
  Future<void> fetchChannels() async {
    _isLoadingChannels = true;
    _channelError = null;
    notifyListeners();
    try {
      final response = await http
          .get(Uri.parse('$_base/messaging/channels'), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = _decodeJsonOrThrow(response);
        _channels = _asList(decoded)
            .map((e) => ChatChannel.fromJson(e as Map<String, dynamic>))
            .toList();
        _totalChannelUnreadCount = decoded is Map<String, dynamic> &&
                decoded['meta'] is Map &&
                (decoded['meta'] as Map)['total_unread_count'] != null
            ? (decoded['meta']['total_unread_count'] as num).toInt()
            : _channels.fold(0, (sum, c) => sum + c.unreadCount);
      } else {
        _channelError = 'Failed to load group chats (${response.statusCode})';
      }
    } catch (e) {
      _channelError = e is FormatException ? e.message : 'Network error: $e';
      debugPrint('[ChatService] fetchChannels error: $e');
    }
    _isLoadingChannels = false;
    notifyListeners();
  }

  /// Admin-only server-side (a plain 403 if the caller isn't an admin).
  /// [patientIds] must be at least 2 of the admin's own patients.
  /// Returns null and sets [channelError] on failure (403/422/network).
  Future<ChatChannel?> createChannel({String? name, required List<int> patientIds}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/messaging/channels'),
            headers: await _headers(),
            body: jsonEncode({'name': name, 'patient_ids': patientIds}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 201) {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        final channel = ChatChannel.fromJson(decoded['data'] as Map<String, dynamic>);
        _channels.insert(0, channel);
        notifyListeners();
        return channel;
      }
      if (response.statusCode == 403) {
        _channelError = 'Only admins can create group chats.';
      } else if (response.statusCode == 422) {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        final errors = decoded['errors'] as Map<String, dynamic>?;
        final errorLists = errors?.values.whereType<List>().toList() ?? const [];
        final firstError = errorLists.isNotEmpty && errorLists.first.isNotEmpty ? errorLists.first.first : null;
        _channelError = firstError as String? ?? decoded['message'] as String? ?? 'Could not create group chat.';
      } else {
        _channelError = 'Failed to create group chat (${response.statusCode})';
      }
    } catch (e) {
      _channelError = e is FormatException ? e.message : 'Network error: $e';
      debugPrint('[ChatService] createChannel error: $e');
    }
    notifyListeners();
    return null;
  }

  Future<void> fetchChannelMessages(int channelId) async {
    _isLoadingChannelMessages = true;
    _channelMessagesError = null;
    notifyListeners();
    try {
      final response = await http
          .get(Uri.parse('$_base/messaging/channels/$channelId/messages'), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        _channelMessages = _asList(_decodeJsonOrThrow(response))
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _channelMessagesError = 'Failed to load messages (${response.statusCode})';
      }
    } catch (e) {
      _channelMessagesError = e is FormatException ? e.message : 'Network error: $e';
      debugPrint('[ChatService] fetchChannelMessages error: $e');
    }
    _isLoadingChannelMessages = false;
    notifyListeners();
  }

  /// Sends a text message to a group. The channel relay has no server-side
  /// fan-out, so the caller must loop [ChannelSendResult.recipients] and emit
  /// `private_message` once per entry to deliver it live.
  Future<ChannelSendResult?> sendChannelMessage({required int channelId, required String body}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/messaging/channels/$channelId/messages'),
            headers: await _headers(),
            body: jsonEncode({'body': body}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 201) {
        final decoded = _decodeJsonOrThrow(response) as Map<String, dynamic>;
        final mine = ChatMessage.fromJson(decoded['data'] as Map<String, dynamic>);
        final recipients = (decoded['recipients'] as List<dynamic>? ?? [])
            .map((e) => ChannelRecipientMessage(
                  recipientId: (e as Map<String, dynamic>)['recipient_id'] as int,
                  message: ChatMessage.fromJson(e['message'] as Map<String, dynamic>),
                ))
            .toList();
        _channelMessages.add(mine);
        notifyListeners();
        return ChannelSendResult(mine: mine, recipients: recipients);
      }
      debugPrint('[ChatService] sendChannelMessage failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('[ChatService] sendChannelMessage error: $e');
    }
    return null;
  }

  /// Merges a group message delivered live over the socket, deduped by id.
  void receiveLiveChannelMessage(ChatMessage message) {
    if (_channelMessages.any((m) => m.id == message.id)) return;
    _channelMessages.add(message);
    notifyListeners();
  }

  void clear() {
    _conversations = [];
    _messages = [];
    _error = null;
    _channels = [];
    _channelMessages = [];
    _totalChannelUnreadCount = 0;
    _channelError = null;
    _channelMessagesError = null;
    notifyListeners();
  }
}
