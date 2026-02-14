# eavesdrop

Live Conversations Worth Listening To

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## Runtime configuration

The app now reads Agora credentials from environment configuration:

- Flutter client app id: pass `--dart-define=AGORA_APP_ID=<your_app_id>` when running/building.
- Firebase Functions token generator: set `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` in the function runtime environment before deploying.

This avoids hardcoding secrets in source control.
