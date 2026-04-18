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

# ─── OkHttp3 (used by cached_network_image and http package internally) ───────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# ─── Cached Network Image / Flutter Cache Manager ─────────────────────────────
-keep class com.baseflow.** { *; }
-keep class flutter_cache_manager.** { *; }
-dontwarn com.baseflow.**

# ─── Keep all model classes from being stripped (JSON parsing) ─────────────────
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ─── Dart/Flutter AOT: Keep reflection-heavy annotations ──────────────────────
-keepattributes InnerClasses
-keepattributes SourceFile
-keepattributes LineNumberTable

# ─── Razorpay ──────────────────────────────────────────────────────────────────
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# ─── File Picker ───────────────────────────────────────────────────────────────
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# ─── NFC Manager ───────────────────────────────────────────────────────────────
-keep class io.github.okmnkn.nfcmanager.** { *; }

# ─── Network Info Plus ─────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.network_info.** { *; }

# ─── Package Info Plus ─────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# ─── Permission Handler ────────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }

# ─── Contacts ──────────────────────────────────────────────────────────────────
-keep class com.github.taher.flutter_contacts.** { *; }