import 'package:flutter/material.dart';

import 'bluetooth_devices_screen.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  void _openBluetooth(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BluetoothDevicesScreen(),
      ),
    );
  }

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
            'মেসেজ আদান-প্রদান করুন।',
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
                'কাছাকাছি জরুরি মেসেঞ্জার ফোন খুঁজে '
                'Bluetooth-এর মাধ্যমে যুক্ত করুন।',
            buttonText: 'Bluetooth ডিভাইস খুঁজুন',
            onPressed: () {
              _openBluetooth(context);
            },
          ),

          const SizedBox(height: 14),

          _ConnectionCard(
            icon: Icons.wifi,
            title: 'Wi-Fi',
            description:
                'একই Wi-Fi network-এ থাকা ফোনের '
                'সাথে local connection তৈরি করুন।',
            buttonText: 'Wi-Fi connection',
            onPressed: () {
              _showComingSoon(
                context,
                'Wi-Fi connection পরের ধাপে চালু করা হবে।',
              );
            },
          ),

          const SizedBox(height: 14),

          _ConnectionCard(
            icon: Icons.wifi_tethering,
            title: 'Hotspot',
            description:
                'একটি ফোনের Hotspot ব্যবহার করে '
                'Internet ছাড়াই local network তৈরি করুন।',
            buttonText: 'Hotspot connection',
            onPressed: () {
              _showComingSoon(
                context,
                'Hotspot connection পরের ধাপে চালু করা হবে।',
              );
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
                      'জরুরি মেসেঞ্জার Internet বা SMS-এর '
                      'উপর নির্ভর করবে না। Bluetooth, Wi-Fi '
                      'ও Hotspot-এর মাধ্যমে local communication '
                      'ব্যবহার করা হবে।',
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

  void _showComingSoon(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
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
