# Changelog

All notable changes to SecureVault will be documented in this file.

## [1.1.0] - November 2026

Build 5 (Play version code 5).

### Changed
- A calm new look for the vault and all four disguises
- Setup now asks for a PIN and lets you open your vault once on the disguise, so you know how it works
- The disguises work like real apps: sums in the right order, a timer keypad, saved alarms, a mood journal
- Notes search, the timer and a mood note now open your vault too
- The new icon appears when you leave the app, with no restart
- The vault locks the moment you leave, or after the time you choose in settings
- Photos swipe from one to the next, and decrypted copies are cleared when the vault locks

### Fixed
- Backups now hold your photos, videos and notes, and restore on a new phone
- Saving and backups now work on older phones
- Notes in any language read back exactly as written
- Changing a PIN can no longer leave a vault half changed if the phone switches off
- The Clock no longer shows a minute digit twice, and its text shows in the light theme

## [1.0.3] - March 2026

### Changed
- Increased minimum vault password length from 4 to 6 characters for stronger protection
- About screen now always shows the correct app version

### Fixed
- About dialog was displaying version 1.0.0 regardless of the installed version

## [1.0.2] - February 2026

### Fixed
- App icon not changing on first install — disguise mode now applies correctly during initial setup
- App no longer stays open after setup; it force-closes so the launcher picks up the new icon
- Disguise icon change in vault settings now force-closes the app for reliable launcher refresh

### Changed
- Updated contact email to hello@chaosmos.studio

## [1.0.1] - February 2026

### Fixed
- Image zoom now works across the full screen area instead of a compact region
- Improved pan and zoom experience in photo viewer

## [1.0.0] - January 2026

### Added
- Initial release
- Multiple disguise modes (Calculator, Clock, Mood Logger, Notes)
- Secure vault for photos, videos, and notes
- Multiple vault support with password protection
- Admin vault with hierarchy management
- Backup and restore functionality
- Auto-lock security feature
- Export and share media securely
- About Us, Contact Us, and Request a Feature in all disguise modes
- First-time instructions showing all features
- Universal password entry via "Request a Feature" option

### Disguise Modes
- **Calculator**: Enter password as numbers and press =, use ⌫ for backspace, or use "Request a Feature" menu
- **Clock**: Tap time digits to enter password, add alarm with time and label (both try unlock), tap alarm to edit, or use "Request a Feature" menu
- **MoodSpace**: Tap mood emoji area or type password in mood input field, or use "Request a Feature" menu
- **Notes**: Type password in notes area, or use "Request a Feature" menu

### Security Features
- AES-256 encryption for all stored data
- Encrypted thumbnails and media
- No trace of vault in app appearance
- Multiple decoy vaults support
