# Flutter 관련 규칙
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# 이미지 관련 플러그인 보호
-keep class * implements io.flutter.plugin.common.MethodCallHandler { *; }
-keep class * implements io.flutter.plugin.common.StreamRequestHandler { *; }

# 네이티브 메서드 보호
-keepclasseswithmembernames class * {
    native <methods>;
}

# 일반적인 Flutter 보호 규칙
-keep class * extends java.lang.annotation.Annotation { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
