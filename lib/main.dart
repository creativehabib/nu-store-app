import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'screens/home_screen.dart'; // HomeScreen ইম্পোর্ট করা হলো

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const ProviderScope(child: StoreManagementApp()));
}

class StoreManagementApp extends StatelessWidget {
  const StoreManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NU Store Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          primary: const Color(0xFF2563EB),
          surface: const Color(0xFFF8FAFC),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(), // প্রথমে HomeScreen লোড হবে
    );
  }
}