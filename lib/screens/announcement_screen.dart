import 'package:flutter/material.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() =>
      _AnnouncementScreenState();
}

class _AnnouncementScreenState
    extends State<AnnouncementScreen> {
  final TextEditingController _controller =
      TextEditingController();

  bool _isEmergency = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  void _sendAnnouncement() {
    final text = _controller.text.trim();

    if (text.isEmpty) {
      _showMessage('ঘোষণার বার্তা লিখুন।');
      return;
    }

    // এই ধাপে শুধু স্ক্রিন তৈরি হচ্ছে।
    // Bluetooth relay পরবর্তী ধাপে যুক্ত হবে।
    _showMessage(
      'ঘোষণার স্ক্রিন প্রস্তুত। '
      'বার্তা পাঠানোর ব্যবস্থা এখনো যুক্ত হয়নি।',
    );
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
              decoration: const InputDecoration(
                labelText: 'ঘোষণার বার্তা',
                hintText:
                    'যেমন: এলাকায় জরুরি সহায়তা প্রয়োজন...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                value: _isEmergency,
                onChanged: (value) {
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
                onPressed: _sendAnnouncement,
                icon: const Icon(Icons.campaign),
                label: const Text(
                  'ঘোষণা পাঠান',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'নোট: এই ধাপে ঘোষণা লেখার স্ক্রিন তৈরি হচ্ছে। '
                  'এখনো বার্তাটি অন্য ফোনে পাঠানো বা রিলে করা '
                  'হয় না। পরবর্তী ধাপে Bluetooth ও সংরক্ষণ '
                  'ব্যবস্থার সঙ্গে যুক্ত করা হবে।',
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
