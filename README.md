# Find Doctor App

A Flutter healthcare application that helps patients find doctors, explore medical specialties, manage appointments, communicate with doctors, and access healthcare services.

## Features

* Patient and doctor accounts
* Doctor search and discovery
* Doctor profiles and specialties
* Appointment booking and management
* Doctor availability and schedules
* Consultation requests
* Patient-doctor chat
* Payments
* Prescriptions
* Notifications
* Community features
* Patient profile management
* Doctor dashboard
* Manager dashboard
* Hospital dashboard
* Doctor management
* Hospital operations
* Equipment management
* Meetings and collaboration
* Application and alert management
* Multi-language support

## Project Name

```text
find_doctor_app
```

## Technology

* Flutter
* Dart
* Flutter BLoC
* HTTP REST API
* Shared Preferences
* Material Design

## Project Structure

```text
find_doctor_app/
├── android/
├── ios/
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/
│
├── lib/
│   ├── core/
│   ├── data/
│   ├── models/
│   ├── services/
│   ├── blocs/
│   ├── presentation/
│   │   ├── screens/
│   │   │   ├── patient/
│   │   │   ├── doctor/
│   │   │   ├── manager/
│   │   │   ├── hospital/
│   │   │   └── common/
│   │   │
│   │   └── widgets/
│   │
│   └── main.dart/
│
├── test/
│   ├── blocs/
│   ├── widgets/
│   └── ...
│
├── analysis_options.yaml
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

## Getting Started

### 1. Install Flutter

Make sure Flutter is installed and configured correctly.

Check your installation with:

```bash
flutter doctor
```

### Supabase backend

Sign-in, accounts, appointments, chat, hiring, inventory, posts and photos are stored in Supabase.
The project URL and public key are in `lib/supabase_config.dart`; no extra key or `--dart-define` is needed.

1. In the Supabase dashboard, open **SQL Editor** and run `supabase/schema.sql` (safe to re-run).
2. Under **Authentication > Sign In / Providers > Email**, keep Email enabled and turn **Confirm email** off.
3. Sign up in the app, then make the first General Manager by hand (see the end of `schema.sql`).

Roles are protected by the database rules in `schema.sql`; users cannot give themselves Doctor or Manager access.

### 2. Get Dependencies

From the project root:

```bash
flutter pub get
```

### 3. Run the Application

```bash
flutter run
```

### 4. Run Tests

```bash
flutter test
```

## Windows Desktop Application

The Windows target builds a native desktop application named **Find Doctor**. The signed-in workspace adapts to a PC window with a persistent five-section navigation rail; on narrow displays it keeps the five-item bottom navigation.

To install a packaged Windows build, extract the complete `FindDoctor-Windows.zip` and run `Install-FindDoctor.cmd`. It installs for the current Windows account, creates Start menu and desktop shortcuts, and registers an uninstall entry in Windows Settings. Administrator access is not required.

To build the Windows bundle from source, install Flutter's Windows prerequisites, including Visual Studio with the Desktop development with C++ workload, then run:

```powershell
flutter build windows --release
```

The native bundle is written to `build\windows\x64\runner\Release`. Run `packaging\windows\Build-WindowsPackage.ps1` to assemble the complete bundle and create `build\FindDoctor-Windows.zip`.

All records are stored in Supabase (see *Supabase backend* above). A payment provider is still required for real transactions.

## Development

The application follows a layered structure:

```text
UI
 ↓
BLoC
 ↓
Services
 ↓
API
```

Screens and widgets are responsible for presentation, BLoCs manage application state, and services communicate with the backend API.

## State Management

The application uses BLoC/Cubit architecture for state management.

Example areas include:

```text
Auth
Appointments
Doctors
Payments
Notifications
Chat
Community
Manager
```

## Localization

The application supports multiple languages through the localization service.

Currently planned languages include:

```text
English
Arabic
Bahasa Melayu
```

## Testing

Tests are organized by feature:

```text
test/
├── blocs/
│   ├── auth_bloc_test.dart
│   ├── appointment_bloc_test.dart
│   └── doctor_bloc_test.dart
│
├── widgets/
│   └── appointment_card_test.dart
│
└── ...
```

Run all tests with:

```bash
flutter test
```

## Code Quality

Run static analysis with:

```bash
flutter analyze
```

Format the Dart code with:

```bash
dart format lib test
```

## Important

Do not commit private credentials, API keys, passwords, access tokens, or other sensitive configuration to the repository.

## License

This project is currently for development and educational purposes.
