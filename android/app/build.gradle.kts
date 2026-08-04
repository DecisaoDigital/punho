import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Identidade permanente da app. `com.example.*` é o placeholder do
    // template do Flutter e a Google Play recusa-o à entrada — ficou cá dentro
    // até 4 de Agosto de 2026, com o TODO original por cima. Mudar o
    // applicationId faz do Punho outra app aos olhos do Android: quem tiver a
    // anterior instalada tem de desinstalar (os dados locais vão com ela; o
    // servidor mantém tudo). Por isso se mudou com uma instalação no mundo, e
    // não com trinta. Não voltar a mexer.
    namespace = "pt.decisaodigital.punho"
    compileSdk = flutter.compileSdkVersion
    // Fixo e não `flutter.ndkVersion`: cinco plugins (image_picker,
    // package_info_plus, path_provider, shared_preferences, url_launcher) pedem
    // o 27, e o que o Flutter escolhe é mais antigo. No build local dá aviso; no
    // Ubuntu do CI parte por incompatibilidade de toolchain (task #197).
    //
    // As versões de NDK são retrocompatíveis, portanto fixar a mais alta que
    // algum plugin pede é o que a própria mensagem do Gradle recomenda.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "pt.decisaodigital.punho"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            check(keystorePropertiesFile.exists()) {
                "Falta android/key.properties. Um APK release do Punho tem de ser assinado com a chave de release."
            }
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }

    buildTypes {
        release {
            // Nunca publicar uma release assinada pela chave de depuração.
            signingConfig = signingConfigs.getByName("release")
        }
    }

    // O ficheiro sai com o nome e a versão em vez de "app-release.apk":
    // Punho_v0.0.4.apk. Assim o que se instala por USB diz-se a si próprio, e
    // segue o mesmo padrão do instalador Windows (Punho_Setup_v0.0.2.exe).
    // `applicationVariants` está depreciado no AGP 8 mas continua a funcionar;
    // quando sair (AGP 9) o substituto é a Variant API nova.
    //
    // O sufixo da arquitectura não é enfeite: com `--split-per-abi` saem três
    // APKs, e sem ele os três queriam escrever o mesmo ficheiro. O Gradle
    // rebentava com "Failed to create .../Punho_v0.2.1.apk", que não diz
    // nada sobre a causa (apanhado a publicar a v0.2.1).
    @Suppress("DEPRECATION")
    applicationVariants.all {
        val versao = versionName
        outputs.all {
            val saida =
                this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val arquitectura = saida.getFilter(com.android.build.OutputFile.ABI)
            saida.outputFileName = if (arquitectura == null) {
                "Punho_v$versao.apk"
            } else {
                "Punho_v${versao}_$arquitectura.apk"
            }
        }
    }
}

flutter {
    source = "../.."
}
