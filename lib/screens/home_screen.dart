import 'package:flutter/material.dart';

import 'connection_screen.dart';
import 'announcement_screen.dart';
import 'private_message_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'জরুরি মেসেঞ্জার',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Bluetooth সংযোগ',
            icon: const Icon(Icons.bluetooth_connected),
            onPressed: () => _open(
              context,
              const ConnectionScreen(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 18),
            Icon(
              Icons.emergency_rounded,
              size: 76,
              color: colors.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'জরুরি যোগাযোগ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'যোগাযোগের ধরন নির্বাচন করুন',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 30),

            _FeatureCard(
              icon: Icons.campaign_rounded,
              title: 'ঘোষণা',
              description:
                  'সবার জন্য জরুরি ঘোষণা তৈরি ও পাঠান।',
              buttonText: 'ঘোষণা খুলুন',
              color: colors.primaryContainer,
              iconColor: colors.onPrimaryContainer,
              onTap: () => _open(
                context,
                const AnnouncementScreen(),
              ),
            ),

            const SizedBox(height: 16),

            _FeatureCard(
              icon: Icons.lock_rounded,
              title: 'ব্যক্তিগত মেসেজ',
              description:
                  'নির্দিষ্ট ব্যক্তির জন্য ব্যক্তিগত মেসেজ।',
              buttonText: 'ব্যক্তিগত মেসেজ খুলুন',
              color: colors.secondaryContainer,
              iconColor: colors.onSecondaryContainer,
              onTap: () => _open(
                context,
                const PrivateMessageScreen(),
              ),
            ),

            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'মেসেজ আদান-প্রদানের জন্য Bluetooth '
                        'সংযোগ প্রয়োজন। রিলে ও ব্যক্তিগত '
                        'এনক্রিপশনের কার্যকারিতা আলাদাভাবে '
                        'বাস্তবায়ন ও পরীক্ষা করতে হবে।',
                        style: TextStyle(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: color,
              child: Icon(
                icon,
                size: 28,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                height: 1.5,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onTap,
                icon: Icon(icon),
                label: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
