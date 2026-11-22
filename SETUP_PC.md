# Hướng dẫn đồng bộ & chạy MinExpiryTracker trên máy tính

## Bước 1: Tải code từ GitHub và tạo khung Android
Mở Terminal trong VS Code và chạy lần lượt các lệnh sau:

```bash
git clone [https://github.com/TEN_TAI_KHOAN_CUA_BAN/min_expiry_tracker.git](https://github.com/TEN_TAI_KHOAN_CUA_BAN/min_expiry_tracker.git)
cd min_expiry_tracker
flutter create --platforms=android .
```

*(Nếu lệnh `flutter create` có lỡ ghi đè file nào trong `lib/`, chạy lệnh `git checkout -- lib/` để khôi phục nguyên vẹn code).*

## Bước 2: Cài toàn bộ gói bổ trợ (Packages)
```bash
flutter pub add intl image_picker sqflite path flutter_local_notifications timezone path_provider share_plus file_picker
```

## Bước 3: Cấu hình quyền thông báo cho Android (Làm 1 lần)

### 3.1. File `android/app/build.gradle.kts`
Thêm 2 dòng sau vào đúng khối `compileOptions` và `dependencies`:
```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

### 3.2. File `android/app/src/main/AndroidManifest.xml`
Thêm bên trên thẻ `<application ...>`:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Thêm bên trong thẻ `<application ...>` (ngay trước `</application>`):
```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    </intent-filter>
</receiver>
```

## Bước 4: Chạy ứng dụng
Cắm điện thoại Android (đã bật USB Debugging) hoặc mở máy ảo, rồi chạy:
```bash
flutter run
```
