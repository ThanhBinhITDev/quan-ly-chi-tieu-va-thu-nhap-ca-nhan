plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.studentfinance.android"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Cần bật để flavor đặt tên app riêng (`app_name`) cho từng bản.
    buildFeatures {
        resValues = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.studentfinance.android"
        manifestPlaceholders["appName"] = "Student Finance"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Hai bản cài song song trên cùng máy:
    //  - `prod`: bản thật, trỏ API + Supabase test qua HTTPS
    //  - `dev` : bản phát triển, trỏ API local (10.0.2.2:3000) và gọi HTTP
    // Khác applicationId nên Android coi là hai app riêng, không ghi đè nhau.
    flavorDimensions += "env"
    productFlavors {
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Student Finance")
            manifestPlaceholders["appName"] = "Student Finance"
        }
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Student Finance Dev")
            manifestPlaceholders["appName"] = "Student Finance Dev"
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
