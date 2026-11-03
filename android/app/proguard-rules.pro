# Flutter keeps what it needs through its own consumer rules; this file is
# for app-specific additions. Keep it small and explain every rule.

# Play Core is referenced by the Flutter engine for deferred components,
# which Finora does not use.
-dontwarn com.google.android.play.core.**

# flutter_local_notifications stores scheduled reminders with Gson, which
# reads generic types through reflection.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
