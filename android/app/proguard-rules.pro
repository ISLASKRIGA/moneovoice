# ─── Firebase / Crashlytics ────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# ─── Flutter ───────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ─── Drift / SQLite ────────────────────────────────────────────────────────────
-keep class drift.** { *; }
-keep class com.simolus3.** { *; }
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**

# ─── speech_to_text ────────────────────────────────────────────────────────────
-keep class com.csdcorp.speech_to_text.** { *; }
-dontwarn com.csdcorp.speech_to_text.**

# ─── permission_handler ────────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# ─── path_provider ─────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.pathprovider.** { *; }

# ─── share_plus ────────────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.share.** { *; }
-dontwarn dev.fluttercommunity.plus.share.**

# ─── shared_preferences ────────────────────────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ─── printing / pdf ────────────────────────────────────────────────────────────
-keep class com.randal.avocado.** { *; }
-dontwarn com.randal.avocado.**

# ─── Google Fonts (descarga desde red, no hay código nativo que proteger) ──────
-dontwarn com.google.fonts.**

# ─── Kotlin coroutines / reflection ────────────────────────────────────────────
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**
-keep class kotlin.Metadata { *; }

# ─── Enums (necesarios para Drift y otros) ─────────────────────────────────────
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ─── Modelos serializados / anotaciones ────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable

# ─── Evitar warnings de librerías internas de Java ─────────────────────────────
-dontwarn java.lang.instrument.**
-dontwarn sun.misc.**
