# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }

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
