# [M3] ProGuard/R8 rules for SSH Dashboard release builds
# Keep Flutter engine and plugin classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep classes required by flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep local_auth plugin classes
-keep class io.flutter.plugins.localauth.** { *; }

# Keep Kotlin metadata (needed by some plugins)
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable

# Keep Android lifecycle classes used by Flutter
-keep class androidx.lifecycle.** { *; }

# Don't warn about missing references in third-party libs
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn kotlin.**
-dontwarn kotlinx.**

# Preserve line number information for debugging stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
