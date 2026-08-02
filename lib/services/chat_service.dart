import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'auth_service.dart';

/// Backs the chat list (admin) and message thread screens against the
/// real messaging API documented in the "Chat API Reference".
class ChatService extends ChangeNotifier {
  static const _base = 'https://familywatchtoday.com/api';

  List<Conversation> _conversations = [];
  List<ChatMessage> _messages = [];
  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;
  String? _error;

  List<Conversation> get conversations => _conversations;
  List<ChatMessage> get messages => _messages;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get error => _error;

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

  void clear() {
    _conversations = [];
    _messages = [];
    _error = null;
    notifyListeners();
  }
}
