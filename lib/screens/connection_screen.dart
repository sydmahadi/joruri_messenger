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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Connection',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 16),

            Icon(
              Icons.bluetooth_connected,
              size: 76,
              color: colors.primary,
            ),

            const SizedBox(height: 18),

            const Text(
              'Bluetooth সংযোগ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Internet ছাড়াই কাছাকাছি থাকা '
              'জরুরি মেসেঞ্জার ফোনের সঙ্গে '
              'Bluetooth-এর মাধ্যমে সংযোগ করুন।',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: colors.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 30),

            Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor:
                          colors.primaryContainer,
                      child: Icon(
                        Icons.bluetooth,
                        size: 38,
                        color: colors.onPrimaryContainer,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Bluetooth',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'কাছাকাছি ফোন খুঁজুন এবং '
                      'সংযোগের অনুরোধ পাঠান। '
                      'অন্য ফোনে অনুরোধ গ্রহণ করা হলে '
                      'চ্যাট শুরু করতে পারবেন।',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () {
                          _openBluetooth(context);
                        },
                        icon: const Icon(
                          Icons.bluetooth_searching,
                        ),
                        label: const Text(
                          'Bluetooth ডিভাইস খুঁজুন',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'এই অ্যাপের বর্তমান Connection '
                        'স্ক্রিনে শুধু Bluetooth ব্যবহার করা হবে। '
                        'সংযোগ করতে উভয় ফোনে Bluetooth চালু '
                        'রাখুন এবং প্রয়োজনীয় অনুমতি দিন।',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: colors.onSurfaceVariant,
                        ),
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
