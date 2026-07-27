plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.punho"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.punho"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
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
        }
    }

    // O ficheiro sai com o nome e a versão em vez de "app-release.apk":
    // Punho_v0.0.4.apk. Assim o que se instala por USB diz-se a si próprio, e
    // segue o mesmo padrão do instalador Windows (Punho_Setup_v0.0.2.exe).
    // `applicationVariants` está depreciado no AGP 8 mas continua a funcionar;
    // quando sair (AGP 9) o substituto é a Variant API nova.
    @Suppress("DEPRECATION")
    applicationVariants.all {
        val versao = versionName
        outputs.all {
            (this as com.android.build.gradle.internal.api.BaseVariantOutputImpl)
                .outputFileName = "Punho_v$versao.apk"
        }
    }
}

flutter {
    source = "../.."
}
