plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Allekirjoitus: CI kirjoittaa avainsäilön tiedostoon salaisuudesta ANDROID_KEYSTORE_B64.
val ksFile: String? = System.getenv("ANDROID_KEYSTORE_FILE")

android {
    namespace = "org.aether.attest"
    compileSdk = 35
    defaultConfig {
        applicationId = "org.aether.attest"
        minSdk = 31
        targetSdk = 35
        versionCode = (System.getenv("GITHUB_RUN_NUMBER") ?: "1").toInt()
        versionName = "0.3"
    }
    signingConfigs {
        if (ksFile != null) {
            create("release") {
                storeFile = file(ksFile)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            isMinifyEnabled = false
            if (ksFile != null) signingConfig = signingConfigs.getByName("release")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    packaging {
        resources { excludes += setOf("META-INF/versions/9/OSGI-INF/MANIFEST.MF", "META-INF/*.SF", "META-INF/*.RSA", "META-INF/*.DSA") }
    }
    lint {
        abortOnError = true
        warningsAsErrors = false
        checkReleaseBuilds = true
    }
}

dependencies {
    implementation("org.bouncycastle:bcprov-jdk18on:1.81")
    testImplementation("junit:junit:4.13.2")
}
