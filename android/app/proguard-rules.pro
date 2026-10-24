# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.kts.

# Keep Kotlin Metadata
-keepattributes *Annotation*
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep Gson serialization/deserialization
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep V2Ray DTO classes (used for JSON serialization)
-keep class com.vpn.fortivavpn.dto.** { *; }
-keepclassmembers class com.vpn.fortivavpn.dto.** { *; }

# Keep ProfileItem and related configuration classes
-keep class com.vpn.fortivavpn.handler.** { *; }
-keepclassmembers class com.vpn.fortivavpn.handler.** { *; }

# Keep libv2ray native interface
-keep class libv2ray.** { *; }
-keep class fortivacore.** { *; }
-keep class go.** { *; }
# Psiphon's psi package, bound into the same libgojni.so. Its native code
# calls the provider methods by name (service/PsiphonCore.kt). The app
# does not ship PsiphonTunnel.java, so there is no ca.psiphon rule.
-keep class psi.** { *; }

# Keep Service classes
-keep class com.vpn.fortivavpn.service.** { *; }

# Keep Receiver classes
-keep class com.vpn.fortivavpn.receiver.** { *; }

# Keep Google Play Services (Play Billing and the in-app review)
-keep class com.google.android.gms.** { *; }

# Keep MMKV
-keep class com.tencent.mmkv.** { *; }

# Keep R8 full mode rules
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep BuildConfig
-keep class com.vpn.fortivavpn.BuildConfig { *; }

# Keep WebView JavaScript Interface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep any classes that might be accessed via reflection
-keep class com.vpn.fortivavpn.fmt.** { *; }
-keep class com.vpn.fortivavpn.util.** { *; }
