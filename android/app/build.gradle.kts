import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val keystoreFile = rootProject.file("key.properties")
    if (keystoreFile.exists()) {
        load(FileInputStream(keystoreFile))
    }
}

val hasReleaseKeystore = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
    .all { (keystoreProperties[it] as String?).isNullOrBlank().not() }
val allowDebugSigningForRelease = project.hasProperty("slipstream.devSigning")

android {
    namespace = "com.slipstream"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.slipstream"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

if (!hasReleaseKeystore && !allowDebugSigningForRelease) {
    gradle.taskGraph.whenReady {
        val buildsRelease = allTasks.any { task ->
            task.project == project &&
                (task.name == "assembleRelease" || task.name == "bundleRelease")
        }
        if (buildsRelease) {
            throw GradleException(
                "Release build has no signing keystore. Add android/key.properties " +
                    "pointing at the real release keystore, or pass " +
                    "-Pslipstream.devSigning to sign with the debug key (local testing only).",
            )
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

dependencies {
    implementation(files("libs/slipstreamcore.aar"))
}