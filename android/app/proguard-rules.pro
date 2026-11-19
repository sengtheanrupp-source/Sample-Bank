# Release builds are shrunk by R8. ML Kit (used by mobile_scanner for KHQR
# scanning) creates its registrars by reflection, so R8 must not strip them,
# or the camera scanner silently fails in release:
#   "Could not instantiate ...BarcodeRegistrar: NoSuchMethodException <init>"
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
-keep class dev.steenbakker.mobile_scanner.** { *; }
