import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties (gitignored; copy
// key.properties.example) or, if that file is absent, from environment
// variables. With neither, the release build falls back to the debug key so
// that reviewers can still build it. A debug-signed APK is not fit for
// distribution.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(propertyName: String, envName: String): String? =
    (keyProperties.getProperty(propertyName) ?: System.getenv(envName))
        ?.takeIf { it.isNotBlank() }

val releaseStoreFile = signingValue("storeFile", "SNAPSYNC_KEYSTORE_FILE")
val releaseStorePassword = signingValue("storePassword", "SNAPSYNC_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "SNAPSYNC_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "SNAPSYNC_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }

android {
    namespace = "com.monir.snapsync"
    // 37: required by permission_handler_android 14.x.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.monir.snapsync"
        // 24: required by permission_handler_android (camera_android_camerax and
        // workmanager_android need 23).
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Both come from `version:` in pubspec.yaml (1.0.0+1).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                // A relative path is resolved against android/app.
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            // The Flutter Gradle plugin adds its own embedding rules and, if
            // present, proguard-rules.pro.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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

if (!hasReleaseSigning) {
    gradle.taskGraph.whenReady {
        if (allTasks.any { it.name.contains("Release") && it.project == project }) {
            logger.warn(
                "WARNING: No release signing config found (android/key.properties " +
                    "or SNAPSYNC_KEYSTORE_* environment variables). Signing the " +
                    "release build with the DEBUG key. Do not distribute this APK.",
            )
        }
    }
}
