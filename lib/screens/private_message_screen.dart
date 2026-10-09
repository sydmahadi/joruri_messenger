import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _recipientController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  void _sendPrivateMessage() {
    final recipientId = _recipientController.text.trim();
    final message = _messageController.text.trim();

    if (recipientId.isEmpty) {
      _showMessage('প্রাপকের ডিভাইস ID লিখুন।');
      return;
    }

    if (message.isEmpty) {
      _showMessage('মেসেজ লিখুন।');
      return;
    }

    // এই ধাপে শুধু স্ক্রিন তৈরি হচ্ছে।
    // Encryption ও Bluetooth delivery পরে যুক্ত হবে।
    _showMessage(
      'ব্যক্তিগত মেসেজের স্ক্রিন প্রস্তুত। '
      'এখনো এনক্রিপশন বা মেসেজ পাঠানোর ব্যবস্থা যুক্ত হয়নি।',
    );
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
                onPressed: _sendPrivateMessage,
                icon: const Icon(Icons.lock),
                label: const Text(
                  'ব্যক্তিগত মেসেজ পাঠান',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'গুরুত্বপূর্ণ: এই স্ক্রিনটি এখনো পরীক্ষামূলক। '
                  'মেসেজ পাঠানো, প্রাপকের পরিচয় যাচাই এবং '
                  'এনক্রিপশন যুক্ত না হওয়া পর্যন্ত এখানে '
                  'সংবেদনশীল তথ্য পাঠাবেন না।',
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
