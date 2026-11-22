import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MinExpiryTrackerApp());
}

class MinExpiryTrackerApp extends StatelessWidget {
  const MinExpiryTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MinExpiryTracker',
      debugShowCheckedModeBanner: false, // Tắt dải chữ "DEBUG" đỏ ở góc trên phải
      theme: ThemeData(
        // Tự động tạo bảng màu hiện đại, hài hòa theo phong cách Android Material 3
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
