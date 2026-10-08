import 'package:flutter/material.dart';

import 'screens/bluetooth_devices_screen.dart';
import 'services/device_service.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalStorageService.init();
  await DeviceService.initialize();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'জরুরি মেসেঞ্জার',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 30),

            Icon(
              Icons.cell_tower,
              size: 90,
              color: Theme.of(context).colorScheme.primary,
            ),

            const SizedBox(height: 20),

            const Text(
              'জরুরি মেসেঞ্জার',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'ইন্টারনেট বা SMS ছাড়াই কাছাকাছি ডিভাইসের '
              'মধ্যে বার্তা আদান-প্রদানের জন্য।',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 35),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const BluetoothDevicesScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.bluetooth),
                label: const Text(
                  'কাছাকাছি ডিভাইস খুঁজুন',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.wifi),
                label: const Text(
                  'Local Network',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),

            const Spacer(),

            Text(
              'Device ID: ${DeviceService.deviceId.length >= 8 ? DeviceService.deviceId.substring(0, 8) : DeviceService.deviceId}...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Offline communication • Emergency ready',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}
