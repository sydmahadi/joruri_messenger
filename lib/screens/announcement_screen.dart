
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../services/bluetooth_service.dart';
import '../services/device_service.dart';
import '../services/local_storage_service.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() =>
      _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  final TextEditingController _controller =
      TextEditingController();

  bool _isEmergency = false;
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _sendAnnouncement() async {
    if (_isSending) return;

    final text = _controller.text.trim();

    if (text.isEmpty) {
      _showMessage('ঘোষণার বার্তা লিখুন।');
      return;
    }

    if (text.length > 1000) {
      _showMessage('ঘোষণার বার্তা ১০০০ অক্ষরের মধ্যে রাখুন।');
      return;
    }

    setState(() {
      _isSending = true;
    });

    final message = Message(
      id: const Uuid().v4(),
      senderId: DeviceService.deviceId,
      senderName: 'ঘোষণা • ${DeviceService.deviceName}',
      text: text,
      createdAt: DateTime.now(),
      isEmergency: _isEmergency,
      isDelivered: false,
    );

    try {
      // প্রথমে ফোনের লোকাল স্টোরেজে ঘোষণা সংরক্ষণ।
      await LocalStorageService.saveMessage(message);

      // বিদ্যমান Bluetooth সংযোগ দিয়ে পাঠানোর চেষ্টা।
      await BluetoothService().sendMessage(
        jsonEncode(message.toMap()),
      );

      // পাঠানোর চেষ্টা সফল হলে delivered হিসেবে সংরক্ষণ।
      final deliveredMessage = Message(
        id: message.id,
        senderId: message.senderId,
        senderName: message.senderName,
        text: message.text,
        createdAt: message.createdAt,
        isEmergency: message.isEmergency,
        isDelivered: true,
      );

      await LocalStorageService.saveMessage(deliveredMessage);

      _controller.clear();

      _showMessage(
        'ঘোষণা Bluetooth সংযোগে পাঠানো হয়েছে।',
      );
    } catch (e) {
      // পাঠানো ব্যর্থ হলেও ঘোষণাটি ফোনে সংরক্ষিত থাকবে।
      _showMessage(
        'ঘোষণা ফোনে সংরক্ষিত হয়েছে, '
        'কিন্তু Bluetooth-এ পাঠানো যায়নি। '
        'সংযোগ পরীক্ষা করুন।',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'জরুরি ঘোষণা',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              Icons.campaign_rounded,
              size: 70,
              color: colors.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'সবার জন্য ঘোষণা',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'জরুরি তথ্য বা সাধারণ ঘোষণা লিখুন।',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _controller,
              minLines: 5,
              maxLines: 9,
              maxLength: 1000,
              enabled: !_isSending,
              decoration: const InputDecoration(
                labelText: 'ঘোষণার বার্তা',
                hintText: 'যেমন: এলাকায় জরুরি সহায়তা প্রয়োজন...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                value: _isEmergency,
                onChanged: _isSending
                    ? null
                    : (value) {
                        setState(() {
                          _isEmergency = value;
                        });
                      },
                secondary: Icon(
                  Icons.warning_amber_rounded,
                  color: _isEmergency
                      ? colors.error
                      : colors.primary,
                ),
                title: const Text('জরুরি ঘোষণা'),
                subtitle: const Text(
                  'বার্তাটিকে জরুরি হিসেবে চিহ্নিত করুন।',
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed:
                    _isSending ? null : _sendAnnouncement,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.campaign),
                label: Text(
                  _isSending
                      ? 'পাঠানো হচ্ছে...'
                      : 'ঘোষণা পাঠান',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'ঘোষণা প্রথমে এই ফোনে সংরক্ষণ করা হবে। '
                  'এরপর বিদ্যমান Bluetooth সংযোগ দিয়ে '
                  'পাঠানোর চেষ্টা করা হবে। অন্য ফোনে পৌঁছানো '
                  'এবং স্বয়ংক্রিয় রিলে এখনো নিশ্চিত নয়।',
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
