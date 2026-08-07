class ChannelParticipant {
  final int userId;
  final int? patientId;
  final String? name;
  final String? profileImageUrl;

  const ChannelParticipant({
    required this.userId,
    this.patientId,
    this.name,
    this.profileImageUrl,
  });

  factory ChannelParticipant.fromJson(Map<String, dynamic> json) {
    return ChannelParticipant(
      userId: json['user_id'] as int,
      patientId: json['patient_id'] as int?,
      name: json['name'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
    );
  }
}

class ChannelPreview {
  final String? body;
  final bool hasAttachment;
  final String? attachmentName;
  final DateTime createdAt;
  final bool isMine;

  const ChannelPreview({
    this.body,
    required this.hasAttachment,
    this.attachmentName,
    required this.createdAt,
    required this.isMine,
  });

  factory ChannelPreview.fromJson(Map<String, dynamic> json) {
    return ChannelPreview(
      body: json['body'] as String?,
      hasAttachment: json['has_attachment'] as bool? ?? false,
      attachmentName: json['attachment_name'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isMine: json['is_mine'] as bool? ?? false,
    );
  }
}

/// A group chat: an admin + 2+ of that admin's own patients in one shared thread.
/// From `GET /api/messaging/channels`.
class ChatChannel {
  final int channelId;
  final String name;
  final List<ChannelParticipant> participants;
  final ChannelPreview? lastMessage;
  final int unreadCount;

  const ChatChannel({
    required this.channelId,
    required this.name,
    required this.participants,
    this.lastMessage,
    required this.unreadCount,
  });

  factory ChatChannel.fromJson(Map<String, dynamic> json) {
    return ChatChannel(
      channelId: json['channel_id'] as int,
      name: json['name'] as String? ?? 'Group chat',
      participants: (json['participants'] as List<dynamic>? ?? [])
          .map((e) => ChannelParticipant.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastMessage: json['last_message'] != null
          ? ChannelPreview.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
