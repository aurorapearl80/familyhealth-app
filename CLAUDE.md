# familyhealth-app

Flutter mobile app ("Family Watch Today", package `familyhealth`, Android applicationId
`com.familywatchtoday.familyhealth`). Family-member-facing client in the **FamilyWatchToday**
ecosystem — see root [`../CLAUDE.md`](../CLAUDE.md). Tagline: "Your health, decoded with precision."

## Purpose

Login, pair/scan BLE vitals devices, view/track vitals (BP, blood glucose, blood oxygen, body
temp, heart rate, body composition), an activity/health-score dashboard, family location sharing
on a map, in-app chat/messaging, and video calling.

## Stack

Dart SDK `>=3.0.0 <4.0.0`, Flutter stable/Material. State: `provider ^6.1.2`. Networking: plain
`http ^1.2.0` for REST + `socket_io_client ^2.0.3+1` for real-time chat. Other key deps:
`flutter_blue_plus` (BLE), `google_maps_flutter` (family map), `livekit_client` (video calls),
`geolocator` + `workmanager` (background GPS), `onesignal_flutter` (push), `sqflite` +
`shared_preferences` (local persistence), `connectivity_plus`, `permission_handler`.
No Firebase dependency, no `firebase_options.dart`, no `.env` file.

## Layout

- `lib/main.dart` — entry point
- `lib/screens/` — `auth/`, `home/`, `vitals/` (per-metric screens), `achieve/` (activity/health
  score), `devices/` (BLE pairing), `share/` (chat, family map, messages, video call), `profile/`
- `lib/services/` — per-vitals-metric API clients, BLE scan/parse services, chat/socket/auth/
  location/patient services
- `lib/models/`, `lib/theme/`, `lib/widgets/`
- Multi-platform: `android/`, `ios/`, `macos/`, `linux/`, `web/`, `windows/`

## Build / run

```
flutter pub get
flutter run              # or: flutter build apk / flutter build ios
flutter test              # only the default boilerplate widget_test.dart — no real coverage
```
From the workspace root: `make flutter-setup` runs `flutter pub get` here.

## Backend

All REST + the Socket.IO chat connection point to **`https://familywatchtoday.com`** — this is the
same host as `patient-monitoring-web`/`socketio`. Key REST paths: `/api/login`, `/api/profile`,
`/api/auth-monitoring/*` (blood-pressure, glucose, oximeter-readings, temperatures, weights,
patient), `/api/patient/livekit/token`, `/api/admin/patients/{id}/livekit/token`,
`/api/ble-devices/summary`, chat under `/api`. `socket_service.dart` opens a Socket.IO connection to
the same host for real-time chat delivery.
