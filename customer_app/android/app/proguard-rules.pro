# Flutter Proguard Rules
-dontoptimize
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Play Core & Split Compat
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

# Firebase Core, Auth, Firestore, Messaging, Storage, RemoteConfig, Analytics
-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature,InnerClasses,EnclosingMethod
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# Speech to Text
-keep class com.csdcorp.speech_to_text.** { *; }
-dontwarn com.csdcorp.speech_to_text.**

# Package Info Plus
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-dontwarn dev.fluttercommunity.plus.packageinfo.**

# SharedPreferences & PathProvider
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# Desugaring & Reflection safety
-dontwarn okio.**
-dontwarn java.lang.invoke.**

