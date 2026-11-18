# SecureVault

A private vault for photos, videos and notes that looks like an everyday app on the phone.
Android first, built with Flutter.

Published by [Chaosmos](https://chaosmos.studio).
Get it on [Google Play](https://play.google.com/store/apps/details?id=com.shravangoswami.securevault), and read more at [chaosmos.studio/securevault](https://chaosmos.studio/securevault/).

## How it works

- Setup picks a disguise (Calculator, Notes, Clock or MoodSpace) and a 6 to 12 digit PIN, then has you open the vault once on the disguise.
- The app swaps its launcher icon and name to the disguise's when you next leave it.
- Each disguise is a working app with its own way in:

| Disguise | Opens the vault |
| --- | --- |
| Calculator | Type the PIN, then `=` (or `%`) |
| Notes | Search for the PIN, or tap the title five times, or title a new note with it |
| Clock | Type the PIN on the Timer keypad and press Start, or set an alarm labelled with it |
| MoodSpace | Write the PIN as the note and press Save |
| Any | Menu > Request a feature, with any password, including older ones with letters |

- Every vault has its own PIN. A vault can make others, such as a harmless one to show if someone insists.
- Files are encrypted with AES-256 under a key made from the PIN and a per-phone salt. They stay on the phone unless you save, share or back them up, and they are left out of Android's backups. [docs/CRYPTO_1.2.md](docs/CRYPTO_1.2.md) plans the next step: Argon2id, a key per vault and authenticated encryption.
- Screenshots are blocked while a vault is open, and the vault locks when the app is left (or after the time set in Settings).
- Settings > Back up and restore saves one vault to a file that opens on any phone with that vault's PIN.

## Build and test

```bash
flutter pub get
flutter test
flutter build apk --debug      # installs as com.shravangoswami.securevault.dev, beside the Play build
flutter build appbundle --release
```

`test/compat/` opens a vault snapshot written by the 1.0.3 release, so an update can never strand existing vaults.
`test/capture/` renders every screen at phone size when `SV_CAPTURE_OUT` is set, and `store/tools/store_art.py` turns those captures into the Play graphics in `assets/store/`.

## Credits

SecureVault was created by Shravan Goswami ([shravanngoswamii](https://github.com/shravanngoswamii)), Jash Ambaliya ([AJ0070](https://github.com/AJ0070)) and Jitendra Verma ([jitendravjh](https://github.com/jitendravjh)).
Chaosmos, the studio Shravan Goswami runs, publishes and maintains it.

## License

SecureVault is free software under the GNU General Public License, version 3 or later (GPL-3.0-or-later). See [LICENSE](LICENSE).
The Red Hat Text font in `assets/fonts/` is under the SIL Open Font License, in `assets/fonts/RedHatText-OFL.txt`.
