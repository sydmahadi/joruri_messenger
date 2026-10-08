class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final bool isEmergency;
  final bool isDelivered;

  const Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.isEmergency = false,
    this.isDelivered = false,
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
    );
  }
}
