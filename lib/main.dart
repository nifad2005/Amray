import 'package:flutter/material.dart';
import 'package:amray/screens/home_screen.dart';
import 'package:amray/services/p2p_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      themeMode: ThemeMode.dark, // Force Dark Theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF2E7D32),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2E7D32),
          secondary: Color(0xFF81C784),
          surface: Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        cardTheme: CardThemeData( // Changed from CardTheme to CardThemeData
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
