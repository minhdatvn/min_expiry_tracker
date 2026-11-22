import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/notify_service.dart';

Future<void> main() async {
  // Bắt buộc phải có dòng này khi gọi các hàm async (như khởi tạo thông báo) trước runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi động hệ thống thông báo offline và xin quyền gửi thông báo trên Android 13+
  await NotifyService.instance.init();

  // Khởi chạy ứng dụng MinExpiryTracker
  runApp(const MinExpiryTrackerApp());
}

class MinExpiryTrackerApp extends StatelessWidget {
  const MinExpiryTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MinExpiryTracker',
      // Tắt dải chữ "DEBUG" màu đỏ ở góc trên bên phải màn hình
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Tự động tạo bảng màu hiện đại, hài hòa theo phong cách Android Material 3
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // Màn hình đầu tiên xuất hiện khi mở ứng dụng
      home: const HomeScreen(),
    );
  }
}
