# FreshSense - Mobile App

Aplicacion movil (Android) de FreshSense construida con Flutter. Es la version movil del [Frontend](https://github.com/1ASI0572-2620-8725/Frontend): misma arquitectura DDD, mismos modulos, mismas rutas y mismos textos (i18n ES/EN), con la interfaz adaptada a movil. Permite gestionar inventario de alimentos, ver alertas, recetas, reportes, notificaciones y el monitoreo en tiempo casi real de los sensores IoT (temperatura, humedad y **etileno / gas**).

---

## Descargar el APK

La ultima version esta en **[Releases](https://github.com/1ASI0572-2620-8725/Mobile-App/releases/latest)** → `freshsense.apk`.

En el telefono: abrir el archivo descargado y permitir "Instalar apps desconocidas" para el navegador o el gestor de archivos.

Usuario demo: `demo@freshsense.com` / `Demo1234!`.

---

## Requisitos

| Herramienta  | Version minima |
|--------------|----------------|
| Flutter      | 3.47+ (canal stable) |
| Android SDK  | API 35         |
| Java (JDK)   | 17             |

---

## Prerequisito: Backend corriendo

La app consume la misma API REST que el frontend web. Por defecto apunta al backend desplegado:

| Recurso | URL |
|---------|-----|
| Backend API | `https://137-131-253-18.sslip.io/api` |
| Swagger UI | `https://137-131-253-18.sslip.io/swagger-ui/index.html` |

Ver el README del [BackEnd](https://github.com/1ASI0572-2620-8725/BackEnd) para levantarlo en local.

---

## Instalacion y ejecucion

```bash
flutter pub get
flutter run                 # con un telefono conectado (depuracion USB) o un emulador
```

---

## Comandos disponibles

```bash
flutter run                    # Ejecutar en modo desarrollo (hot reload)
flutter build apk --release    # APK de produccion (build/app/outputs/flutter-apk/app-release.apk)
flutter test                   # Tests unitarios
flutter analyze                # Analisis estatico
```

---

## Configuracion de entorno

El archivo `lib/environments/environment.dart` contiene la URL base del API (equivalente a `src/environments/environment*.ts` del web):

```dart
static const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://137-131-253-18.sslip.io/api',
);
```

Para apuntar a otro backend sin tocar el codigo:

```bash
# Backend local desde el emulador de Android (10.0.2.2 = localhost de la PC)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

---

## Arquitectura

El proyecto sigue Domain-Driven Design (DDD) con la misma estructura de carpetas que el frontend web.

```
lib/
├── accounts/          # Autenticacion, registro, configuracion de usuario
├── alerts/            # Alertas por vencimiento o sensores
├── billing/           # Planes y suscripciones
├── core/i18n/         # Idioma (ES/EN) con los mismos JSON del web
├── environments/      # URL del backend
├── inventory/         # Gestion de productos en inventario (catalogo + voz)
├── monitoring/        # Monitoreo de sensores IoT y dispositivos
├── notifications/     # Bandeja de notificaciones in-app
├── recipes/           # Recetas recomendadas segun el inventario
├── reports/           # Historial de consumo y reportes
├── shared/            # HTTP, guards, toast, tema, layout, home
├── app.routes.dart    # Rutas (equivalente a app.routes.ts)
└── main.dart          # Arranque e inyeccion de dependencias (equivalente a app.config.ts)
```

Estructura interna de cada modulo:

```
{modulo}/
├── domain/             # Modelos de dominio (clases con fromJson/toJson)
├── application/        # Stores (ChangeNotifier), servicios de aplicacion
├── infrastructure/     # APIs HTTP hacia el backend, responses y assemblers
└── presentation/       # Vistas (widgets)
```

### Equivalencias con el frontend web

| Angular (web)                    | Flutter (movil)                              |
|----------------------------------|----------------------------------------------|
| Store con `signal()`             | Store con `ChangeNotifier` + `notifyListeners()` |
| `@Injectable({ providedIn: 'root' })` | Instancia unica registrada con `Provider` en `main.dart` |
| `inject(X)`                      | `context.read<X>()`                          |
| `HttpClient` + `withCredentials` | `Dio` + cookie jar persistente               |
| `auth.interceptor.ts`            | `shared/infrastructure/auth_interceptor.dart` |
| `authGuard` / `premiumGuard`     | `redirect` de `go_router`                    |
| `@ngx-translate` + `\| translate` | `LanguageService` + `context.tr('clave')`   |
| `ToastService`                   | `ToastService` (SnackBar)                    |
| Modales                          | Bottom sheets                                |

---

## Autenticacion

- El JWT viaja en las cookies HttpOnly `authToken` y `refreshToken` que setea el backend, igual que en el web. La app las guarda en un cookie jar persistente, asi la sesion sobrevive al cerrar la app; el token nunca se guarda en texto.
- Ante un `401`, `auth_interceptor.dart` renueva el access token con `/accounts/refresh` y repite la peticion; si no puede, cierra la sesion.
- El `authGuard` intenta `tryRestoreSession()` (`GET /accounts/me`) antes de mandar al login.
- Login con Google: no incluido en movil (el flujo OAuth2 del backend redirige al frontend web).

### Roles disponibles

| Rol            | Descripcion                                          |
|----------------|------------------------------------------------------|
| `USER_STANDARD`| Usuario registrado sin suscripcion activa            |
| `USER_PREMIUM` | Usuario con suscripcion; accede a recetas premium    |
| `ADMIN`        | Administrador del sistema                            |

---

## Rutas

| Ruta              | Vista                  | Acceso   |
|-------------------|------------------------|----------|
| `/login`          | LoginView              | Publico  |
| `/register`       | RegisterView           | Publico  |
| `/dashboard`      | HomeView               | Auth     |
| `/inventory`      | FoodInventoryView      | Auth     |
| `/inventory/add`  | InventoryAddView       | Auth     |
| `/monitoring`     | MonitoringView         | Auth     |
| `/devices`        | DevicesView            | Auth     |
| `/alerts`         | AlertsView             | Auth     |
| `/recipes`        | RecipesView            | Auth     |
| `/reports`        | ReportsView            | Auth     |
| `/notifications`  | NotificationsView      | Auth     |
| `/settings`       | SettingsView           | Auth     |
| `/plan`           | PlanView               | Auth     |
| `/payment`        | PaymentView            | Auth     |

---

## Monitoreo en tiempo casi real (gas)

Flujo: **Sensor (ESP32) → Edge → Backend → App**.

- La vista Monitoreo consulta `GET /api/monitoring/latest` **cada 5 segundos** y actualiza las tarjetas y sus graficas.
- Muestra temperatura, humedad y **etileno (ppm)**; el color del etileno usa el semaforo que calcula el Edge por categoria.
- El historial se puede exportar a CSV y compartir.

---

## Internacionalizacion (i18n)

Los archivos de traduccion estan en `assets/i18n/` y son los mismos del frontend web (`public/i18n/`), con algunas claves extra para movil (`devices.*`, `monitoring.ethylene`):

- `es.json` — Espanol
- `en.json` — Ingles

El idioma se cambia con el boton EN/ES de la barra superior o en Configuracion → Preferencias.

**Convencion:** no se permiten strings fijos en las vistas. Todos los textos visibles deben usar `context.tr('clave')` (en `build`) o `context.trNow('clave')` (en callbacks).

---

## Convenciones de desarrollo

- Misma estructura DDD y mismos nombres de clases que el web (`AccountStore`, `InventoryApi`, `AlertsView`, ...).
- Sufijo `View` en todas las clases de vista; sufijo `Api` en los clientes HTTP; sufijo `Store` en el estado.
- Archivos en `snake_case` (convencion de Dart), equivalentes a los `kebab-case` del web.
- Tokens de diseno (`--fs-*` del web) en `shared/presentation/theme/app_theme.dart`.
- `dart format -l 130` y `flutter analyze` sin advertencias.

---

## Estado de funcionalidades

| Feature                          | Estado    |
|----------------------------------|-----------|
| Login / Registro JWT             | Completo  |
| Login con Google (OAuth2)        | No aplica en movil |
| Inventario (catalogo + manual)   | Completo  |
| Voz para agregar productos       | Completo  |
| Alertas con filtros              | Completo  |
| Monitoreo con etileno (gas)      | Completo  |
| Refresco automatico cada 5 s     | Completo  |
| Dispositivos IoT (emparejamiento)| Completo  |
| Recetas recomendadas y con IA    | Completo  |
| Reportes e historial             | Completo  |
| Bandeja de notificaciones        | Completo  |
| Configuracion de usuario         | Completo  |
| Planes y pago simulado           | Completo  |
