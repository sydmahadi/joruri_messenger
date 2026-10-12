class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final bool isEmergency;
  final bool isDelivered;
  final String messageType;
  final String? recipientId;

  // Mesh forwarding-এর জন্য
  final int hopCount;
  final int maxHops;
  final DateTime? expiresAt;

  const Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.isEmergency = false,
    this.isDelivered = false,
    this.messageType = 'chat',
    this.recipientId,
    this.hopCount = 0,
    this.maxHops = 5,
    this.expiresAt,
  });

  DateTime get timestamp => createdAt;

  // প্রকৃতপক্ষে নিজের পাঠানো কি না, তা ChatScreen-এ
  // DeviceService.deviceId-এর সঙ্গে senderId মিলিয়ে নির্ধারণ করবে।
  bool get isSent => true;

  bool get canForward {
    if (hopCount >= maxHops) return false;

    final expiry = expiresAt;
    if (expiry != null && DateTime.now().isAfter(expiry)) {
      return false;
    }

    return true;
  }

  Message forwarded() {
    return Message(
      id: id,
      senderId: senderId,
      senderName: senderName,
      text: text,
      createdAt: createdAt,
      isEmergency: isEmergency,
      isDelivered: isDelivered,
      messageType: messageType,
      recipientId: recipientId,
      hopCount: hopCount + 1,
      maxHops: maxHops,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'isEmergency': isEmergency,
      'isDelivered': isDelivered,
      'messageType': messageType,
      'recipientId': recipientId,
      'hopCount': hopCount,
      'maxHops': maxHops,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? 'অজানা',
      text: map['text']?.toString() ?? '',
      createdAt: DateTime.tryParse(
            map['createdAt']?.toString() ??
                map['timestamp']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      isEmergency: map['isEmergency'] as bool? ?? false,
      isDelivered: map['isDelivered'] as bool? ?? false,
      messageType: map['messageType']?.toString() ?? 'chat',
      recipientId: map['recipientId']?.toString(),
      hopCount: (map['hopCount'] as num?)?.toInt() ?? 0,
      maxHops: (map['maxHops'] as num?)?.toInt() ?? 5,
      expiresAt: DateTime.tryParse(
        map['expiresAt']?.toString() ?? '',
      ),
    );
  }
}
