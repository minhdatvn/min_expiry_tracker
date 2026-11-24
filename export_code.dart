import 'dart:convert';
import 'dart:io';

void main() async {
  // File kết quả sẽ được tạo ra ngay tại thư mục gốc của dự án
  final outputFile = File('toan_bo_code_app.txt');
  final buffer = StringBuffer();

  buffer.writeln('==================================================');
  buffer.writeln('   BÁO CÁO CẤU TRÚC & MÃ NGUỒN ỨNG DỤNG FLUTTER   ');
  buffer.writeln('==================================================\n');

  // 1. Vẽ sơ đồ cây thư mục của lib/ để dễ nhìn tổng quan
  buffer.writeln('--- 1. CẤU TRÚC THƯ MỤC (lib/) ---');
  final libDir = Directory('lib');
  if (await libDir.exists()) {
    await _writeDirectoryTree(libDir, buffer, '');
  } else {
    buffer.writeln('Không tìm thấy thư mục lib/');
  }
  buffer.writeln('\n');

  // 2. Gom các file cấu hình quan trọng (thư viện & cấu hình Android)
  final configFiles = [
    'pubspec.yaml',
    'android/app/src/main/AndroidManifest.xml',
    'android/app/build.gradle',
    'android/app/build.gradle.kts',
    'android/build.gradle',
    'android/build.gradle.kts',
    'android/settings.gradle',
    'android/settings.gradle.kts',
    'android/app/src/main/kotlin/com/min/expiry_tracker/MainActivity.kt',
    'android/app/proguard-rules.pro',
  ];

  buffer.writeln('--- 2. CÁC FILE CẤU HÌNH QUAN TRỌNG ---');
  for (final path in configFiles) {
    final file = File(path);
    if (await file.exists()) {
      await _appendFileContent(file, buffer);
    }
  }

  // 3. Gom toàn bộ mã nguồn .dart trong thư mục lib/
  buffer.writeln('--- 3. TOÀN BỘ MÃ NGUỒN DART (lib/) ---');
  if (await libDir.exists()) {
    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    // Sắp xếp theo tên đường dẫn cho gọn gàng
    dartFiles.sort((a, b) => a.path.compareTo(b.path));

    for (final file in dartFiles) {
      await _appendFileContent(file, buffer);
    }
  }

  // Xuất ra file .txt chuẩn UTF-8 để không bị lỗi chữ tiếng Việt
  await outputFile.writeAsString(buffer.toString(), encoding: utf8);

  print('Da gom code thanh cong!');
  print('File duoc luu tai: ${outputFile.absolute.path}');
}

// Hàm đệ quy giúp vẽ sơ đồ cây thư mục
Future<void> _writeDirectoryTree(
  Directory dir,
  StringBuffer buffer,
  String indent,
) async {
  final entities = dir.listSync()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final entity in entities) {
    final name = entity.path.replaceAll('\\', '/').split('/').last;
    if (entity is Directory) {
      buffer.writeln('$indent[Thu muc] $name/');
      await _writeDirectoryTree(entity, buffer, '$indent  ');
    } else if (entity is File) {
      buffer.writeln('$indent- $name');
    }
  }
}

// Hàm đọc nội dung từng file và đánh dấu tên file rõ ràng
Future<void> _appendFileContent(File file, StringBuffer buffer) async {
  final normalizedPath = file.path.replaceAll('\\', '/');
  buffer.writeln('\n==================================================');
  buffer.writeln('FILE: $normalizedPath');
  buffer.writeln('==================================================');
  try {
    final bytes = await file.readAsBytes();
    final content = utf8.decode(bytes, allowMalformed: true);
    buffer.writeln(content);
  } catch (e) {
    buffer.writeln('[Loi khong doc duoc file nay: $e]');
  }
}