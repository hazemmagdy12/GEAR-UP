plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.sim.gear_up"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // 🔥 التعديل هنا: ضفنا حرفين is في الأول عشان الكوتلن تفهمها
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // 🔥 التعديل هنا: اختصرناها عشان نعالج التحذير التاني
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.sim.gear_up"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // لو إنت لسه مضفتش بصمة الريليس فوق، خلي الكلمة دي "debug" مؤقتاً عشان النسخة تطلع
            signingConfig = signingConfigs.getByName("debug")

            // السطر السحري بتاعنا بس بلغة Kotlin 🔥
            ndk.debugSymbolLevel = "NONE"
        }
    }
} // 🔥 القوس ده هو اللي كان ناقص وعامل المشكلة! 🔥

flutter {
    source = "../.."
}

// 🔥 إضافة المكتبة
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}