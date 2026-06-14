import java.util.Properties
import java.io.FileInputStream

// Reads versionName (X.Y.Z) and versionCode (+N) from pubspec.yaml.
fun pubspecVersion(): Pair<String, Int> {
    val pubspec = file("../../pubspec.yaml")
    if (!pubspec.exists()) return Pair("1.0.0", 1)
    val match = Regex("""^version:\s+(\d+\.\d+\.\d+)\+(\d+)""", RegexOption.MULTILINE)
        .find(pubspec.readText())
    val name = match?.groupValues?.getOrNull(1) ?: "1.0.0"
    val code = match?.groupValues?.getOrNull(2)?.toIntOrNull() ?: 1
    return Pair(name, code)
}

val pubspecVer = pubspecVersion()

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.artsdarts.valorantlineups"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            if (keyPropertiesFile.exists()) {
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
                storeFile = file("${rootProject.projectDir}/${keyProperties["storeFile"]}")
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.artsdarts.valorantlineups"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = pubspecVer.second
        versionName = pubspecVer.first
    }

    buildTypes {
        release {
            signingConfig = if (keyPropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
