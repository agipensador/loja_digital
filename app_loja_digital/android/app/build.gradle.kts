import groovy.json.JsonSlurper

// Um productFlavor por loja, lido de flavors/<id>/flavor.json (criado pelo
// tool/new_flavor.sh). Cada flavor tem o seu google-services.json em
// android/app/src/<id>/ — o plugin do Google Services escolhe sozinho.
val storeFlavorDirs: List<File> = rootProject.file("../flavors")
    .listFiles()
    ?.filter { File(it, "flavor.json").exists() }
    ?.sortedBy { it.name }
    ?: emptyList()

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "br.com.inforic.app_loja_digital"
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
        applicationId = "br.com.inforic.app_loja_digital"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "Loja Digital"
    }

    if (storeFlavorDirs.isNotEmpty()) {
        flavorDimensions += "loja"
        productFlavors {
            storeFlavorDirs.forEach { dir ->
                @Suppress("UNCHECKED_CAST")
                val cfg = JsonSlurper().parse(File(dir, "flavor.json")) as Map<String, Any>
                create(dir.name) {
                    dimension = "loja"
                    applicationId = cfg["androidPackage"] as String
                    manifestPlaceholders["appLabel"] = cfg["appName"] as String
                }
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
  // Import the Firebase BoM
  implementation(platform("com.google.firebase:firebase-bom:34.1.0"))


  // TODO: Add the dependencies for Firebase products you want to use
  // When using the BoM, don't specify versions in Firebase dependencies
  implementation("com.google.firebase:firebase-analytics")


  // Add the dependencies for any other desired Firebase products
  // https://firebase.google.com/docs/android/setup#available-libraries
}

flutter {
    source = "../.."
}
