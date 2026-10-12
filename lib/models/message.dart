
class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String senderLocation;
  final String text;
  final DateTime createdAt;
  final bool isEmergency;
  final bool isDelivered;
  final String messageType;
  final String? recipientId;
  final int hopCount;
  final int maxHops;

  const Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.senderLocation = '',
    this.isEmergency = false,
    this.isDelivered = false,
    this.messageType = 'chat',
    this.recipientId,
    this.hopCount = 0,
    this.maxHops = 5,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderLocation': senderLocation,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'isEmergency': isEmergency,
      'isDelivered': isDelivered,
      'messageType': messageType,
      'recipientId': recipientId,
      'hopCount': hopCount,
      'maxHops': maxHops,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? 'অজানা ব্যবহারকারী',
      senderLocation: map['senderLocation']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      createdAt: DateTime.tryParse(
            map['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
      isEmergency: map['isEmergency'] == true,
      isDelivered: map['isDelivered'] == true,
      messageType: map['messageType']?.toString() ?? 'chat',
      recipientId: map['recipientId']?.toString(),
      hopCount: int.tryParse(map['hopCount']?.toString() ?? '') ?? 0,
      maxHops: int.tryParse(map['maxHops']?.toString() ?? '') ?? 5,
    );
  }

  Message copyWith({
    int? hopCount,
    bool? isDelivered,
  }) {
    return Message(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderLocation: senderLocation,
      text: text,
      createdAt: createdAt,
      isEmergency: isEmergency,
      isDelivered: isDelivered ?? this.isDelivered,
      messageType: messageType,
      recipientId: recipientId,
      hopCount: hopCount ?? this.hopCount,
      maxHops: maxHops,
    );
  }
}
