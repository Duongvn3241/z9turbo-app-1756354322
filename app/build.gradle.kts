plugins {
  id("com.android.application") version "8.5.2"
  id("org.jetbrains.kotlin.android") version "2.0.20"
  id("org.jetbrains.kotlin.plugin.compose") version "2.0.20"
}
android {
  namespace = "com.z9turbo"
  compileSdk = 34
  defaultConfig {
    applicationId = "com.z9turbo"
    minSdk = 26
    targetSdk = 34
    versionCode = 1
    versionName = "1.0"
  }
  buildTypes {
    release {
      isMinifyEnabled = false
      proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    }
  }
  buildFeatures { compose = true }
  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
  kotlinOptions { jvmTarget = "17" }
}
dependencies {
  val composeBom = platform("androidx.compose:compose-bom:2024.08.00")
  implementation(composeBom); androidTestImplementation(composeBom)
  implementation("androidx.activity:activity-compose:1.9.2")
  implementation("androidx.compose.ui:ui")
  implementation("androidx.compose.ui:ui-tooling-preview")
  implementation("androidx.compose.material3:material3")
  debugImplementation("androidx.compose.ui:ui-tooling")
  debugImplementation("androidx.compose.ui:ui-test-manifest")
  androidTestImplementation("androidx.test.ext:junit:1.2.1")
  androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
}
