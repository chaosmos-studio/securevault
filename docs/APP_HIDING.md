# Hiding other apps

A user emailed asking SecureVault to "hide apps": to make other apps' icons disappear from the phone.
This is what Android and Google Play allow, what other hide-app apps really do, what each option would cost us in Flutter, and what we recommend.
Checked on 18 November 2026.

## The short answer

No ordinary Google Play app can hide another app's icon on Android 15 or 16.
Only four things take an icon out of sight, and each one is either expensive or risky on Play:

- being the phone's home screen (a launcher),
- owning a work profile,
- cloning the app into a container and asking the user to uninstall the original,
- the phone's own feature: Private space, Samsung's Secure Folder, or the maker's "Hide apps".

An app lock hides nothing either.
It only puts a PIN in front of an app that is still on the home screen.

## What the platform allows

### One app cannot touch another app's icon

- An app may turn its own launcher entries on and off, which is how SecureVault becomes Calculator.
  Android lets a caller change a component's state without any permission only when the component runs under the caller's own user id [1].
- Changing another app's components needs `CHANGE_COMPONENT_ENABLED_STATE`, which Android marks "Not for use by third-party applications" [2].
- Truly hiding an app (`DevicePolicyManager.setApplicationHidden`) is only open to a device owner, a profile owner, or an app they delegate to [3].
- Shell tricks do not get there either: over adb or Shizuku an app can be disabled but not hidden, as the open-source Hail app documents [26].
- Since Android 11 an app cannot even see which other apps are installed unless it declares them or holds `QUERY_ALL_PACKAGES`, which Play restricts [6][52].

### A replacement launcher

- A launcher declares itself as a home screen, and the user picks it through the system's home app role [7].
  Its app drawer then simply leaves chosen apps out.
- Hyde App Hider (10M+ installs) is a launcher of this kind, and so are App Icon Hider and Hide All [46].
- The user gives up their own home screen, its layout, widgets and gestures.
  Hyde's reviews mention apps coming back after a reboot and a home screen being reset [46].
- The hidden apps still show in Settings, in the Play Store and in any other launcher.
  Nova Launcher's own help calls its hide option "an organizational tool and not a way to globally hide apps" [48].
- Since Android 15, a third-party launcher must also handle Private space itself to show it at all [9].
- It would fight our own disguise: SecureVault would have to be both the Calculator and the home screen.

### A work profile (Shelter, Island, Insular)

- These apps create a work profile, become its owner, clone apps into it and then freeze or hide them [19][22][25].
  The user still has to uninstall the personal copy for the app to be gone from the main screen.
- A phone has room for one work profile, so this clashes with an employer's work profile and, per Island's FAQ, with "Dual Apps" features [16][20].
  Samsung blocks the profile when a custom recovery is installed, and Xiaomi needs extra settings [20][21].
- The profile itself is not hidden: its apps sit in a "Work" tab with a briefcase badge.
- Island is still on Play, but its Play build cannot clone apps installed from outside Play [19][20].
  Shelter left Play in March 2023 and is now on F-Droid only, in maintenance mode [24][25].
- Google has closed new registrations of custom device policy controllers for the Google Play EMM API [13][14].
  Play Protect now blocks device policy controllers that Android Enterprise has not approved during enrolment [15][17].
  We could not find whether that block also covers a consumer app making a work profile from inside itself, so this is a risk we cannot measure.

### Android's Private space

- Android 15 added Private space: "a separate space on their device where they can keep sensitive apps away from prying eyes, under an additional layer of authentication" [8].
- Its apps show in a separate container in the launcher, and are hidden from recents, notifications, settings and other apps while it is locked [8].
  When locked, its apps stop running [8].
- Existing apps cannot be moved in. The user installs fresh copies inside it [8].
- The space can itself be hidden when locked [11].
- Ordinary apps cannot create it, open it or put apps in it. Only the default launcher, with a special permission, can see and lock it [4][9].
  The most SecureVault could do is open the phone's security settings and explain the steps.
- Shravan's own Nothing Phone (2a) has it since Nothing OS 3.0: swipe right in the app drawer, and hide it under Settings > Security and privacy > Private Space > Hide Private Space [31][32][34].
- Pixels and phones close to stock Android 15 and later have it.
  Samsung's One UI 8 moved Secure Folder onto the same private profile [28].

### Samsung Secure Folder and other makers

- Samsung's Secure Folder keeps copies of apps in a separate locked space, and can be hidden from the Apps screen [27].
  Its Knox SDK is licensed only to approved enterprise customers, so no consumer app can drive it [29][30].
- Xiaomi (Second space, Hidden apps), OnePlus (Hidden Space) and Oppo or realme (Hide apps) have their own versions [36][37][38].
  The menu paths change between versions, and we found only secondary sources for them.
- None of them has an interface another app can call.

### Cloning into a container

- Apps like Parallel Space and Dual Space run other apps' code inside their own process and redirect what those apps ask of the system [42].
  The hider then shows a cloned copy behind its own lock, and the user uninstalls the original.
- They need very long permission lists to make guest apps work. Exodus counts 174 to 209 permissions in the manifests of the big ones [47].
- Research has found most of these frameworks open to attack, and banking malware has used them to get around Android's sandbox [43][44][45].
- Play allows container apps only if they refuse to load any app that declares `REQUIRE_SECURE_ENV`, never proxy other apps, and check every manifest [39][40].
  Google says no technical feature enforces this, so it rests on policy alone [40].
- SecureVault 1.1 now declares `REQUIRE_SECURE_ENV`, so these containers must not load the vault [41].

## What Google Play's policies say

- **Accessibility.** Apps that use the accessibility service for anything but helping people with disabilities need a prominent in-app disclosure, consent and a Play Console declaration.
  It must never be used to get around Android's own security or to stop apps being uninstalled [50][51].
- **Seeing all apps.** `QUERY_ALL_PACKAGES` is allowed only when the app's core purpose needs it, with a declaration form [52].
- **Usage access and drawing over other apps.** These are granted by the user in Settings, and the user-data disclosure rules apply [51].
- **Device admin.** Device admin must not be used to block uninstalling [55].
- **Disguises.** We found no Play page about calculator disguises.
  The rules that apply are that metadata must accurately say what the app does, that apps must not mimic other apps or the system, and that icons and titles must not be so close to existing products that people are misled [53][54].
  Many disguised vaults are on Play, which shows tolerance rather than permission.
  Our safe practice: icons of our own, disguises that really work, and a listing that says plainly it is a vault.

## What the hide-app apps on Play actually do

Methods come from their listings and permissions from Exodus scans of their manifests [46][47].
We did not install any of them.

| App | What it really does | Notable |
| --- | --- | --- |
| Calculator Vault - App Hider (10M+) | Clones apps into a container behind a calculator | Asks for usage access, drawing over apps and all-files access. Reviews mention crashes after updates and lost files |
| App Hider: Hide Apps | Clones apps | Its own listing says "since Android 6.0, no one can hide the icon, you can only hide the application by cloning" |
| Hide Apps icon | Clones apps | "We will not hide the application directly from the system, but hide its copy" |
| Hyde App Hider (10M+) | A replacement launcher | Launcher permissions only |
| Hide All | A second home screen behind a calculator | Reviews say background apps stop and recents go blank |
| AppLock (100M+) | Locks apps, hides nothing | Uses an accessibility service and device admin |

None of them hides another app's icon the way the user imagines.
They either replace the home screen or hide a copy.

## Effort in Flutter

| Option | Effort | What it needs |
| --- | --- | --- |
| A guide to the phone's own feature, inside SecureVault | 2 to 4 days | Read the maker and Android version, show the right steps, open the right Settings screen. No Kotlin. Most of the time goes into checking real phones |
| Launcher mode | 2 to 3 weeks for a rough one, 6 to 10 or more for a good one | A home activity, app icons, package changes, widgets, Private space and work profile handling, nearly all in Kotlin |
| Work profile owner | 4 to 8 weeks | A device admin receiver, provisioning, cross-profile calls, all in Kotlin, testing on many makers' phones, and an unknown Play Protect risk |
| Cloning container | Months | A licensed or forked engine from 2017, and a security product built on known weak ground |
| App lock (ruled out) | 1 to 3 weeks | Usage access, an overlay, Play declarations |

## Recommendation

**Build an honest "Hide other apps" guide, and nothing more.**

- One screen in the vault's settings that says plainly that Android does not let one app hide another, then walks the user through their own phone's feature: Private space on Pixel, Nothing and other phones close to stock Android, Secure Folder on Samsung, and the maker's Hide apps elsewhere.
- It is 2 to 4 days of work, carries no Play risk, and sends the user to something stronger than any Play app can build: a locked space that also stops the apps and their notifications.
- It also answers the user who asked, truthfully.

**Do not build** a launcher, a work profile owner or a cloning container.
Each is weeks or months of mostly Kotlin work for a two-person studio, each is fragile across phone makers, and cloning would weaken a security product.

**On app locks.**
An app lock is not the only honest option, because it is not hiding at all.
The only real hiding open to a Play app is a launcher, a work profile or a container, and all three fit SecureVault badly.
Android is also getting a built-in App Lock, reported in beta on Pixels in August 2026, with its interface open only to the default launcher [1][57].
Shravan's "no app lock" call looks right.

## Sources

1. Android Developers, "PackageManager" reference, https://developer.android.com/reference/android/content/pm/PackageManager
2. Android Developers, "Manifest.permission" reference, https://developer.android.com/reference/android/Manifest.permission
3. Android Developers, "DevicePolicyManager" reference, https://developer.android.com/reference/android/app/admin/DevicePolicyManager
4. Android Developers, "LauncherApps" reference, https://developer.android.com/reference/android/content/pm/LauncherApps
5. Android Developers, "UserManager" reference, https://developer.android.com/reference/android/os/UserManager
6. Android Developers, "Declare package visibility needs", https://developer.android.com/training/package-visibility/declaring
7. Android Developers, "RoleManager" reference, https://developer.android.com/reference/android/app/role/RoleManager
8. Android Developers, "Android 15 features and APIs: Private space", https://developer.android.com/about/versions/15/features#private-space
9. Android Developers, "Behavior changes: all apps (Android 15), Private space", https://developer.android.com/about/versions/15/behavior-changes-all
10. Android Open Source Project, "Private space", https://source.android.com/docs/security/features/private-space
11. Google, Android Help, "Hide sensitive apps with private space", https://support.google.com/android/answer/15341885
12. Android Developers, "Settings" reference, https://developer.android.com/reference/android/provider/Settings
13. Android Developers, "Build a device policy controller", https://developer.android.com/work/dpc/build-dpc
14. Google for Developers, "Register for the EMM Community", https://developers.google.com/android/work/play/emm-api/register
15. Google, Android Enterprise Help, "Approved Android Enterprise DPC allowlist", https://support.google.com/work/android/answer/16694822
16. Google, Android Enterprise Help, "General FAQs", https://support.google.com/work/android/answer/14772109
17. Jason Bayton, "The DPC allowlist" (24 December 2025), https://bayton.org/blog/2025/12/the-dpc-allowlist/
18. Jason Bayton, "Play Protect blocked my DPC, why?", https://bayton.org/android/android-enterprise-faq/play-protect-blocked-my-dpc-why/
19. Oasis Feng, "Island" on Google Play, https://play.google.com/store/apps/details?id=com.oasisfeng.island
20. Oasis Feng, "Island FAQ", https://island.oasisfeng.com/faq
21. Oasis Feng, "Island Setup Guide", https://island.oasisfeng.com/setup.html
22. Oasis Feng, "island" repository, https://github.com/oasisfeng/island
23. F-Droid, "Insular", https://f-droid.org/en/packages/com.oasisfeng.island.fdroid/
24. PeterCxy, "Shelter" README, https://gitea.angry.im/PeterCxy/Shelter, and the commit that removed the Play link (4 March 2023), https://github.com/PeterCxy/Shelter/commit/be9b762724
25. F-Droid, "Shelter", https://f-droid.org/en/packages/net.typeblog.shelter/
26. aistra0528, "Hail" README, https://github.com/aistra0528/Hail
27. Samsung US, "Use the Secure Folder on your Galaxy phone or tablet", https://www.samsung.com/us/support/answer/ANS10001401
28. SamMobile, "One UI 8 fixes Secure Folder's major security flaw" (21 July 2025), https://www.sammobile.com/news/one-ui-8-fixes-samsung-secure-folder-major-security-flaw/
29. Samsung Knox, "About licenses", https://docs.samsungknox.com/dev/knox-sdk/introduction/about-licenses/
30. Samsung Knox, "KBA-1227: License keys page unavailable", https://docs.samsungknox.com/dev/knox-sdk/kbas/kba-1227-license-keys-page-unavailable-from-the-knox-developer-portal
31. Nothing Support, "What is Private Space?", https://support.nothing.tech/hc/en-us/articles/36481130645777-What-is-Private-Space
32. Nothing Support, "How do I hide Private Space?", https://support.nothing.tech/hc/en-us/articles/33944568514577-How-do-I-hide-Private-Space
33. Nothing Support, "How do I hide app icons on Phone (2a)?", https://support.nothing.tech/hc/en-us/articles/24510382360721-How-do-I-hide-app-icons-on-Phone-2a
34. Nothing Community, "Phone (2a) Nothing OS V3.0-250429-1922 changelog" (13 May 2025), https://nothing.community/d/32934-nothing-phone-2a-nothing-os-v30-250429-1922-changelog
35. Wikipedia, "Nothing Phone 2a", https://en.wikipedia.org/wiki/Nothing_Phone_2a
36. Android Central, "How to use Hidden Space in OxygenOS", https://androidcentral.com/how-use-hidden-space-oxygenos
37. realme Support, "Hide apps" (the page would not render, so its content is unverified), https://realme.com/in/support/kw/doc/2058698
38. miuirom.org, "How to use Second Space on Xiaomi" (secondary, unverified), https://miuirom.org/updates/xiaomi-second-space
39. Google Play Console Help, "Device and Network Abuse", https://support.google.com/googleplay/android-developer/answer/9888379
40. Google Play Console Help, "On-device Android container apps and the REQUIRE_SECURE_ENV flag", https://support.google.com/googleplay/android-developer/answer/13609005
41. Android Developers, "Limit loading in on-device Android containers", https://developer.android.com/training/basics/intents/limit-play-loading
42. asLody, "VirtualApp" README, https://github.com/asLody/VirtualApp
43. Lei Zhang, Zhemin Yang and others (Fudan University), "App in the Middle: Demystify Application Virtualization in Android and its Security Threats", SIGMETRICS 2019, https://secsys.fudan.edu.cn/publications/content/2021-08-18-008
44. "Parallel Space Traveling: A Security Analysis of App-Level Virtualization in Android", SACMAT 2020, hosted at UC Riverside, https://www.cs.ucr.edu/~heng/pubs/sacmat2020.pdf
45. The Hacker News, "New FjordPhantom Android malware" (December 2023), https://thehackernews.com/2023/12/new-fjordphantom-android-malware.html
46. Google Play listings, fetched 18 November 2026:
    Calculator Vault - App Hider, https://play.google.com/store/apps/details?id=com.app.calculator.vault.hider
    App Hider: Hide Apps, https://play.google.com/store/apps/details?id=com.hidespps.apphider
    Hide Apps icon, https://play.google.com/store/apps/details?id=com.privacyspace.hideapps.socialspace
    Hyde App Hider, https://play.google.com/store/apps/details?id=hyde.android.launcher3
    Hide All, https://play.google.com/store/apps/details?id=com.hello.mihe.app.launcher
    App Icon Hider, https://play.google.com/store/apps/details?id=com.appiconhider
    AppLock, https://play.google.com/store/apps/details?id=com.domobile.applockwatcher
    Parallel Space, https://play.google.com/store/apps/details?id=com.lbe.parallel.intl
    Dual Space, https://play.google.com/store/apps/details?id=com.ludashi.dualspace
47. Exodus Privacy, app reports, https://reports.exodus-privacy.eu.org/en/reports/
48. TeslaCoil Apps, "Nova Launcher FAQ" (archive), https://nova-archive.teslacoilapps.com/faq
49. Android Headlines, "Nova Launcher gets a new owner and ads too" (21 January 2026), https://www.androidheadlines.com/2026/01/nova-launcher-gets-a-new-owner-and-ads-too.html
50. Google Play Console Help, "Use of the AccessibilityService API", https://support.google.com/googleplay/android-developer/answer/10964491
51. Google Play Console Help, "Permissions and APIs that Access Sensitive Information", https://support.google.com/googleplay/android-developer/answer/9888170
52. Google Play Console Help, "Use of the broad package (App) visibility (QUERY_ALL_PACKAGES) permission", https://support.google.com/googleplay/android-developer/answer/10158779
53. Google Play Console Help, "Deceptive Behavior", https://support.google.com/googleplay/android-developer/answer/9888077
54. Google Play Console Help, "Impersonation", https://support.google.com/googleplay/android-developer/answer/9888374
55. Google Play Console Help, "Malware", https://support.google.com/googleplay/android-developer/answer/9888380
56. Malwarebytes, "Google cracks down on Android apps abusing accessibility" (17 March 2026), https://www.malwarebytes.com/blog/mobile/2026/03/google-cracks-down-on-android-apps-abusing-accessibility
57. Droid Life, "Google adds App Lock to Pixel phones in new update" (16 August 2026), https://droid-life.com/2026/08/16/google-adds-app-lock-to-pixel-phones-in-new-update
