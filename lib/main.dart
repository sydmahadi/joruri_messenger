import 'package:flutter/material.dart';

import 'screens/connection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JoruriMessengerApp());
}

class JoruriMessengerApp extends StatelessWidget {
  const JoruriMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'জরুরি মেসেঞ্জার',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        brightness: Brightness.light,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature স্ক্রিন পরের ধাপে তৈরি করা হবে।'),
      ),
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
            tooltip: 'সংযোগ',
            onPressed: () => _openScreen(
              context,
              const ConnectionScreen(),
            ),
            icon: const Icon(Icons.bluetooth_connected),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 16),
            Icon(
              Icons.emergency_rounded,
              size: 76,
              color: colors.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'সংযুক্ত থাকুন, প্রস্তুত থাকুন',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'স্থানীয় ডিভাইসের মাধ্যমে যোগাযোগের জন্য '
              'একটি সুবিধা বেছে নিন।',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            _HomeFeatureCard(
              icon: Icons.campaign_rounded,
              title: 'ঘোষণা',
              subtitle:
                  'সবার জন্য জরুরি বার্তা তৈরি ও পাঠানোর ব্যবস্থা।',
              buttonText: 'ঘোষণা খুলুন',
              color: colors.primaryContainer,
              iconColor: colors.onPrimaryContainer,
              onTap: () => _showComingSoon(context, 'ঘোষণা'),
            ),

            const SizedBox(height: 16),

            _HomeFeatureCard(
              icon: Icons.lock_rounded,
              title: 'ব্যক্তিগত মেসেজ',
              subtitle:
                  'নির্দিষ্ট ব্যক্তির জন্য গোপনীয় মেসেজের ব্যবস্থা।',
              buttonText: 'ব্যক্তিগত মেসেজ খুলুন',
              color: colors.secondaryContainer,
              iconColor: colors.onSecondaryContainer,
              onTap: () =>
                  _showComingSoon(context, 'ব্যক্তিগত মেসেজ'),
            ),

            const SizedBox(height: 16),

            _HomeFeatureCard(
              icon: Icons.chat_rounded,
              title: 'বর্তমান চ্যাট',
              subtitle:
                  'আগের সাধারণ Bluetooth চ্যাট স্ক্রিনটি ব্যবহার করুন।',
              buttonText: 'চ্যাট খুলুন',
              color: colors.surfaceContainerHighest,
              iconColor: colors.onSurface,
              onTap: () => _showComingSoon(context, 'বর্তমান চ্যাট'),
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
                        'ঘোষণা, ব্যক্তিগত এনক্রিপশন ও ফোনের মাধ্যমে '
                        'মেসেজ রিলে করার কার্যকর ব্যবস্থা পরবর্তী '
                        'ধাপগুলোতে তৈরি হবে। এখনো এই স্ক্রিনগুলো '
                        'সম্পূর্ণ কার্যকর নয়।',
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

class _HomeFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _HomeFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
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
              subtitle,
              style: TextStyle(
                fontSize: 14,
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
