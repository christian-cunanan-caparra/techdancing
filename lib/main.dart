import 'package:flutter/material.dart';
import 'package:techdancing/screens/splash_screen.dart';
import 'package:techdancing/services/video_cache_service.dart'; // Add this import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize video cache service
  await VideoCacheService().init();

  runApp(MyApp());
}

// UGH ~
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dancing Game',
      theme: ThemeData(primarySwatch: Colors.purple),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}