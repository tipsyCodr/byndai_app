# Flutter rules
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Firebase rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# AndroidX and Camera
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Video Player
-keep class io.flutter.plugins.videoplayer.** { *; }

# Wakelock
-keep class wakelock.** { *; }

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod

# Google Play Core
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Provider
-keep class com.provider.** { *; }

# Flutter Secure Storage
-keep class com.it_solutions.flutter_secure_storage.** { *; }

# Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Pinput
-keep class com.compose.pinput.** { *; }

# Mobile Scanner
-keep class dev.clauidofp7.mobile_scanner.** { *; }

# Desugaring
-keep class j$.** { *; }
-dontwarn j$.**