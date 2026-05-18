plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.paejae.capstone"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.paejae.capstone"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        // 네이티브 크래시 방지를 위한 추가 설정
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            isDebuggable = false
            // R8 최적화도 비활성화
            proguardFiles(getDefaultProguardFile("proguard-android.txt"))
        }
        debug {
            applicationIdSuffix = ".debug"
            isDebuggable = true
        }
    }

    packaging {
        resources {
            pickFirsts += setOf(
                "**/libc++_shared.so",
                "**/libjsc.so",
                "**/libflutter.so"
            )
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1"
            )
        }
        jniLibs {
            useLegacyPackaging = true
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    // 네이티브 크래시 방지를 위한 안정 버전 사용
    implementation("androidx.core:core-ktx:1.8.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.6.1")

    // 네이티브 크래시 방지를 위한 추가 의존성
    implementation("androidx.startup:startup-runtime:1.1.1")
}
