plugins {
    // Versions come from settings.gradle.kts; requesting one here conflicts with
    // the plugins the included flutter_tools build puts on the classpath.
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.jaredsburrows.license")
    // TODO: Re-enable Firebase after adding google-services.json for com.vpn.fortivavpn
    // id("com.google.gms.google-services")
    // id("com.google.firebase.crashlytics")
}

import java.util.Properties
import java.io.FileInputStream

flutter {
    source = "../.."
}

android {
    namespace = "com.vpn.fortivavpn"
    // path_provider_android pulls in the `jni` plugin, which needs a newer
    // NDK than Flutter's default. NDK releases are backward compatible, so
    // pinning the highest requirement satisfies every plugin at once.
    ndkVersion = "28.2.13676358"
    compileSdk = 36

    // Load keystore properties
    val keystorePropertiesFile = rootProject.file("keystore.properties")
    val keystoreProperties = Properties().apply {
        if (keystorePropertiesFile.exists()) {
            load(FileInputStream(keystorePropertiesFile))
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.vpn.fortivavpn"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Straight from pubspec.yaml's `version:` via the Flutter Gradle
        // plugin, which is also where iOS gets CFBundleVersion. These used to
        // be read out of local.properties instead — a gitignored, per-machine
        // file that Flutter does not reliably rewrite. When it went stale the
        // build silently shipped the wrong versionCode, and a fresh clone with
        // no such file fell back to 1.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // Splits temporarily disabled to fix flutter run debug artifact detection
        // val abiFilterList = (properties["ABI_FILTERS"] as? String)?.split(';')
        // splits {
        //     abi {
        //         isEnable = true
        //         reset()
        //         if (abiFilterList != null && abiFilterList.isNotEmpty()) {
        //             include(*abiFilterList.toTypedArray())
        //         } else {
        //             include(
        //                 "arm64-v8a",
        //                 "armeabi-v7a",
        //                 "x86_64",
        //                 "x86"
        //             )
        //         }
        //         isUniversalApk = abiFilterList.isNullOrEmpty()
        //     }
        // }

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")

            // `flutter build apk --target-platform` builds Flutter and the
            // Dart code only for the platforms it lists. The Flutter Gradle
            // plugin still packs every other native library (the core,
            // libtun2socks, mmkv, dartjni) for arm, arm64 and x86_64. An APK
            // built for android-arm alone then has a lib/arm64-v8a folder
            // with no libflutter.so, and a 64-bit phone installs that folder
            // and fails at launch. So pack native code only for the ABIs
            // Flutter was built for. With no --target-platform, Flutter
            // passes its default list (arm, arm64, x86_64), so the Play
            // bundle is unchanged. tool/release.sh checks each APK's ABIs.
            val flutterAbis = mapOf(
                "android-arm" to "armeabi-v7a",
                "android-arm64" to "arm64-v8a",
                "android-x64" to "x86_64",
            )
            (project.findProperty("target-platform") as? String)?.let { platforms ->
                ndk {
                    abiFilters.clear()
                    platforms.split(",").forEach { platform ->
                        abiFilters += flutterAbis[platform]
                            ?: throw GradleException("unknown target platform '$platform'")
                    }
                }
            }
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("libs")
        }
    }


    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        viewBinding = true
        buildConfig = true
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            // androidx.datastore ships this library for multi-process
            // DataStore. It is 16 KB aligned, but its build note says NDK
            // r20 (r27 in 1.3.0-alpha11), and Play flags any library built
            // with an NDK older than r28. Only MultiProcessDataStoreFactory
            // loads it. shared_preferences_android, the one user of
            // DataStore here, builds a single-process DataStore, so nothing
            // in the app can load it. The check at the bottom of this file
            // fails the release build if that changes. See #105.
            excludes += "**/libdatastore_shared_counter.so"
        }
    }

}

// Suppress "source value 8 is obsolete" warnings from dependencies
tasks.withType<JavaCompile> {
    options.compilerArgs.add("-Xlint:-options")
}

// libdatastore_shared_counter.so is left out of the package (see packaging
// above). The only code that loads it is DataStore's
// System.loadLibrary("datastore_shared_counter"). R8 drops that call when
// nothing can reach it, and the string goes with it. If the string is still
// in the release dex, some dependency now uses a multi-process DataStore,
// and the app would crash the first time that code runs. Fail the build
// instead, and put the library back or find what started using it.
tasks.matching { it.name == "minifyReleaseWithR8" }.configureEach {
    doLast {
        // ISO-8859-1 maps each byte to one char, so this is a byte search.
        val hits = outputs.files.asFileTree.matching { include("**/*.dex") }.filter { dex ->
            String(dex.readBytes(), Charsets.ISO_8859_1).contains("datastore_shared_counter")
        }
        if (!hits.isEmpty) {
            throw GradleException(
                "The release dex still loads libdatastore_shared_counter.so, " +
                    "which packaging excludes. Found in: " +
                    hits.files.joinToString { it.name } + ". See #105."
            )
        }
    }
}

dependencies {
    // Local .aar/.jar Libraries
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar", "*.jar"))))

    // Manually added Flutter Embedding removed to restore standard plugin behavior

    // AndroidX Libraries
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.activity)

    // UI
    implementation(libs.material)
    implementation(libs.toasty)

    // Storage and Data
    implementation(libs.mmkv.static.v222)
    implementation(libs.gson)

    // Flutter plugin dependencies are added automatically by the Flutter Gradle
    // plugin from .flutter-plugins-dependencies; do not list them here. That
    // includes Play Services: in_app_purchase brings Play Billing, which
    // brings play-services-base. It and play.review below bring
    // play-services-basement, which is what the manifest's gms.version
    // meta-data resolves against.

    // Kotlin Coroutines
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.coroutines.core)

    // Google Play's in-app review card (MainActivity.requestReview). Also in
    // the channel APK, where the app never calls it: only a Play install can
    // be rated, so ReviewPrompt checks the installer first.
    implementation(libs.play.review)

    // QR decoding of share links (util/QRCodeDecoder.kt)
    implementation(libs.core)
    implementation(libs.multidex)

    // Testing
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    testImplementation(libs.org.mockito.mockito.inline)
    testImplementation(libs.mockito.kotlin)
    testImplementation(libs.org.json)

    // Java 8+ Desugaring
    coreLibraryDesugaring(libs.desugar.jdk.libs)

}

