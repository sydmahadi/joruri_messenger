import 'package:hive_flutter/hive_flutter.dart';

import '../models/message.dart';

class LocalStorageService {
  static const String messagesBoxName = 'messages';
  static const String settingsBoxName = 'settings';

  static Future<void> init() async {
    await Hive.initFlutter();

    await Hive.openBox<Map>(messagesBoxName);
    await Hive.openBox(settingsBoxName);
  }

  static Box<Map> get messagesBox {
    return Hive.box<Map>(messagesBoxName);
  }

  static Box get settingsBox {
    return Hive.box(settingsBoxName);
  }

  static Future<void> saveMessage(Message message) async {
    await messagesBox.put(
      message.id,
      message.toMap(),
    );
  }

  static List<Message> getMessages() {
    final messages = <Message>[];

    for (final value in messagesBox.values) {
      try {
        messages.add(
          Message.fromMap(
            Map<String, dynamic>.from(value),
          ),
        );
      } catch (_) {
        // Ignore corrupted message entries.
      }
    }

    messages.sort(
      (a, b) => a.createdAt.compareTo(b.createdAt),
    );

    return messages;
  }

  static Future<void> deleteMessage(String id) async {
    await messagesBox.delete(id);
  }

  static Future<void> saveDeviceId(String deviceId) async {
    await settingsBox.put('deviceId', deviceId);
  }

  static String? getDeviceId() {
    return settingsBox.get('deviceId') as String?;
  }

  static Future<void> saveDeviceName(String name) async {
    await settingsBox.put('deviceName', name);
  }

  static String? getDeviceName() {
    return settingsBox.get('deviceName') as String?;
  }
}
