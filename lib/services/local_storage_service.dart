import 'package:hive_flutter/hive_flutter.dart';

import '../models/message.dart';

class StorageService {
  static const String messagesBoxName = 'messages';
  static const String settingsBoxName = 'settings';

  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isBoxOpen(messagesBoxName)) {
      await Hive.openBox<Map>(messagesBoxName);
    }

    if (!Hive.isBoxOpen(settingsBoxName)) {
      await Hive.openBox(settingsBoxName);
    }
  }

  static Box<Map> get messagesBox {
    return Hive.box<Map>(messagesBoxName);
  }

  static Box get settingsBox {
    return Hive.box(settingsBoxName);
  }

  static Future<void> saveMessage(Message message) async {
    await messagesBox.put(message.id, message.toMap());
  }

  static Future<void> saveMessages(List<Message> messages) async {
    final entries = <dynamic, dynamic>{};

    for (final message in messages) {
      entries[message.id] = message.toMap();
    }

    if (entries.isNotEmpty) {
      await messagesBox.putAll(entries);
    }
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
      } catch (error) {
        // Ignore corrupted message entries.
      }
    }

    messages.sort(
      (a, b) => a.timestamp.compareTo(b.timestamp),
    );

    return messages;
  }

  static Future<void> deleteMessage(String id) async {
    await messagesBox.delete(id);
  }

  static Future<void> clearMessages() async {
    await messagesBox.clear();
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

  static Future<void> saveSetting(
    String key,
    dynamic value,
  ) async {
    await settingsBox.put(key, value);
  }

  static dynamic getSetting(String key) {
    return settingsBox.get(key);
  }
}
