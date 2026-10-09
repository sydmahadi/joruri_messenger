
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../services/bluetooth_service.dart';
import '../services/device_service.dart';
import '../services/local_storage_service.dart';

class PrivateMessageScreen extends StatefulWidget {
  const PrivateMessageScreen({super.key});

  @override
  State<PrivateMessageScreen> createState() =>
      _PrivateMessageScreenState();
}

class _PrivateMessageScreenState
    extends State<PrivateMessageScreen> {
  final TextEditingController _recipientController =
      TextEditingController();

  final TextEditingController _messageController =
      TextEditingController();

  bool _isSending = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendPrivateMessage() async {
    if (_isSending) return;

    final recipientId = _recipientController.text.trim();
    final text = _messageController.text.trim();

    if (recipientId.isEmpty) {
      _showMessage('প্রাপকের ডিভাইস ID লিখুন।');
      return;
    }

    if (recipientId == DeviceService.deviceId) {
      _showMessage('নিজের ডিভাইসে মেসেজ পাঠানো যাবে না।');
      return;
    }

    if (text.isEmpty) {
      _showMessage('মেসেজ লিখুন।');
      return;
    }

    setState(() {
      _isSending = true;
    });

    final message = Message(
      id: const Uuid().v4(),
      senderId: DeviceService.deviceId,
      senderName: DeviceService.deviceName,
      text: text,
      createdAt: DateTime.now(),
      isEmergency: false,
      isDelivered: false,
      messageType: 'private',
      recipientId: recipientId,
    );

    try {
      // প্রথমে এই ফোনে মেসেজ সংরক্ষণ।
      await LocalStorageService.saveMessage(message);

      // বিদ্যমান Bluetooth সংযোগে পাঠানোর চেষ্টা।
      await BluetoothService().sendMessage(
        jsonEncode(message.toMap()),
      );

      _messageController.clear();

      _showMessage(
        'Bluetooth-এ পাঠানোর চেষ্টা সম্পন্ন। '
        'প্রাপক পেয়েছেন কি না নিশ্চিত নয়।',
      );
    } catch (_) {
      _showMessage(
        'মেসেজ ফোনে সংরক্ষিত আছে, কিন্তু Bluetooth-এ '
        'পাঠানো যায়নি। সংযোগ পরীক্ষা করুন।',
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
          'ব্যক্তিগত মেসেজ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              Icons.lock_rounded,
              size: 70,
              color: colors.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'নির্দিষ্ট ব্যক্তিকে মেসেজ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'প্রাপকের ডিভাইস ID ও মেসেজ লিখুন।',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _recipientController,
              enabled: !_isSending,
              decoration: const InputDecoration(
                labelText: 'প্রাপকের ডিভাইস ID',
                hintText: 'প্রাপকের সম্পূর্ণ ID',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _messageController,
              enabled: !_isSending,
              minLines: 4,
              maxLines: 8,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'ব্যক্তিগত মেসেজ',
                hintText: 'আপনার মেসেজ লিখুন...',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.chat_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed:
                    _isSending ? null : _sendPrivateMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSending
                      ? 'পাঠানো হচ্ছে...'
                      : 'ব্যক্তিগত মেসেজ পাঠান',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'সতর্কতা: মেসেজ এখনো এনক্রিপ্ট করা হয় না। '
                  'প্রাপকের ID দিয়ে নির্দিষ্ট ফোনে পাঠানো '
                  'বা প্রাপকের পরিচয় যাচাই করার ব্যবস্থা '
                  'এখনো সম্পূর্ণ নয়। সংবেদনশীল তথ্য পাঠাবেন না।',
                  style: TextStyle(height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
