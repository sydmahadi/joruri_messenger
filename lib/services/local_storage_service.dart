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

  static Box<Map> get messagesBox =>
      Hive.box<Map>(messagesBoxName);

  static Box get settingsBox =>
      Hive.box(settingsBoxName);

  static Future<void> saveMessage(Message message) async {
    await messagesBox.put(message.id, message.toMap());
  }

  static Future<void> saveMessages(
    List<Message> messages,
  ) async {
    for (final message in messages) {
      await messagesBox.put(message.id, message.toMap());
    }
  }

  static List<Message> getMessages() {
    final result = <Message>[];

    for (final value in messagesBox.values) {
      try {
        result.add(
          Message.fromMap(
            Map<String, dynamic>.from(value),
          ),
        );
      } catch (_) {
        // ভুল বা অসম্পূর্ণ ডেটা থাকলে সেটি এড়িয়ে যাবে।
      }
    }

    result.sort(
      (a, b) => a.createdAt.compareTo(b.createdAt),
    );

    return result;
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
