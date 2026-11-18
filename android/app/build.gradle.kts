import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key comes from the environment in CI and from android/key.properties on a local machine.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
fun signing(env: String, property: String): String? =
    System.getenv(env)?.takeIf { it.isNotEmpty() } ?: keystoreProperties[property] as String?
val hasUploadKey = signing("ANDROID_KEYSTORE_PATH", "storeFile") != null

android {
    namespace = "com.shravangoswami.securevault"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = signing("ANDROID_KEYSTORE_ALIAS", "keyAlias") ?: ""
            keyPassword = signing("ANDROID_KEY_PASSWORD", "keyPassword") ?: ""
            storeFile = signing("ANDROID_KEYSTORE_PATH", "storeFile")?.let { file(it) }
            storePassword = signing("ANDROID_KEYSTORE_PASSWORD", "storePassword") ?: ""
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.shravangoswami.securevault"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // Installs beside the Play build, so testing never touches real vaults.
            applicationIdSuffix = ".dev"
        }
        release {
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "release" else "debug")
        }
    }
}

flutter {
    source = "../.."
}
