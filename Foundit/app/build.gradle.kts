import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

val mapsApiKey: String = localProps.getProperty("MAPS_API_KEY", "YOUR_GOOGLE_MAPS_API_KEY")
val googleWebClientId: String = localProps.getProperty("GOOGLE_WEB_CLIENT_ID", "")

android {
    namespace = "com.example.foundit"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.foundit"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
        val escapedMapsKey = mapsApiKey.replace("\\", "\\\\").replace("\"", "\\\"")
        buildConfigField("String", "MAPS_API_KEY", "\"$escapedMapsKey\"")
        val escapedId = googleWebClientId.replace("\\", "\\\\").replace("\"", "\\\"")
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"$escapedId\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    // Core
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)

    // Compose BOM
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)

    // Navigation
    implementation(libs.androidx.navigation.compose)

    // Lifecycle / ViewModel
    implementation(libs.androidx.lifecycle.viewmodel.compose)

    // Network
    implementation(libs.retrofit)
    implementation(libs.retrofit.gson)
    implementation(libs.okhttp.logging)
    implementation(libs.gson)

    // Coroutines
    implementation(libs.kotlinx.coroutines.android)

    // Image loading
    implementation(libs.coil.compose)

    // DataStore
    implementation(libs.androidx.datastore.preferences)

    // Google Maps
    implementation(libs.maps.compose)
    implementation(libs.play.services.maps)
    implementation(libs.play.services.location)
    implementation(libs.play.services.auth)

    // ML Kit (QR Scanning)
    implementation(libs.mlkit.barcode.scanning)

    // Permissions
    implementation(libs.accompanist.permissions)

    // CameraX
    implementation(libs.camerax.core)
    implementation(libs.camerax.camera2)
    implementation(libs.camerax.lifecycle)
    implementation(libs.camerax.view)

    // ZXing (QR Code 產生)
    implementation(libs.zxing.core)

    // 聊天室即時（Socket.IO）
    implementation(libs.socketIoClient)

    // Firebase（推播通知）— 需要 app/google-services.json
    // 取消下方兩行的註解並新增 google-services.json 以啟用 FCM 推播
    // implementation(platform(libs.firebase.bom))
    // implementation(libs.firebase.messaging)
    // implementation(libs.firebase.analytics)

    // Testing
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
