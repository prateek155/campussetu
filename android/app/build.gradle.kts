plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.campussetu.campussetu"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    buildFeatures {
        resValues = true
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "app"

    productFlavors {
        create("user") {
            dimension = "app"
            applicationId = "com.campussetu.campussetu"
            resValue("string", "app_name", "CampusSetu")
        }
        create("admin") {
            dimension = "app"
            applicationId = "com.campussetu.admin"
            resValue("string", "app_name", "CampusSetu Admin")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}