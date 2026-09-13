# CampusSetu — Build Commands

## User App APK
```
flutter build apk --release --flavor user --target lib/main_user.dart
```
Output: `build/app/outputs/flutter-apk/app-user-release.apk`

## Admin App APK
```
flutter build apk --release --flavor admin --target lib/main_admin.dart
```
Output: `build/app/outputs/flutter-apk/app-admin-release.apk`

## Run in dev
```
# User app
flutter run --flavor user --target lib/main_user.dart

# Admin app
flutter run --flavor admin --target lib/main_admin.dart
```
