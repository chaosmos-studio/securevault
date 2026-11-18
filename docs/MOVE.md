# Moving SecureVault to the Chaosmos org

A checklist for the day SecureVault becomes `chaosmos-studio/securevault`: public, GPL-3.0-or-later, with its website served at `https://chaosmos.studio/securevault/`.
Nothing here happens before Jash Ambaliya and Jitendra Verma agree to the licence.

## 1. Before the day

- [ ] Jash Ambaliya and Jitendra Verma agree in writing (an email kept on file is enough) that their contributions are released under GPL-3.0-or-later.
- [ ] Each of them says whether their commit email may appear in the public history, or which address to use instead.
- [ ] Decide the history (section 2). The recommendation is a cleaned history.
- [ ] Prepare the licence change on a branch:
  - `LICENSE` holds the GPL-3.0 text, and README's licence section says GPL-3.0-or-later.
  - Settings gains a Licences row that opens Flutter's `showLicensePage`.
  - The Red Hat Text OFL licence is registered with `LicenseRegistry`, so it shows there too.
  - The website's terms (`Using the app`), privacy and footer drop "all rights reserved" for the GPL wording.
  - Optional: SPDX headers in `lib/`, `android/` and `store/tools/`.
- [ ] Delete the iOS icons of unknown origin that are still in the tree (`ios/Runner/*Icon*.png` other than `AppIcon.appiconset`), or replace them with ones drawn by `store/tools/icons.py`.

## 2. The history

Three choices:

1. **Full history.** It is honest and keeps everyone's commits, but it publishes things we have no right to publish:
   - the One Piece and anime images (`website/src/assets/luffy.png`, `zoro.png`, `jitendra.webp`)
   - the 1.0.x shield, weather and disguise icons, whose source is unknown
   - `node_modules` with a 19 MB Windows DLL, and Flutter's `linux/` and `windows/` ephemeral folders
   - old personal addresses in website pages and commit metadata
2. **One fresh commit.** It is clean and small, but it drops the co-creators' commits, which are their credit.
3. **Filtered history (recommended).** Keep every commit and its message, and remove only what must not be published. It keeps everyone's credit and leaves no image or file we lack the rights to.

How to filter, with `git filter-repo` on a fresh mirror clone, never on this working copy:

- [ ] Remove these paths from every commit: `node_modules/`, `linux/flutter/ephemeral/`, `windows/flutter/ephemeral/`, `android/build/`, `website/src/assets/luffy.png`, `website/src/assets/zoro.png`, `website/src/assets/jitendra.webp`, `**/ic_weather.png`, `assets/icons/weather_icon.png`, `**/ic_shield*.png`, `android/app/src/main/res/mipmap-anydpi-v26/ic_shield.xml`.
- [ ] For files that still exist under the same path (`assets/icons/*_icon.png`, `mipmap-*/ic_calculator*.png` and the others), strip every older version by blob id with `--strip-blobs-with-ids`, keeping only the blobs at the current HEAD.
- [ ] Use `--replace-text` to turn old addresses in file contents (the gmail and shravangoswami.com contacts) into `hello@chaosmos.studio`.
- [ ] Use `--mailmap` for commit authors, with the addresses each person chose in section 1.
- [ ] Check the result:
  - `git diff <old HEAD> <new HEAD> --stat` shows no differences in kept files;
  - `flutter test` passes;
  - a release build signs with the same upload key fingerprint;
  - a secrets scan (`gitleaks` or the audit's greps) over every commit finds nothing.

Commit messages such as "Fixed: The Secret Backdoor" stay as written. They describe old website copy and harm no one.

## 3. The repository

With a filtered history, the new repo is a new push, not a transfer:

- [ ] Create `chaosmos-studio/securevault` as public, then push the filtered `main` and the release tags.
- [ ] Rename the old `shravanngoswamii/SecureVault` to `SecureVault-archive`, keep it private, and archive it. Its one fork is private too: ask its owner to delete it.
- [ ] Re-add the Actions secrets for signing and Play (`ANDROID_KEYSTORE_*`, `PLAY_SERVICE_ACCOUNT_JSON`) to the new repo.
- [ ] Turn on branch protection for `main`.

With the full history, use GitHub's Transfer instead, which keeps issues and redirects the old repo URL.

## 4. The website at chaosmos.studio/securevault/

- [ ] In `website/astro.config.mjs`, set `site` to `https://chaosmos.studio` and `base` to `/securevault`.
- [ ] Check that the studio site (`studio/chaosmos-studio.github.io`) has no `/securevault/` page, because a project site and the org site cannot both serve that path.
- [ ] In the new repo, Settings, Pages: deploy from the `gh-pages` branch. Run `website-deploy.yml` once by hand.
- [ ] Check every page: `/`, `/about/`, `/blog/` and each post, `/credits/`, `/developers/`, `/privacy/`, `/support/`, `/terms/` and `/rss.xml`.
- [ ] Giscus: point the comment box at a discussions category in the new public repo, or at `chaosmos-studio/community`.

## 5. The old URLs

`https://shravangoswami.com/SecureVault/` is served by the old repo's GitHub Pages. Once that repo is private or its Pages are off, the path falls through to Shravan's personal site, `other/shravanngoswamii.github.io`.

- [ ] Only after the new site works, turn off Pages on the old repo.
- [ ] In the personal site, add `SecureVault/<page>/index.html` for every page in section 4. Each is a small page with `<meta http-equiv="refresh" content="0; url=https://chaosmos.studio/securevault/<page>/">`, a canonical link to the same address, and a plain link for browsers that block the refresh.
- [ ] Check that each old URL lands on its new page, with and without the trailing slash.

## 6. Google Play and the app

- [ ] App content, Privacy policy: `https://chaosmos.studio/securevault/privacy/`.
- [ ] Store settings, website: `https://chaosmos.studio/securevault/`. Update `CONTACT` in `store/tools/play_release.py` to match.
- [ ] Wherever Play shows the trader terms or a terms link for the app: `https://chaosmos.studio/securevault/terms/`.
- [ ] The app's Settings links (Privacy) move to the new URLs in the next release. The redirects keep 1.1.0's links working until then.
- [ ] README, `assets/store/listing.md` and the workspace docs point at the new repo and site.
- [ ] Add SecureVault to the studio site's list of apps, as the studio's own page and the developer page now show it.

## 7. F-Droid, later

The app has no Google Play Services, Firebase, ads or billing, so it can go on F-Droid. That needs a pinned Flutter version in the build recipe, and its own signing key. Moving from the Play build to the F-Droid build means a reinstall, which deletes vaults, so the F-Droid listing must say to make a backup first.
