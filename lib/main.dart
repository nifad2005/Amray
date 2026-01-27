import 'package:flutter/material.dart';
import 'package:amray/screens/onboarding_screen.dart';
import 'package:amray/services/p2p_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize P2P Service
  await P2PService().init();
  runApp(const AmrayApp());
}

class AmrayApp extends StatelessWidget {
  const AmrayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'আমরাই',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Soft Green
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF0288D1), // Sky Blue
        ),
        useMaterial3: true,
        fontFamily: 'Hind Siliguri',
        scaffoldBackgroundColor: const Color(0xFFFAFAFA), // Off-white
      ),
      home: const OnboardingScreen(),
    );
  }
}
