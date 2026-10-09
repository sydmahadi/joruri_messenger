
class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final bool isEmergency;
  final bool isDelivered;

  // chat, announcement অথবা private
  final String messageType;

  // ব্যক্তিগত মেসেজের প্রাপকের Device ID
  final String? recipientId;

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
  });

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
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      senderId: map['senderId'] as String,
      senderName: map['senderName'] as String,
      text: map['text'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      isEmergency: map['isEmergency'] as bool? ?? false,
      isDelivered: map['isDelivered'] as bool? ?? false,
      messageType: map['messageType'] as String? ?? 'chat',
      recipientId: map['recipientId'] as String?,
    );
  }
}
