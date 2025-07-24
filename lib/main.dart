import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
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
