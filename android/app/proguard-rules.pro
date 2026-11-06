# Phase 9 release build. Flutter and the Firebase SDKs ship consumer rules;
# these keep the Firestore and Functions model classes the app reflects on.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
