plugins {
    id("com.android.application")
    id("kotlin-android")

    // ✅ Firebase Google Services Plugin
    id("com.google.gms.google-services")

    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.omerates.nakliyeyg.nakliyeuyg"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ Flutter local notifications için şart
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.logigo.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // ✅ Firebase BoM (Android tarafı uyumlu versiyonları yönetir)
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))

    // ✅ Desugaring dependency (flutter_local_notifications istiyor)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // (Opsiyonel) Analytics istersen aç:
    // implementation("com.google.firebase:firebase-analytics")
}

flutter {
    source = "../.."
}