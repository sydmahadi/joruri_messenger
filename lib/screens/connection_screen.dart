import 'package:flutter/material.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Connection',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'কানেকশনের মাধ্যম নির্বাচন করুন',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Internet ছাড়াই কাছাকাছি ফোনের সাথে '
            'মেসেজ আদান-প্রদান করা যাবে।',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          _ConnectionCard(
            icon: Icons.bluetooth,
            title: 'Bluetooth',
            description:
                'কাছাকাছি ফোনের সাথে Bluetooth দিয়ে যুক্ত হন',
            buttonText: 'Bluetooth ডিভাইস খুঁজুন',
            onPressed: () {
              // Bluetooth connection পরের ধাপে যুক্ত হবে।
            },
          ),

          const SizedBox(height: 14),

          _ConnectionCard(
            icon: Icons.wifi,
            title: 'Wi-Fi',
            description:
                'একই Wi-Fi network-এ থাকা ফোনের সাথে যুক্ত হন',
            buttonText: 'Wi-Fi ডিভাইস খুঁজুন',
            onPressed: () {
              // Wi-Fi connection পরের ধাপে যুক্ত হবে।
            },
          ),

          const SizedBox(height: 14),

          _ConnectionCard(
            icon: Icons.wifi_tethering,
            title: 'Hotspot',
            description:
                'একটি ফোনের Hotspot ব্যবহার করে local network তৈরি করুন',
            buttonText: 'Hotspot connection',
            onPressed: () {
              // Hotspot connection পরের ধাপে যুক্ত হবে।
            },
          ),

          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'এই অ্যাপের local communication-এর জন্য '
                      'mobile internet বা SMS প্রয়োজন হবে না।',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onPressed;

  const _ConnectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      colorScheme.primaryContainer,
                  child: Icon(
                    icon,
                    color: colorScheme
                        .onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: onPressed,
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
