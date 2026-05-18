import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart'; // Import service notifikasi

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nyalakan mesin notifikasi sebelum aplikasi berjalan
  await NotificationService().init(); 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoYourTask',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A11CB)),
        useMaterial3: true,
        fontFamily: 'Roboto', 
      ),
      home: const LoginScreen(),
    );
  }
}