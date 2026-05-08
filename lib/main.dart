// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/water_screen.dart';
import 'screens/bmi_screen.dart';
import 'screens/barcode_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: AppTheme.primary),
  );
  runApp(const BeslenmeApp());
}

class BeslenmeApp extends StatelessWidget {
  const BeslenmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beslenme Asistanı',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ChatScreen(),
    WaterScreen(),
    BmiScreen(),
    BarcodeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.border,
          backgroundColor: Colors.white,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Ana Sayfa'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Asistan'),
            BottomNavigationBarItem(icon: Icon(Icons.water_drop_rounded), label: 'Su'),
            BottomNavigationBarItem(icon: Icon(Icons.monitor_weight_rounded), label: 'BMI'),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner_rounded), label: 'Barkod'),
          ],
        ),
      ),
    );
  }
}