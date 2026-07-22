plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.inventaris_toko"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (uses java.time APIs
        // that need desugaring on minSdk < 26).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.inventaris_toko"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // isar_community_flutter_libs requires minSdk 23.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // This project had never been release-built before this round of
            // on-device verification. R8 minification/obfuscation (on by
            // Flutter's own default, even with no `isMinifyEnabled` set here)
            // turned out to break multiple plugins that resolve their own
            // classes by name at runtime — androidx.work's WorkDatabase_Impl
            // (reflective no-arg constructor lookup) and
            // android_alarm_manager_plus's RebootBroadcastReceiver
            // (ComponentName built from `.class`, resolved post-rename) both
            // crashed with no proguard-rules.pro in place to protect them.
            // Turning shrinking off entirely rather than chasing each
            // plugin's specific reflection pattern one at a time — this app
            // has no APK-size constraint that would justify that risk.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
