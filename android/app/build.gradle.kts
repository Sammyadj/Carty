import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Secrets live in ignored local properties or CI environment variables.
val releaseProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.isFile) propertiesFile.inputStream().use { load(it) }
}
val signingInputs = mapOf(
    "storeFile" to "CARTY_ANDROID_STORE_FILE",
    "storePassword" to "CARTY_ANDROID_STORE_PASSWORD",
    "keyAlias" to "CARTY_ANDROID_KEY_ALIAS",
    "keyPassword" to "CARTY_ANDROID_KEY_PASSWORD",
).mapValues { (property, variable) ->
    System.getenv(variable) ?: releaseProperties.getProperty(property)
}
val releaseKeystore = signingInputs["storeFile"]
    ?.takeIf { it.isNotBlank() }
    ?.let { rootProject.file(it) }

val verifyReleaseSigning by tasks.registering {
    group = "verification"
    description = "Requires explicit Android Release signing without a debug-key fallback."
    doLast {
        val missing = signingInputs.filterValues { it.isNullOrBlank() }.keys
        if (missing.isNotEmpty()) {
            throw GradleException(
                "Android Release signing is not configured. Missing: ${missing.joinToString()}. " +
                    "Use android/key.properties or CARTY_ANDROID_* environment variables. " +
                    "See docs/ANDROID_SIGNING.md. Debug builds do not need these credentials.",
            )
        }
        if (releaseKeystore?.isFile != true) {
            throw GradleException("Android Release keystore is unavailable. See docs/ANDROID_SIGNING.md.")
        }
    }
}

// Check before expensive compilation, and also for direct signing-task invocations.
tasks.matching { it.name == "preReleaseBuild" || it.name == "validateSigningRelease" }
    .configureEach { dependsOn(verifyReleaseSigning) }

android {
    namespace = "com.Samueladjei.carty_app"
    compileSdk = flutter.compileSdkVersion
    // Match the highest NDK required by our Android plugins.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Preserve the existing application identity when configuring store signing.
        applicationId = "com.Samueladjei.carty_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = releaseKeystore
            storePassword = signingInputs["storePassword"]
            keyAlias = signingInputs["keyAlias"]
            keyPassword = signingInputs["keyPassword"]
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
