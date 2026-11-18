# Encryption upgrade for 1.2

A plan for SecureVault 1.2: a slow key derivation, a key per vault, authenticated encryption, encrypted vault names, and a migration that cannot lose a file.
Nothing here ships in 1.1.0.

## Where 1.1 stands

- A PIN becomes the key through 10,000 rounds of SHA-256 over the PIN and a per-phone salt (`lib/core/services/encryption_service.dart`, `deriveKeyWithSalt`).
- A PIN is checked with one SHA-256 of the PIN and the salt (`hashPassword`), which is far cheaper to test than the key itself.
- Files, thumbnails and `metadata.enc` use AES-256-CBC with a random IV and no authentication, so changed or swapped bytes go unnoticed.
- The PIN's key encrypts every file directly, so changing a PIN re-encrypts every file (`VaultService.changePassword`).
- The vault index in secure storage holds vault names and the master and decoy tree, protected by the Android Keystore but not by any PIN.
- A `.svb` backup carries its salt, so anyone with the file can test PINs offline at GPU speed. By our estimate a 6-digit PIN falls in about a second on one GPU.

## Design

### Keys

1. `stretched = Argon2id(PIN, salt, memory, iterations)`, with a random 16-byte salt per vault.
2. On the phone only, `bound = HMAC(keystore_key, stretched)`, where `keystore_key` is a non-exportable Android Keystore HMAC key. A copy of the app's files is then useless off the phone, whatever the PIN.
3. From `bound`, HKDF-SHA256 gives two values: `lookup`, which finds the vault a PIN opens, and `wrap`, which unwraps the vault's data key.
4. Each vault gets a random 32-byte data key (DEK) at creation. It is stored only wrapped by `wrap`, with AES-256-GCM.
5. Changing a PIN rewraps the DEK and touches no files.

The `lookup` value replaces the SHA-256 verifier, so testing a PIN costs a full Argon2id run.

Argon2id parameters are chosen by benchmark on a low-end phone running Android 7, the oldest the app supports, aiming at about half a second per unlock.
They are stored in each vault's header, so they can rise later without breaking old vaults.

Candidates to benchmark: libsodium's `crypto_pwhash` through a Flutter binding, and a pure-Dart Argon2id.
Check each one's current version, licence (GPL-3.0 compatible) and F-Droid buildability before choosing.

### Files

- AES-256-GCM in chunks of 64 KiB, so large videos never sit whole in memory.
- Each file starts with a header: magic, format version, a random 7-byte nonce prefix and the chunk size.
- Each chunk's nonce is the prefix, a chunk counter and a last-chunk flag. The file's item id is the associated data, which stops chunks being reordered or truncated, and files being swapped between items.
- Thumbnails, notes and `metadata.enc` use the same format.

### Vault names and the vault tree

- A vault's name moves into its own encrypted metadata.
- The index in secure storage keeps only `lookup -> vault folder`, with no names.
- A vault's child vaults are listed inside the parent's encrypted metadata, so a decoy vault learns nothing about the others.

### Backups (.svb v3)

- A backup has its own Argon2id salt and parameters in its header. It holds the DEK wrapped by a key from the vault's PIN, then the files exactly as stored.
- The Keystore step is left out, because a backup must open on another phone. A backup's strength is therefore Argon2id and the PIN's length.
- The backup screen will say so plainly, and suggest a longer PIN for vaults that are backed up.
- 1.2 keeps reading `.svb` v2 files, and restoring one converts its items to the new format.

### What still shows

The number of vaults, the number of items and their rough sizes stay visible to anyone with the app's files.
Padding sizes and hiding counts is out of scope for 1.2.

## Migration

Each vault migrates on its first unlock in 1.2, with a progress bar, and at no other time, because only then is the PIN known.

1. **Prepare:** create the DEK and the new header, and write `migration.journal`, encrypted with the new keys. The old files stay the source of truth.
2. **Per item:**
   - Decrypt the old file.
   - Write the new file to `<id>.v2.tmp`, flush it to disk, and read it back to check it decrypts to the same bytes.
   - Rename it to `<id>.v2`, and record the item in the journal.
3. **Switch:** write the new `metadata.v2`, flush it, then rename it over the marker that says which format is live. This is the only step that changes which files the app reads.
4. **Clean up:** delete the old `.enc` files and the journal only after the switch.

Why this cannot lose data:

- Until step 3, the app still reads the old files.
- A crash anywhere before step 3 leaves the vault exactly as it was in 1.1, plus some `.v2` files that the journal lets the next unlock skip.
- After step 3, every new file has already been checked.

Free space is checked before each item. When it runs low, migration pauses with a clear message and resumes on a later unlock.
Decoy vaults migrate independently when they are opened.
Vaults that are never opened stay in the old format, and 1.2 keeps the old reader for them.

## Tests

- Migrate the 1.0.3 fixture (`test/fixtures/v1_0_3`) and a new 1.1 fixture, then compare every item's plaintext hash before and after.
- Inject a crash after every step of the migration and every write inside it. Assume the PIN is typed again, then check that the result equals a clean migration and no item is lost.
- A wrong PIN changes nothing on disk.
- Low free space pauses and later resumes.
- Tampering: flip a byte, truncate a file, swap two chunks or two files. Each must fail to open, never return wrong bytes.
- `.svb` v2 backups restore into a migrated vault, and v3 backups round-trip.
- A PIN change rewrites only the wrapped key.
- The KDF benchmark runs on a real low-end phone before the parameters are fixed.

## Rollout

- Ship 1.2 to the closed test first, with the migration on.
- Keep the old reader in the app for at least two releases after 1.2.
- Play cannot downgrade an app, so there is no path back to 1.1 after a vault migrates. The release notes will say that the vault is upgraded on first unlock.
