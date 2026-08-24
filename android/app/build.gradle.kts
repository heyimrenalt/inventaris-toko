import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("app/key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.tokomama.inventaris"
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
        applicationId = "com.tokomama.inventaris"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // isar_community_flutter_libs requires minSdk 23.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystoreProperties) {
            create("release") {
                storeFile = rootProject.file("app/" + keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Release builds must be signed with the permanent release keystore
            // (see android/app/key.properties, generated once and never
            // regenerated — regenerating it or losing it breaks updates for
            // anyone who already installed the app, forcing an uninstall and
            // losing their local Isar data). Deliberately left *unsigned*
            // rather than falling back to the debug keystore, which would
            // produce an APK that can never update a real install. The
            // missing-keystore case is turned into a hard failure by the
            // taskGraph check at the bottom of this file — not by throwing
            // here, since this block is evaluated at configuration time for
            // every Gradle invocation, which would break `flutter run` and
            // the integration tests on a fresh clone that has no keystore.
            signingConfig = if (hasKeystoreProperties) {
                signingConfigs.getByName("release")
            } else {
                null
            }
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

// Fails a release build that has no keystore, while leaving debug builds
// (`flutter run`, `flutter test integration_test`) working on a fresh clone.
// Checked against the resolved task graph rather than thrown from the
// `release { }` block above: that block runs during configuration on *every*
// Gradle invocation, so throwing there made even a debug run impossible
// without a keystore.
gradle.taskGraph.whenReady {
    if (hasKeystoreProperties) return@whenReady
    val releaseTask = allTasks.firstOrNull { task ->
        task.project == project &&
            task.name.contains("Release") &&
            listOf("assemble", "bundle", "package", "install").any { task.name.startsWith(it) }
    } ?: return@whenReady

    throw GradleException(
        "Cannot run '${releaseTask.name}': android/app/key.properties not found. " +
        "Release builds must be signed with the permanent release keystore, not " +
        "the debug keystore — a debug-signed APK can never update a real install. " +
        "Copy android/app/key.properties.example to android/app/key.properties and " +
        "fill in the real passwords, or generate the keystore first with keytool."
    )
}
