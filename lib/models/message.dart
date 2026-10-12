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

  // আগের ChatScreen কোডের সঙ্গে সামঞ্জস্য
  DateTime get timestamp => createdAt;

  // আগের ChatScreen কোডের সঙ্গে সামঞ্জস্য
  bool get isSent => true;

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
    );
  }
}
