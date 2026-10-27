# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.kts.
#
# Keep only what is reached by name: classes Gson fills by reflection,
# classes native code calls, and the names Android stores. Libraries bring
# their own rules for their own classes (Gson, Play Services, Play
# Billing). Up to 2.2.0 this file also kept all of Gson, all of Play
# Services and five of the app's packages whole, which left 46% of the
# code unoptimized, and Google Play reported it ("R8 optimization"). R8
# writes the figures into the bundle at
# BUNDLE-METADATA/com.android.tools/r8.json.

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Gson reads and writes the V2Ray config and the profiles kept in MMKV by
# field name, enum constants included, so the field names are the stored
# format. Their methods are left to R8.
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.vpn.fortivavpn.dto.** {
    <fields>;
    <init>(...);
}
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep libv2ray native interface
-keep class libv2ray.** { *; }
-keep class fortivacore.** { *; }
-keep class go.** { *; }
# Psiphon's psi package, bound into the same libgojni.so. Its native code
# calls the provider methods by name (service/PsiphonCore.kt). The app
# does not ship PsiphonTunnel.java, so there is no ca.psiphon rule.
-keep class psi.** { *; }

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
