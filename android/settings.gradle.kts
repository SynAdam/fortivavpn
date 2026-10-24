pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val propertiesFile = java.io.File("local.properties")
        if (propertiesFile.exists()) {
            properties.load(java.io.FileInputStream(propertiesFile))
        }
        properties.getProperty("flutter.sdk")
    }

    if (flutterSdkPath != null) {
        includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
    }

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}

// flutter-plugin-loader registers each Android plugin from
// .flutter-plugins-dependencies as a Gradle subproject. Do not replace it with
// hardcoded include()/projectDir entries: pub-cache paths are machine- and
// version-specific and break every other checkout.
//
// AGP and Kotlin versions must be resolved here rather than in the root
// build.gradle.kts, because the included flutter_tools build puts them on the
// classpath first. Keep them in sync with `agp` and `kotlin` in
// gradle/libs.versions.toml.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.10.1" apply false
    id("com.android.library") version "8.10.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.0" apply false
}

rootProject.name = "FortivaVPN"
include(":app")
