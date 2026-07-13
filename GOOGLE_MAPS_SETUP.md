# Configuración de Google Maps para HieloPedido

Esta guía explica detalladamente qué APIs activar y en qué archivos de configuración colocar la **API Key de Google Maps** para que la aplicación de Flutter compile y cargue los mapas correctamente.

---

## 1. APIs que deben estar habilitadas en Google Cloud Console

Para que todas las funciones (renderizado, trazado de rutas y geocodificación) funcionen, la clave API creada debe tener habilitadas las siguientes **5 APIs** en la biblioteca de Google Cloud:

1. **SDK de mapas para Android** (Maps SDK for Android)
2. **SDK de mapas para iOS** (Maps SDK for iOS)
3. **API de direcciones** (Directions API - usada para trazar la ruta de las calles)
4. **API de geocodificación** (Geocoding API - usada para coordenadas y direcciones)
5. **API de lugares** (Places API - usada para autocompletar búsquedas de locales)

> [!WARNING]
> **Restricciones de aplicaciones:** En la fase de desarrollo, mantén la restricción de aplicaciones en **"Ninguno"** (None) para evitar errores CORS o de firma digital cuando la app consulte la API de Direcciones desde el código Dart. Asegúrate de configurar la restricción en **"Restringir clave"** para permitir únicamente las 5 APIs listadas arriba.

---

## 2. Dónde colocar la API Key en el Proyecto Flutter

### 🤖 Android
Edita el archivo [AndroidManifest.xml](file:///c:/Users/maxce/Desktop/proyecto/android/app/src/main/AndroidManifest.xml) y agrega el bloque `<meta-data>` con tu clave dentro del elemento `<application>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application ...>
        
        <!-- API KEY DE GOOGLE MAPS -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="TU_API_KEY_AQUI" />
            
    </application>
</manifest>
```

---

### 🍏 iOS
Edita el archivo [AppDelegate.swift](file:///c:/Users/maxce/Desktop/proyecto/ios/Runner/AppDelegate.swift). Asegúrate de importar `GoogleMaps` e invocar `provideAPIKey` dentro del método `didFinishLaunchingWithOptions`:

```swift
import Flutter
import UIKit
import GoogleMaps // 1. Importar la librería

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 2. Colocar la clave de Google Maps aquí:
    GMSServices.provideAPIKey("TU_API_KEY_AQUI")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

---

## 3. Comandos para probar
Una vez configuradas las llaves:
1. Limpia la compilación anterior para asegurar la recarga nativa:
   ```bash
   flutter clean
   ```
2. Descarga de nuevo las dependencias:
   ```bash
   flutter pub get
   ```
3. Arranca el emulador o dispositivo y corre el proyecto:
   ```bash
   flutter run
   ```
