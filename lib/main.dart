import 'package:diplomgrinenko/firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

//точка входа в приложение
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализируем Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
 

  runApp(const diplomApp());
}

class diplomApp extends StatelessWidget {
  const diplomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrinApp',
      theme: AppTheme.lightTheme,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
