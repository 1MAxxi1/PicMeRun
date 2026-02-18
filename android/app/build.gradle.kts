android {
    namespace = "com.picmerun.picmerun"

    // ✅ Versión fija para compatibilidad con TFLite y ML Kit
    compileSdk = 36

    // ✅ Versión exacta del NDK requerida por tus plugins de IA
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.picmerun.picmerun"

        // ✅ Mantener en 21 por requerimiento de Gregorio
        minSdk = 21

        // ✅ Usamos la referencia de flutter directamente para evitar el error de "unsupported"
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // Nota: Se usa getByName en .kts para mayor precisión
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}