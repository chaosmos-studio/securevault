# SecureVault

A privacy vault app disguised as utility apps. Store photos, videos, and notes with AES-256 encryption. Multiple password-protected vaults where each password unlocks different content.

## Features

- 4 disguises: Calculator, Notes, Clock, MoodSpace
- Multi-vault system with separate passwords
- AES-256 encryption
- Dynamic app icon and name (Android)
- Photo, video, and notes storage
- Auto-lock and screenshot prevention

## Disguise Utilities

### Calculator
A fully functional calculator with basic arithmetic operations (+, -, ×, ÷). Works exactly like a real calculator app.

**Secret Entry:** Type your numeric passcode and press `=` or `%` to unlock the vault.

### Notes
A simple notes app where you can create, edit, and delete text notes. Notes are stored locally and persist between sessions.

**Secret Entry:** Tap the "Notes" title in the app bar **5 times** rapidly. A password dialog will appear where you enter your passcode.

### Clock
Displays current time with an analog clock face. Shows hours, minutes, and seconds with smooth animations.

**Secret Entry:** Tap the clock digits (hours/minutes) to input your code. For passcode `1234`, set it as time `12:34`. Alternatively, use the alarm feature and set the alarm time as your code.

### MoodSpace
A mood tracking and emotional wellness app. Log your daily moods, view mood history with beautiful visualizations, and gain insights into your emotional patterns.

**Secret Entry:** Tap the **settings icon** (gear) in the top-right corner **7 times** rapidly. A password dialog will appear.

## Multi-Vault System

SecureVault supports multiple vaults with different passwords:

- **Master Vault:** Primary storage accessible with your main password
- **Decoy Vaults:** Create additional vaults with different passwords that show different content
- **Panic Password:** Optionally set a password that wipes all data when entered

Each vault has its own encrypted storage for photos, videos, and notes.

## Security

- **AES-256 Encryption:** Military-grade encryption for all stored files
- **PBKDF2 Key Derivation:** Passwords are never stored; keys are derived securely
- **Auto-Lock:** App locks automatically when backgrounded or after timeout
- **Screenshot Prevention:** Blocks screenshots and screen recording
- **No Cloud Sync:** All data stays on your device

## Build

```bash
flutter pub get
flutter run
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

## License

Proprietary. See LICENSE file.