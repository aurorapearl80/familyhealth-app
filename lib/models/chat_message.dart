class ChatUser {
  final int id;
  final String? name;
  final String? email;
  final String? profileImageUrl;

  ChatUser({required this.id, this.name, this.email, this.profileImageUrl});

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] as int,
      name: json['name'] as String?,
      email: json['email'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'profile_image_url': profileImageUrl,
      };
}

class MessageAttachment {
  final String url;
  final String name;
  final String mime;
  final int size;
  final bool isImage;

  MessageAttachment({
    required this.url,
    required this.name,
    required this.mime,
    required this.size,
    required this.isImage,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      url: json['url'] as String? ?? '',
      name: json['name'] as String? ?? '',
      mime: json['mime'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      isImage: json['is_image'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'name': name,
        'mime': mime,
        'size': size,
        'is_image': isImage,
      };
}

class ChatMessage {
  final int id;
  final int senderId;
  final int recipientId;
  final int? patientId;
  final int? channelId;
  final String? body;
  final MessageAttachment? attachment;
  final bool isRead;
  final DateTime? readAt;
  final bool isMine;
  final DateTime createdAt;
  final ChatUser? sender;
  final ChatUser? recipient;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    this.patientId,
    this.channelId,
    this.body,
    this.attachment,
    required this.isRead,
    this.readAt,
    required this.isMine,
    required this.createdAt,
    this.sender,
    this.recipient,
  });

  bool get isGroup => channelId != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      senderId: json['sender_id'] as int,
      recipientId: json['recipient_id'] as int,
      patientId: json['patient_id'] as int?,
      channelId: json['channel_id'] as int?,
      body: json['body'] as String?,
      attachment: json['attachment'] != null
          ? MessageAttachment.fromJson(json['attachment'] as Map<String, dynamic>)
          : null,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      isMine: json['is_mine'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sender: json['sender'] != null
          ? ChatUser.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      recipient: json['recipient'] != null
          ? ChatUser.fromJson(json['recipient'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Round-trips back to the REST message shape, so a just-sent message can be
  /// relayed as-is over the `private_message` socket event.
  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'recipient_id': recipientId,
        'patient_id': patientId,
        'channel_id': channelId,
        'body': body,
        'attachment': attachment?.toJson(),
        'is_read': isRead,
        'read_at': readAt?.toIso8601String(),
        'is_mine': isMine,
        'created_at': createdAt.toIso8601String(),
        'sender': sender?.toJson(),
        'recipient': recipient?.toJson(),
      };

  /// Anything arriving over the `private_message` listen event was — by
  /// definition — sent by the other party, even though the REST-computed
  /// `is_mine` on that copy still reflects the *sender's* point of view.
  ChatMessage copyWithIsMine(bool value) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      recipientId: recipientId,
      patientId: patientId,
      channelId: channelId,
      body: body,
      attachment: attachment,
      isRead: isRead,
      readAt: readAt,
      isMine: value,
      createdAt: createdAt,
      sender: sender,
      recipient: recipient,
    );
  }
}
