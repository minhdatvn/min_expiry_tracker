# PROJECT CONTEXT: MinExpiryTracker

> **Hướng dẫn dành cho A.I ở phiên làm việc mới:**
> File này mô tả toàn bộ ý tưởng, kiến trúc, cơ sở dữ liệu, phiên bản thư viện và tiến độ hiện tại của ứng dụng **MinExpiryTracker**. Hãy đọc kỹ toàn bộ tài liệu này trước khi đề xuất code hoặc hướng dẫn tiếp theo.
>
> **Phong cách phối hợp mong muốn của người dùng:**
> - Trình độ lập trình: Cơ bản, đang học và làm ứng dụng Flutter/Dart trên Android.
> - Hướng dẫn **chậm rãi, từng bước nhỏ một** (mỗi lượt chỉ làm 1 bước, xác nhận xong mới chuyển sang bước tiếp theo).
> - Giải thích ngắn gọn, trực quan lý do dùng từng widget hoặc cú pháp Dart.
> - Giao tiếp và chú thích trong code bằng **tiếng Việt**; giao diện ứng dụng (UI) và tên biến/hàm bằng **tiếng Anh**.

---

## 1. Tổng quan & Ý tưởng ứng dụng

- **Tên ứng dụng:** MinExpiryTracker
- **Kho lưu trữ GitHub:** `https://github.com/minhdatvn/min_expiry_tracker.git`
- **Nền tảng mục tiêu:** Android (xây dựng bằng Flutter / Dart, giao diện Material 3 với tông màu chủ đạo `Colors.teal`).
- **Mục đích:** Ứng dụng quản lý hạn sử dụng của các vật phẩm gia dụng (thuốc, mỹ phẩm, thực phẩm, đồ dùng khác) theo phong cách tối giản, dễ dùng.
- **Nguyên tắc thiết kế cốt lõi:**
  1. **100% Offline:** Không cần máy chủ (server), không cần đăng nhập tài khoản, toàn bộ dữ liệu và ảnh lưu cục bộ trên điện thoại.
  2. **Nhắc nhở linh hoạt:** Mỗi vật phẩm có thể tự cài đặt các mốc cảnh báo riêng trước ngày hết hạn.
  3. **Hỗ trợ PAO (Period After Opening):** Tự động tính hạn sử dụng rút ngắn sau khi mở nắp (rất quan trọng với mỹ phẩm, thuốc nhỏ mắt...).
  4. **Sao lưu di động gọn nhẹ:** Dữ liệu và cả hình ảnh sản phẩm được đóng gói gọn trong **duy nhất 1 file `.json`** để người dùng tự lưu lên Google Drive hoặc chuyển sang máy khác.

---

## 2. Tính năng & Nghiệp vụ cốt lõi (Business Logic)

### 2.1. Tính hạn sử dụng thực tế (`effectiveExpiryDate`)
- Mỗi vật phẩm bắt buộc có **Hạn sử dụng trên bao bì (`expiryDate`)**.
- Nếu người dùng nhập thêm **Ngày mở nắp (`openedDate`)** và **Số tháng dùng sau khi mở (`paoMonths`)**, ứng dụng sẽ tính ngày hết hạn PAO: `openedDate + paoMonths`.
- **Quy tắc:** `effectiveExpiryDate` sẽ tự động lấy **ngày nào đến trước** giữa `expiryDate` và ngày hết hạn PAO.
- Số ngày còn lại (`daysRemaining`) được tính theo chênh lệch ngày thực tế (bỏ qua giờ/phút) giữa `effectiveExpiryDate` và ngày hôm nay.

### 2.2. Hiển thị trực quan & Quy tắc màu sắc trạng thái (`ItemCard`)
- Danh sách trên màn hình chính hỗ trợ lọc nhanh theo 5 nhóm (`All`, `Medicine`, `Cosmetics`, `Food`, `Other`) và **luôn tự động sắp xếp vật phẩm sắp hết hạn lên đầu** (`daysRemaining` tăng dần).
- Màu sắc nhãn đếm ngược và viền thẻ được tính dựa theo mốc cảnh báo riêng (`alertDays`) của từng món:
  - **Đỏ (`Colors.red`):** Đã hết hạn, hết hạn hôm nay (`days <= 0`), hoặc có từ 2 mốc cảnh báo trở lên và rơi vào mốc gần nhất (VD: `<= 7` ngày).
  - **Cam (`Colors.orange`):** Rơi vào phạm vi mốc cảnh báo xa nhất (VD: `<= 30` ngày).
  - **Xanh lá (`Colors.green`):** Còn an toàn.

### 2.3. Lưu trữ hình ảnh cục bộ bằng Base64
- Người dùng có thể chụp ảnh (Camera) hoặc chọn từ Thư viện ảnh (Gallery) thông qua `image_picker`.
- Ảnh được tự động thu nhỏ và nén ngay khi chọn (`maxWidth: 600`, `maxHeight: 600`, `imageQuality: 70`, dung lượng còn khoảng 25–40 KB).
- Dữ liệu ảnh được mã hóa thành chuỗi văn bản `imageBase64` lưu thẳng vào SQLite và file JSON sao lưu; khi hiển thị trên UI thì giải mã sang `Uint8List` (`imageBytes`) để vẽ bằng `Image.memory`.

### 2.4. Hệ thống thông báo Offline (`NotifyService`)
- Chạy hoàn toàn cục bộ, đặt lịch nhắc nhở vào **9:00 sáng** giờ địa phương của từng ngày mốc trong `alertDays` (bỏ qua các mốc đã rơi vào quá khứ).
- **Quy ước mã định danh thông báo (Notification ID):**
  - ID `0`: Dành riêng cho nút chuông gửi thông báo kiểm thử (Test Notification) trên AppBar.
  - ID cho vật phẩm: `itemId * 100 + index` (VD: vật phẩm có `id = 5` sẽ dùng các ID `500`, `501`, `502`...). Khi sửa hoặc xóa vật phẩm `id`, hệ thống lọc và hủy toàn bộ thông báo có `request.id ~/ 100 == itemId`.
- Dùng chế độ `AndroidScheduleMode.inexactAllowWhileIdle` để nhắc bền bỉ ngay cả khi máy khóa màn hình mà không cần xin quyền Exact Alarm phức tạp.

### 2.5. Sao lưu & Khôi phục toàn phần (`BackupService`)
- **Sao lưu (Export):** Đọc toàn bộ vật phẩm từ SQLite → đóng gói JSON kèm chữ ký nhận diện (`app: "MinExpiryTracker"`, `version: 1`, `exportedAt`, `items`) → ghi ra file tạm `MinExpiryTracker_yyyy-MM-dd.json` → mở bảng chia sẻ gốc của Android (`share_plus`) để lưu vào Google Drive hoặc bộ nhớ máy.
- **Khôi phục (Import):** Mở trình chọn file Android (`FileType.any` để tránh lỗi Android ẩn file `.json`) → kiểm tra tính hợp lệ của file JSON **trước khi** xóa dữ liệu cũ → gọi `clearAllItems()` và `cancelAllAlerts()` → nạp lại từng vật phẩm vào SQLite và tự động đặt lại toàn bộ lịch thông báo theo ID mới.

---

## 3. Môi trường phát triển & Công nghệ (Tech Stack)

### 3.1. Cấu hình máy phát triển
- **Hệ điều hành:** Windows 11
- **Trình soạn thảo:** VS Code (**không cài Android Studio**, chỉ dùng Android SDK độc lập phiên bản `35.0.1`)
- **Thư mục dự án cục bộ:** `D:\Codes\min_expiry_tracker`
- **Flutter SDK:** `3.32.6` (Channel stable) | **Dart SDK:** `^3.8.1`
- **Máy ảo Android có sẵn:** `mincloset_emu`

### 3.2. Danh sách thư viện (`pubspec.yaml`) & Lưu ý cú pháp quan trọng
> **LƯU Ý QUAN TRỌNG CHO A.I:** Dự án sử dụng các phiên bản thư viện đời mới có thay đổi cú pháp (breaking changes). Tuyệt đối tuân thủ đúng cú pháp dưới đây khi viết/sửa code:

| Thư viện | Phiên bản | Vai trò & Lưu ý cú pháp bắt buộc |
| :--- | :--- | :--- |
| `sqflite` | `^2.4.2` | Cơ sở dữ liệu SQLite offline. |
| `path` | `^1.9.1` | Ghép đường dẫn file database an toàn. |
| `intl` | `^0.20.2` | Định dạng ngày tháng (`MMM dd, yyyy`, `yyyy-MM-dd`). |
| `image_picker` | `^1.2.1` | Chụp/chọn ảnh và nén kích thước. |
| `flutter_local_notifications` | `^20.1.0` | **Bản v20+ bắt buộc dùng Named Parameters:** `_plugin.initialize(settings: ...)`, `_plugin.show(id: ..., title: ..., body: ..., notificationDetails: ...)`, `_plugin.cancel(id: ...)`, `_plugin.zonedSchedule(id: ..., title: ..., body: ..., scheduledDate: ..., notificationDetails: ..., androidScheduleMode: ...)`. **Đã bỏ** tham số `uiLocalNotificationDateInterpretation`. |
| `timezone` | `^0.10.1` | Xử lý múi giờ `TZDateTime` cho lịch thông báo. |
| `path_provider` | `^2.1.5` | Lấy thư mục tạm (`getTemporaryDirectory`) để tạo file backup. |
| `share_plus` | `^12.0.2` | Dùng cú pháp mới: `SharePlus.instance.share(ShareParams(files: [...], subject: ...))`. |
| `file_picker` | `^11.0.3` | **Bản v11+ đã bỏ `.platform`:** Gọi trực tiếp `FilePicker.pickFiles(type: FileType.any)`. |

---

## 4. Kiến trúc & Cấu trúc thư mục

Ứng dụng áp dụng kiến trúc phân lớp đơn giản (Simple Layered Architecture) theo mô hình Singleton cho các Service:

```text
min_expiry_tracker/
├── SETUP_PC.md                        # Ghi chú cài đặt dự án trên máy tính mới
├── PROJECT_CONTEXT.md                 # Tài liệu ngữ cảnh tổng thể dự án (file này)
├── pubspec.yaml                       # Khai báo 9 thư viện dự án
├── android/
│   └── app/
│       ├── build.gradle.kts           # Cấu hình Gradle (Kotlin DSL) + Desugaring
│       └── src/main/AndroidManifest.xml # Quyền thông báo & Receiver khởi động lại lịch
└── lib/
    ├── main.dart                      # Điểm khởi chạy: WidgetsFlutterBinding, NotifyService.init(), MaterialApp
    ├── models/
    │   └── item_model.dart            # Class HouseholdItem, logic PAO, Base64, toMap()/fromMap()
    ├── services/
    │   ├── database_service.dart      # Singleton SQLite (CRUD + clearAllItems)
    │   ├── notify_service.dart        # Singleton thông báo offline (init, test, schedule, cancel, cancelAll)
    │   └── backup_service.dart        # Singleton sao lưu & khôi phục file .json
    ├── widgets/
    │   └── item_card.dart             # Widget thẻ vật phẩm hiển thị ảnh/icon, PAO badge, đếm ngược màu sắc
    └── screens/
        ├── home_screen.dart           # Màn hình chính: Lọc danh mục, danh sách sắp xếp theo HSD, nút Test & Settings
        ├── add_edit_screen.dart       # Màn hình Thêm/Sửa/Xóa vật phẩm, chụp ảnh, chọn lịch, tùy chỉnh mốc alertDays
        └── settings_screen.dart       # Màn hình Cài đặt: Nút Backup Data, Restore Data và thông tin phiên bản
```

*(Ghi chú: File test mẫu mặc định `test/widget_test.dart` đã được xóa để tránh lỗi tham chiếu `MyApp`).*

---

## 5. Thiết kế cơ sở dữ liệu (SQLite Schema)

- **Tên file DB:** `min_expiry_tracker.db` (Version `1`)
- **Tên bảng:** `items`

| Tên cột | Kiểu SQLite | Bắt buộc | Mô tả |
| :--- | :--- | :---: | :--- |
| `id` | `INTEGER PRIMARY KEY AUTOINCREMENT` | Có | Khóa chính tự tăng (SQLite tự cấp khi thêm mới). |
| `name` | `TEXT` | Có | Tên vật phẩm (VD: Vitamin C Serum, Panadol). |
| `category` | `TEXT` | Có | Danh mục: `Medicine`, `Cosmetics`, `Food`, `Other`. |
| `expiryDate` | `TEXT` | Có | Ngày hết hạn bao bì (chuỗi chuẩn `ISO-8601`). |
| `openedDate` | `TEXT` | Không | Ngày mở nắp (chuỗi `ISO-8601` hoặc `null`). |
| `paoMonths` | `INTEGER` | Không | Số tháng sử dụng sau mở nắp (VD: `6`, `12`). |
| `quantity` | `INTEGER` | Không | Số lượng hiện có. |
| `imageBase64` | `TEXT` | Không | Chuỗi ảnh đã nén mã hóa Base64. |
| `owner` | `TEXT` | Không | Người sử dụng (VD: Me, Mom, Family). |
| `alertDays` | `TEXT` | Không | Danh sách mốc cảnh báo lưu dạng chuỗi cách nhau bởi dấu phẩy (VD: `"30,7"`). |

---

## 6. Cấu hình Android bắt buộc

Để `flutter_local_notifications` hoạt động và biên dịch thành công trên Android:

1. **File `android/app/build.gradle.kts`:**
   - Trong `compileOptions`: Bật `isCoreLibraryDesugaringEnabled = true` (cùng `JavaVersion.VERSION_11`).
   - Cuối file trong `dependencies`: Thêm `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.
2. **File `android/app/src/main/AndroidManifest.xml`:**
   - Quyền phía trên `<application>`: `POST_NOTIFICATIONS` và `RECEIVE_BOOT_COMPLETED`.
   - Tên hiển thị ứng dụng: `android:label="MinExpiryTracker"`.
   - Bên trong `<application>`: Khai báo `ScheduledNotificationReceiver` và `ScheduledNotificationBootReceiver` để duy trì lịch nhắc sau khi khởi động lại điện thoại.

---

## 7. Trạng thái hiện tại & Lộ trình tiếp theo

### Đã hoàn thành
- [x] Chốt ý tưởng, kiến trúc và thiết kế dữ liệu offline hoàn chỉnh.
- [x] Viết hoàn chỉnh toàn bộ 9 file trong `lib/` (Model, 3 Services, Widget, 3 Screens, Main).
- [x] Khởi tạo bộ khung Android, cài đủ 9 thư viện trong `pubspec.yaml` và đồng bộ lên GitHub.
- [x] Xử lý toàn bộ lỗi phiên bản thư viện (`flutter_local_notifications v20`, `file_picker v11`) — lệnh `flutter analyze` đạt **`No issues found!`**.
- [x] Kiểm tra môi trường máy tính (`flutter doctor` xanh Android toolchain) và xác nhận có máy ảo `mincloset_emu`.

### Đang thực hiện & Bước tiếp theo
- [ ] **Kiểm thử chạy thực tế:** Khởi chạy trên máy ảo `mincloset_emu` (và điện thoại Android thật) để kiểm tra toàn bộ luồng: Thêm/Sửa/Xóa vật phẩm, tính PAO, đính kèm ảnh Base64, nút Test chuông thông báo, Sao lưu & Khôi phục file `.json`.
- [ ] **Đồng bộ GitHub:** Commit và push các bản sửa lỗi gần nhất cùng cấu hình Android (`build.gradle.kts`, `AndroidManifest.xml`) và file `PROJECT_CONTEXT.md` lên GitHub.
- [ ] **Hoàn thiện & Đóng gói:** Tùy chỉnh biểu tượng ứng dụng (App Icon), kiểm tra trải nghiệm UI/UX (tìm kiếm, sửa lỗi phát sinh nếu có) và đóng gói file cài đặt `.apk` (`flutter build apk --release`) để cài trực tiếp lên điện thoại dùng hàng ngày.