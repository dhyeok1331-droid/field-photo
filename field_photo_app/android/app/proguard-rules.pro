# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }

# Play Core (deferred components 미사용 — R8 누락 클래스 경고 무시)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# mailer / JavaMail (SMTP)
-keep class com.sun.mail.** { *; }
-keep class javax.mail.** { *; }

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# geolocator
-keep class com.baseflow.geolocator.** { *; }

# camera
-keep class io.flutter.plugins.camera.** { *; }

# Kotlin coroutines
-keepnames class kotlinx.coroutines.** { *; }
