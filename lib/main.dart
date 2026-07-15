import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const ProviderScope(child: CityCallsVendorApp()));
}

class CityCallsVendorApp extends StatelessWidget {
  const CityCallsVendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CityCalls Field',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
