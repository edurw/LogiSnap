import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chave de assinatura do release. O arquivo fica fora do repositório
// (ver .gitignore); sem ele o build cai na chave de debug em vez de quebrar.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

android {
    namespace = "dev.chico.logisnap"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")
                ?.let { rootProject.file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    defaultConfig {
        applicationId = "dev.chico.logisnap"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Clone sem a chave: assina com debug para o build não quebrar.
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Nome do APK distribuido: LogiSnap-v<versao>.apk (a versao vem do pubspec.yaml).
val distributionApkName = "LogiSnap-v${flutter.versionName}.apk"

androidComponents {
    onVariants { variant ->
        if (variant.buildType == "release") {
            variant.outputs.forEach { output ->
                (output as? com.android.build.api.variant.impl.VariantOutputImpl)
                    ?.outputFileName
                    ?.set(distributionApkName)
            }
        }
    }
}

// O plugin do Flutter copia o APK para outputs/flutter-apk, mas usando o nome
// original; a ferramenta `flutter build apk` tambem exige encontrar
// app-release.apk nesse diretorio. Entao copiamos o APK renomeado para la,
// mantendo o alias app-release.apk que o tooling espera.
val copyDistributionApk =
    tasks.register<Copy>("copyDistributionApk") {
        val apkDir = layout.buildDirectory.dir("outputs/apk/release")
        from(apkDir) { include(distributionApkName) }
        from(apkDir) {
            include(distributionApkName)
            rename { "app-release.apk" }
        }
        into(layout.buildDirectory.dir("outputs/flutter-apk"))
    }

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy(copyDistributionApk)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
