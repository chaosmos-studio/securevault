# SecureVault's move to the Chaosmos org

SecureVault moved to the Chaosmos org and became open source on 18 November 2026.
This records what changed and what is left.

## Where things are

- **Code:** https://github.com/chaosmos-studio/securevault, public, GPL-3.0-or-later.
- **Website:** https://chaosmos.studio/apps/securevault/, built from `website/` by `.github/workflows/website-deploy.yml` and served by the Cloudflare Worker `securevault-site`. The workflow needs the repository secret `CLOUDFLARE_API_TOKEN`.
- **The old repo:** `shravanngoswamii/SecureVault`, private and archived, with the history from before the move.
  - Its `gh-pages` holds one `index.html` and one `404.html`.
  - Both send `shravangoswami.com/SecureVault/<path>` to the same path under `https://chaosmos.studio/securevault/`, with the query and the hash, and the studio site sends that on to `/apps/securevault/` with the path and query.
  - Every old path except the home page now answers HTTP 404 before the script redirects, because the `404.html` catches it.
- **Releases:** `.github/workflows/release-android.yml` builds the signed AAB and APK, checks them, makes the GitHub release and uploads to Google Play. `store/tools/play_release.py` updates the listing and rolls out the production draft.
- **The creators' agreement:** issue #1. `.github/workflows/creators-agreement.yml` records each signature in `.github/agreements/`.

## The history cleanup

`git filter-repo` ran on a fresh mirror of the old repo's `main` and tags.

- **Kept:** all 174 commits, with their authors.
- **Removed from every commit:**
  - `node_modules/`, `android/build/`, and the Flutter ephemeral folders for Linux, Windows and macOS
  - the One Piece and anime avatar images, and the old SVGRepo favicon
  - the iOS disguise icons of unknown origin, the weather icons, the old shield icons, and 66 older versions of the disguise and vault icons
- **Replaced:** Shravan's old addresses, and two placeholder addresses at a domain we do not own, became `hello@chaosmos.studio` in every file and commit message.
- **Left out:** the `gh-pages` branch and the pull request refs.
- **Checked:**
  - none of those paths or blobs is in any commit
  - the pack went from 29.6 MiB to 17.6 MiB
  - `tools/secret-scan.sh --history` is clean

The iOS disguise icons were drawn again by `store/tools/icons.py` after the cleanup.

## Left to do

- [x] Shravan Goswami, Jash Ambaliya and Jitendra Verma each comment **I agree** on issue #1.
- [ ] Play Console, App content, Privacy policy: `https://chaosmos.studio/apps/securevault/privacy/`. The old address answers 404 before it redirects.
- [ ] Play Console, Store settings, Website: `https://chaosmos.studio/apps/securevault/` (`store/tools/play_release.py listing` sends it).
- [ ] Add SecureVault to the studio site's list of apps (the website's draft for `/apps/`).
- [ ] Later, F-Droid. The app has no Google Play Services, Firebase, ads or billing. It needs a pinned Flutter version in the build recipe and its own signing key. Moving from the Play build to the F-Droid build means a reinstall, which deletes vaults, so the listing must say to make a backup first.
