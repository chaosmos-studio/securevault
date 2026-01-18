# SecureVault

A privacy vault app disguised as utility apps. Store photos, videos, and notes with AES-256 encryption. Multiple password-protected vaults where each password unlocks different content.

## Features

- 4 disguises: Calculator, Notes, Clock, Weather
- Multi-vault system with separate passwords
- AES-256 encryption
- Dynamic app icon and name (Android)
- Photo, video, and notes storage
- Auto-lock and screenshot prevention

## Secret Entry

- Calculator: Type code, press = or %
- Notes: Tap title 5 times, enter code
- Clock: Tap digits or set alarm as code (1234 = 12:34)
- Weather: Tap settings 7 times, enter code

## Build

```
flutter pub get
flutter run
flutter build apk --release
```

## License

Proprietary. See LICENSE file.