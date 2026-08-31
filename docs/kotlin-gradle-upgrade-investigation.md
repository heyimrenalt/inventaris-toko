# Kotlin / Gradle Plugin Upgrade — Investigation Report

**Date:** 2026-08-23 · **Scope:** facts only, nothing modified, no upgrade recommended.

---

## 1. Current state

| Item | Value | Source (file:line) |
|---|---|---|
| Gradle wrapper | **9.1.0** (`gradle-9.1.0-all.zip`) | `android/gradle/wrapper/gradle-wrapper.properties:5` |
| Android Gradle Plugin (AGP) | **9.0.1** | `android/settings.gradle.kts:22` |
| Kotlin Gradle Plugin (KGP) | **2.3.20** (declared, `apply false`) | `android/settings.gradle.kts:23` |
| Flutter plugin loader | **1.0.0** | `android/settings.gradle.kts:21` |
| Flutter Gradle plugin | applied, version from SDK includeBuild | `android/app/build.gradle.kts:4`, `settings.gradle.kts:11` |
| `compileSdk` | **36** (`flutter.compileSdkVersion`) | `android/app/build.gradle.kts:9` → `FlutterExtension.kt:23` |
| `targetSdk` | **36** (`flutter.targetSdkVersion`) | `android/app/build.gradle.kts:27` → `FlutterExtension.kt:34` |
| `minSdk` | **24** (`flutter.minSdkVersion`) | `android/app/build.gradle.kts:26` → `FlutterExtension.kt:26` |
| `ndkVersion` | **28.2.13676358** (`flutter.ndkVersion`) | `android/app/build.gradle.kts:10` → `FlutterExtension.kt:42` |
| Java source/target compatibility | **17** | `android/app/build.gradle.kts:13-14` |
| Kotlin `jvmTarget` | **JVM_17** | `android/app/build.gradle.kts:57` |
| Core library desugaring | enabled, `desugar_jdk_libs:2.1.4` | `android/app/build.gradle.kts:17`, `:66` |
| Local JDK running Gradle | **Java 22** (per compiler warning) | build output |
| `android.builtInKotlin` | **false** (deprecated flag) | `android/gradle.properties:6` |
| `android.newDsl` | **false** (deprecated flag) | `android/gradle.properties:4` |
| `gradle/libs.versions.toml` | **does not exist** anywhere in the repo | `find` returned nothing |

### Every plugin declared (complete list — there are 4 root/settings + 2 app-level, not 5)

`android/settings.gradle.kts` `plugins {}` block, lines 20-24:
1. `dev.flutter.flutter-plugin-loader` **1.0.0** (applied)
2. `com.android.application` **9.0.1** (`apply false`)
3. `org.jetbrains.kotlin.android` **2.3.20** (`apply false`)

`android/app/build.gradle.kts` `plugins {}` block, lines 1-5:
4. `com.android.application` (version inherited from settings)
5. `dev.flutter.flutter-gradle-plugin` (version from Flutter SDK includeBuild)

`android/build.gradle.kts` declares **no plugins at all** — it only configures repositories, relocates build dirs, and registers a `clean` task.

> **Note on "5 plugins":** the number 5 in the noted deadline does *not* refer to Gradle plugins declared in this project. It matches exactly the 5 **pub packages** named in Flutter's Built-in Kotlin warning (§3.1). That is almost certainly the origin of the "5 plugins" memory.

## 2. Flutter / Dart

| Item | Value | Source |
|---|---|---|
| Dart SDK constraint | `^3.12.2` | `pubspec.yaml:22` |
| Flutter SDK constraint | **none declared** | `pubspec.yaml` has no `flutter:` key under `environment:` |
| Installed Flutter | **3.44.6**, stable, rev `ee80f08bbf` (2026-07-08) | `flutter --version` |
| Installed Dart | **3.12.2** | `flutter --version` |
| Flutter SDK path | `/opt/homebrew/share/flutter` | `android/local.properties` |

## 3. Build result and warnings (verbatim)

`flutter build apk --debug` — **SUCCEEDED** in 42.1s, produced `build/app/outputs/flutter-apk/app-debug.apk`. No failure to report.

### 3.1 Flutter tool warning (the headline one)

```
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): android_alarm_manager_plus, file_picker, package_info_plus, share_plus, workmanager_android
Future versions of Flutter will fail to build if your app uses plugins that apply KGP.

Please check the changelogs of these plugins and upgrade to a version that supports Built-in Kotlin.
If no such version exists, report the issue to the plugin. If necessary, here is a guide on filing 
an issue against a plugin: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers#report-incompatible-kotlin-gradle-plugin-usage-to-plugin-authors

If you are a plugin author, please migrate your plugin to Built-in Kotlin using this guide: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors
```

Note the wording: **"Future versions of Flutter will fail"** — no version number, no date. This is the only "deadline"-shaped statement the build emits.

### 3.2 AGP option deprecations

```
WARNING: The option setting 'android.newDsl=false' is deprecated.
It will be removed in version 10.0 of the Android Gradle plugin.
```
```
WARNING: The option setting 'android.builtInKotlin=false' is deprecated.
It will be removed in version 10.0 of the Android Gradle plugin.
```

### 3.3 Gradle 10 deprecations (from `--warning-mode all`)

```
Invocation of Task.project at execution time has been deprecated. This will fail with an error in Gradle 10. This API is incompatible with the configuration cache, which will become the only mode supported by Gradle in a future release. Consult the upgrading guide for further information: https://docs.gradle.org/9.1.0/userguide/upgrading_version_7.html#task_project
```

Groovy space-assignment deprecations (all "scheduled to be removed in Gradle 10"), emitted for these properties — all originate in **third-party plugin `build.gradle` files**, not in this project's own Kotlin-DSL files:

```
Properties should be assigned using the 'propName = value' syntax. Setting a property via the Gradle-generated 'propName value' or 'propName(value)' syntax in Groovy DSL has been deprecated. This is scheduled to be removed in Gradle 10. Use assignment ('<X> = <value>') instead. Consult the upgrading guide for further information: https://docs.gradle.org/9.1.0/userguide/upgrading_version_8.html#groovy_space_assignment_syntax
```
for `X` ∈ { `coreLibraryDesugaringEnabled`, `group`, `multiDexEnabled`, `namespace`, `ndkVersion`, `version` }.

Summary line: **`3 warnings`** (Gradle's own deprecation counter).

### 3.4 Kotlin compiler warnings

```
w: ⚠️ Deprecated 'org.jetbrains.kotlin.android' plugin usage
```
```
w: file:///Users/rikiadityaramadhan/inventaris-toko/android/app/build.gradle.kts:7:1: 'fun Project.android(configure: Action<BaseAppModuleExtension>): Unit' is deprecated. Replaced by com.android.build.api.dsl.ApplicationExtension.
w: file:///Users/rikiadityaramadhan/.pub-cache/hosted/pub.dev/flutter_plugin_android_lifecycle-2.0.35/android/build.gradle.kts:26:1: 'fun Project.android(configure: Action<LibraryExtension>): Unit' is deprecated. Replaced by com.android.build.api.dsl.LibraryExtension.
w: file:///Users/rikiadityaramadhan/.pub-cache/hosted/pub.dev/image_picker_android-0.8.13+19/android/build.gradle.kts:34:1: 'fun Project.android(configure: Action<LibraryExtension>): Unit' is deprecated. Replaced by com.android.build.api.dsl.LibraryExtension.
w: file:///opt/homebrew/share/flutter/packages/integration_test/android/build.gradle.kts:34:1: 'fun Project.android(configure: Action<LibraryExtension>): Unit' is deprecated. Replaced by com.android.build.api.dsl.LibraryExtension.
```

The `BaseAppModuleExtension` one at `android/app/build.gradle.kts:7` is a direct consequence of `android.newDsl=false`; AGP also says of that class:

```
This class is not used for the public extensions in AGP when android.newDsl=true, which is the default in AGP 9.0, and will be removed in AGP 10.0.
```

Warnings from **Flutter's own Gradle plugin** (i.e. not fixable in this repo):

```
w: file:///opt/homebrew/share/flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt:13:8 'interface ApkVariant : Any, BaseVariant, InstallableVariant, AndroidArtifactVariant, InternalBaseVariant' is deprecated. Deprecated in Java.
w: file:///opt/homebrew/share/flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt:662:69 'interface ApkVariant : ...' is deprecated. Deprecated in Java.
w: file:///opt/homebrew/share/flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterPluginUtils.kt:12:8 'interface BaseVariantOutput : Any, OutputFile' is deprecated. Deprecated in Java.
```

### 3.5 Java compiler warnings

```
Java compiler version 22 has deprecated support for compiling with source/target version 8.
To suppress this warning, set android.javaCompile.suppressSourceTargetDeprecationWarning=true in gradle.properties.
warning: [options] source value 8 is obsolete and will be removed in a future release
warning: [options] target value 8 is obsolete and will be removed in a future release
warning: [options] To suppress warnings about obsolete options, use -Xlint:-options.
```
Origin: **`workmanager_android`**, which pins `JavaVersion.VERSION_1_8` (`workmanager_android-0.10.6/android/build.gradle:59-60`). Not this app's setting — the app itself is on 17.

```
Note: /Users/rikiadityaramadhan/.pub-cache/hosted/pub.dev/android_alarm_manager_plus-4.0.8/android/src/main/java/dev/fluttercommunity/plus/androidalarmmanager/AlarmService.java uses or overrides a deprecated API.
Note: Recompile with -Xlint:deprecation for details.
```

### 3.6 Benign / false-positive warning

```
> Configure project :gradle
WARNING: Unsupported Kotlin plugin version.
The `embedded-kotlin` and `kotlin-dsl` plugins rely on features of Kotlin `2.2.0` that might work differently than in the requested version `2.2.20`.
```
This is emitted while configuring **`:gradle`, the Flutter SDK's own included build** (`$FLUTTER/packages/flutter_tools/gradle`), and concerns 2.2.0 vs 2.2.20 inside that build. It has nothing to do with this app's KGP 2.3.20 and is not actionable here.

## 4. Dependency-imposed AGP / Kotlin constraints

The 5 packages Flutter names, with what each actually declares (all read from `~/.pub-cache`):

| Package | Installed | Latest on pub | Its `build.gradle` KGP | Its AGP classpath | Its compileSdk / minSdk | Java |
|---|---|---|---|---|---|---|
| `android_alarm_manager_plus` | 4.0.8 | **5.1.1** | `1.9.23` | `8.3.1` | 34 / 19 | 17 |
| `file_picker` | 10.3.10 | **12.0.0** | `1.8.22` | `8.5.1` | `flutter.compileSdkVersion` / 21 | 11 |
| `package_info_plus` | 9.0.1 | **10.2.1** | `2.2.0` | `8.12.1` | `flutter.compileSdkVersion` / 19 | 17 |
| `share_plus` | 11.1.0 | **13.3.0** | `1.7.22` | `8.3.1` | 34 / 19 | 17 |
| `workmanager_android` | 0.10.6 | **0.10.8** | conditional | — | 35 / 23 | **1.8** |

Important detail: these are **classpath declarations inside each plugin's own buildscript block**, which Gradle ignores for included plugin projects — the app's resolved AGP 9.0.1 / KGP 2.3.20 is what actually compiles them. They are *not* enforced minimums or maximums. **No package in the tree declares an AGP or Kotlin minimum that this project fails.** The build succeeds.

`workmanager_android` 0.10.6 is the only one that has already been adapted for AGP 9 — it detects AGP major ≥ 9 and skips applying KGP *unless* the app opts out (`workmanager_android-0.10.6/android/build.gradle:19-24`):

```groovy
// apps set `android.builtInKotlin=false` in gradle.properties
// (flutter/flutter#183910) to keep the legacy KGP path working for
// unmigrated plugins, so this module must apply KGP itself unless built-in
// Kotlin is active. See #710 and #722.
def agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.tokenize('.')[0] as int
def builtInKotlin = agpMajor >= 9 &&
    project.findProperty('android.builtInKotlin')?.toString() != 'false'
if (!builtInKotlin) {
    apply plugin: 'kotlin-android'
}
```

So `workmanager_android` appears in the warning **only because this project sets `android.builtInKotlin=false`**. It would drop off the list on its own if that flag were flipped — which is exactly why the other four matter: they apply KGP unconditionally, so flipping the flag is currently blocked by them, not by workmanager.

Also relevant, already documented in the repo: `pubspec.yaml:51-59` records that `file_picker` ≥ 11.0.0 skips applying KGP under AGP 9 and consequently fails to compile `FilePickerPlugin.kt` in this project — i.e. the *newer* file_picker was already tried and reverted. That constraint should be re-tested against 12.0.0 before assuming it still holds.

## 5. UNKNOWN — needs a human decision or external verification

1. **Is there actually a deadline, and what is it?** Nothing in the build output states a date or a version number. The Flutter warning says only "future versions of Flutter will fail". No source in this repo substantiates a dated deadline. **The premise of the original task is unverified and the build currently emits nothing that would substantiate it.**
2. **Distribution channel — Play Store or sideloaded APK?** This determines whether Google Play's target-API deadlines apply *at all*. Evidence in-repo points to sideloading but is not conclusive: `applicationId` is still the template default `com.example.inventaris_toko` (`app/build.gradle.kts:8,22`, with the template `TODO` comment intact), release builds are signed with the **debug** keystore (`:36`), and `versionCode`/`versionName` are still `1`/`1.0.0`. A Play-published app could not ship in that state. If sideloaded, Play target-API deadlines are irrelevant and `targetSdk 36` is already current regardless.
3. **Which Flutter release actually turns the KGP warning into an error?** Requires checking the Flutter breaking-change page / release notes; not determinable from this repo. Also: is this project pinned to Flutter 3.44.6, or does it track stable? `pubspec.yaml` declares **no Flutter SDK constraint**, so an unattended `flutter upgrade` could pull in the breaking release with no guard.
4. **Whether the four unmigrated plugins have Built-in-Kotlin-compatible releases.** Newer majors exist for all four (5.1.1 / 12.0.0 / 10.2.1 / 13.3.0) but whether any of them stops applying KGP was **not** verified — that needs reading each changelog or downloading the versions. Not done, per the no-upgrade constraint.
5. **Whether `file_picker` 12.0.0 still has the AGP-9 breakage** documented at `pubspec.yaml:51-59` for 11.x. Unverified.
6. **Tolerance for the `android.newDsl=false` / `android.builtInKotlin=false` pair.** Both are deprecated and slated for removal in AGP 10. They are separate migrations with separate blockers and no stated date.
7. **Target JDK policy.** Gradle runs on Java 22 locally; the app targets 17; `workmanager_android` drags in source/target 8. Whether the local JDK is pinned anywhere (CI, other machines) is unknown — there is no CI config or toolchain declaration in the repo.

---

*No files were modified. `flutter build apk --debug` and `./gradlew :app:assembleDebug --warning-mode all` were run read-only to capture warnings; both succeeded.*
