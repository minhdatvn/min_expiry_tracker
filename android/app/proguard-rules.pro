# Giữ thuộc tính kiểu dữ liệu cho Gson / Reflection khi bật R8
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses

# Giữ nguyên các lớp nhận thông báo nền của flutter_local_notifications
-keep class com.dexterous.** { *; }

# Giữ nguyên các lớp model của device_calendar (tránh lỗi đồng bộ Lịch trên bản Release)
-keep class com.builttoroam.devicecalendar.** { *; }

# Giữ nguyên các lớp chuyển đổi dữ liệu của Gson (được cả thông báo và Lịch dùng nội bộ)
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Giữ lớp nhận diện chữ của Google ML Kit khi nén R8 bản Release
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**