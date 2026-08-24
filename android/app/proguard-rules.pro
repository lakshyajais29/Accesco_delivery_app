# Razorpay checkout.
#
# Flutter shrinks code with R8 on release builds. The Razorpay SDK is driven
# from a WebView through @JavascriptInterface and reflection, so R8 has no
# reference to those members and strips them — the sheet then opens to a
# blank screen in release and works perfectly in debug, which is a very
# expensive bug to find late.
#
# Rules are Razorpay's own, from their Android integration guide.
-keepattributes *Annotation*
-keepattributes JavascriptInterface

-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# The plugin dispatches results by method name.
-keepclasseswithmembers class * {
    public void onPayment*(...);
}

# Razorpay ships ProGuard-sensitive optimisation notes; inlining breaks the
# WebView bridge.
-optimizations !method/inlining/*
