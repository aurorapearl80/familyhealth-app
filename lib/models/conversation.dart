class ConversationPreview {
  final String? body;
  final bool hasAttachment;
  final String? attachmentName;
  final DateTime createdAt;
  final bool isMine;
  final bool isRead;

  const ConversationPreview({
    this.body,
    required this.hasAttachment,
    this.attachmentName,
    required this.createdAt,
    required this.isMine,
    required this.isRead,
  });

  factory ConversationPreview.fromJson(Map<String, dynamic> json) {
    return ConversationPreview(
      body: json['body'] as String?,
      hasAttachment: json['has_attachment'] as bool? ?? false,
      attachmentName: json['attachment_name'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isMine: json['is_mine'] as bool? ?? false,
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}

/// One entry per patient, from `GET /messaging/conversations` (admin only).
class Conversation {
  final int patientId;
  final int recipientUserId;
  final String fullName;
  final String? profileImageUrl;
  final ConversationPreview? lastMessage;
  final int unreadCount;

  const Conversation({
    required this.patientId,
    required this.recipientUserId,
    required this.fullName,
    this.profileImageUrl,
    this.lastMessage,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      patientId: json['patient_id'] as int,
      recipientUserId: json['recipient_user_id'] as int,
      fullName: json['full_name'] as String? ?? 'Unknown',
      profileImageUrl: json['profile_image_url'] as String?,
      lastMessage: json['last_message'] != null
          ? ConversationPreview.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
