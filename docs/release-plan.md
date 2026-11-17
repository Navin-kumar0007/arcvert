# Release plan

What goes into each version up to 1.0, agreed with the owner on 11 November 2026. How to make a release is in
[RELEASING.md](RELEASING.md).

## How releases go out

Releases are prepared ahead and published one after another, with time to test each:

1. Build the version on `core-engine`, raise the version, write its changelog section, and tag it. CI builds a
   **draft** release that only the owner can see.
2. Test the draft's downloads for about 10 days. A bug found then is fixed and the version tagged again, or it waits
   for a patch release.
3. Publish the draft. Then move `main` to that tag only, never the whole branch: every push to `main` redeploys the
   website and web app, and later versions may already be on the branch. `main` holds merge commits the branch
   doesn't, so make one more whose files are exactly the tag's, and push it:
   ```sh
   git fetch origin
   C=$(git commit-tree 'vX.Y.Z^{tree}' -p origin/main -p 'vX.Y.Z^{commit}' -m 'Release X.Y.Z')
   git push origin "${C}:refs/heads/main"
   ```
4. About two days later, update `docs/site/version.json`, so copies from the website offer the new version.

Publish in version order, as GitHub's "latest" release, which the site's Download buttons use, follows commit date.
A patch built after later versions were tagged, as 0.10.1 was, is newer by date than them: when publishing those, pass
`--latest` (`gh release edit vX.Y.Z --draft=false --latest`) so Latest moves on to them.

## 0.10.1: web worker fix

Patch on `main` (branch `release-0.10.1`), 16 November 2026: the browser's conversion worker was never told ring
choices, so in the web app Rotate 180° and 90° left, Flip upside down and Resize's sizes ran as the first choice.
Published at once, as the live web app had it. 0.13.0 carries the same fix (`ActionOptions.toWire`); the 0.11.0 and
0.12.0 drafts were tagged before it and don't. The owner chose (16 November 2026) not to publish 0.11 and 0.12 on
their own: 0.13.0, which holds all of them and the fix, is the next release after 0.10.1.

## 0.10.0: guide, update check, Tools in Shift-drag

**Published** on 15 November 2026 from `778461f`, and `main` moved to it. `version.json` to follow about 17 November.

- First-launch guide with a practice Shift-drag on a sample photo.
- Daily check for a newer version on Mac and Windows copies from the website; a link to the download page on Android.
- Option (Mac) or Alt (Windows) during a Shift-drag for Tools, with outer rings in the native menus.
- Language chosen in the app.

## 0.11.0: Settings, reorder before merging, previews

**Done**, tagged 11 November 2026. Not published on its own: it ships within 0.13.0.

### 1. Settings screen

One screen for every choice, opened from a gear icon beside About and History. About goes back to saying what the
app is, with its licences.

| Setting | Platforms | Default |
| --- | --- | --- |
| Where results go: beside the original, or a folder you choose | Mac, Windows | Beside the original |
| Theme: light, dark or as the system | All | As the system |
| Language: as the device, English or Hindi | All | As the device |
| Show previews | All | On |
| Open at login | Mac, Windows | Off |
| Check for new versions | Mac and Windows website copies | On |
| Get the newest version (a link, not a setting) | Android | — |
| Show the guide again (a button) | All | — |

Phones and browsers keep asking where to save, as now. A chosen folder that has gone, or can't be written to, falls back
to beside the original and says so once. Animations already follow the system's Reduce motion.

### 2. Reorder before merging

Merging PDFs, video or sound, and One PDF from pictures, first show the files in a list to drag into order, with a
small preview of each, then **Merge**. Up and down buttons do the same for keyboards and screen readers. In a
Shift-drag there is no screen to ask on, so the files are merged in the order they were dragged, and **Open menu
again** in the window offers the list. **Done** (`reorder_dialog.dart`).

### 3. Previews

A small panel shows the first page of the file: before converting, and after it, beside the result. **Show previews**
in Settings turns it off, and an eye button on the panel hides it for now.

| Kind | Before | After |
| --- | --- | --- |
| Pictures, including HEIC, TIFF, ICO | The picture | The result |
| PDF | Page 1 | Page 1 of the result |
| Video | A frame about a second in | A frame of the result |
| Sound | Its length, with an icon | The new length |
| Subtitles | The first three lines | The first three lines after the change |
| Archives | The first five names inside | The names in the new archive |
| PDF to Word | Page 1 of the PDF | The first lines of text |

With it:

- **Compare slider** for pictures and PDF pages: drag a line across one picture, before on the left and after on the
  right, to see what Compress or a size limit did.
- **Info line** under the preview, such as `4032×3024 → 1280×960 · 3.2 MB → 240 KB`, or pages and length for PDFs,
  video and sound.
- **Thumbnails on every result row**, in place of the plain file icon, so a batch can be checked at a glance.
- **Tap to enlarge**, full size, with pinch or scroll to zoom, to check sharpness.

Rules:

- Previews never slow or stop a conversion. They are made in the background, after the menu opens, and a failure shows
  "Can't preview" instead.
- Pictures are decoded straight to about 600 pixels wide, never at full size. Video frames are asked for once per file.
- Locked PDFs show a lock until their password is given. 7z and RAR show their names only once unpacked for a job.
- Several files: the panel shows the first, and every row gets its thumbnail.
- Previews live in memory only. They are never written to disk or kept in history.
- Every preview has a text description for screen readers.

**Done** (`preview.dart`, `preview_view.dart`), tried in Chrome.

### Done when

- Each feature works in Chrome, on the Mac, on an Android emulator in CI, and builds for Windows.
- Tests cover every file kind's preview, its failures, the compare slider, the reorder list and every setting.
- The user guide, privacy policy (previews stay on the device) and changelog say what changed.

## 0.12.0: new look, copy details

**Done**, tagged 15 November 2026. Not published on its own: it ships within 0.13.0. The
owner chose to ship the new look with Copy details and move the other planned items to 0.13.

- **New look** (agreed 15 November 2026 from the canvas of concepts), light and dark: colour sets in `theme.dart`,
  Inter and Space Grotesk bundled, the dial shown before any file as the drop target, Make it fit as its own amber
  tab, result cards with a size bar, theme cards in Settings, the phone's half dial within thumb reach
  (`thumb_arc.dart`), and the native Shift-drag menus and result chips on Mac and Windows in the same colours.
- **Copy details** on every failed file: app version, platform, action, file kind and the error's key, ready to paste
  into a bug report. Never file names or contents (`failure_details.dart`).

## 0.13.0: menu and form polish

**Not published**: in 0.16.0. Built and tagged on 16 November 2026 as ShiftDrop; the owner tried it on every platform.

- **Live preview in the menu's centre**: resting on Rotate, Flip or Resize, or one of their choices, shows the
  picture already turned, flipped or smaller, without converting. Window menu only. **Done** (`live_look.dart`,
  16 November 2026).
- **Thumbnails on the Shift-drag result chip**, from the system's own thumbnails (Quick Look on a Mac, the shell on
  Windows). **Done** (`QLThumbnailGenerator` in `ShiftDrag.swift`, `ShellThumbnail` in `shift_drag.cpp`).
- **Signature cleanup**: crop to the ink, whiten the paper, darken the ink, then the form's size and KB limits.
  **Done** (`cleanSignature` in `portable_engine.dart`, 16 November 2026).
- **Scanned document** preset: a greyscale PDF under a size limit. **Done** (`images-scan-pdf`, `cleanPage`, 16 November
  2026): Make it fit, pages in order first, under 1 MB, 500 KB or 200 KB, A4 pages.
- **Quality levels on Compress's outer ring**: high, medium and small, honoured by every engine. **Done**
  (`CompressLevel`, 16 November 2026): Balanced, Best quality, Smallest.

## 0.14.0: pages, details and habits

**Not published**: in 0.16.0. Built 16 November 2026 as ShiftDrop, after the owner tried 0.13.0 on every platform.

- **PDF page picker**: Extract pages with a grid of page pictures to tap, and the range typed, such as 1-3, 7.
  **Done** (`page_picker.dart`, `page_range.dart`, 16 November 2026), tried in Chrome.
- **Keep photo details (EXIF) while removing location**, as the plan asks; outputs drop all of it today. **Done**
  (`safePhotoDetails`, `keepsPhotoDetails`, 16 November 2026), JPEG results; HEIC loses them in decoding still.
- **Extract an archive to a folder** on a desktop, instead of one Save per file. **Done** (`keepFolders`,
  `saveFolderBesideOriginal`, 16 November 2026).
- **Learned slice order**: the most-used actions move to the easiest slots, learned on the device only. **Done**
  (`orderByUse`, `AppSettings.uses`, 16 November 2026).
- **Changing the trigger key** from Shift. **Done** (`AppSettings.triggerKey`, `TriggerKey` in Swift, `TriggerDown` in
  C++, 16 November 2026): Shift or Control.

## 0.17.0: your own slices

**Built**, 17 November 2026, not yet tried on devices.

- **Own Make it fit slices** (`core/lib/src/my_fits.dart`, `AppSettings.myFits`, `MyFitsList` in Settings): a form's
  sizes under a name, first in Make it fit and Shift-drag, run as Form photo (`runsAs`), result named after the slice
  (`ActionOptions.nameSuffix`). Made from Form photo's **Keep as a Make it fit slice** or in Settings.
  The owner tried it on devices on 17 November 2026: it works.
- **Export and import of settings** (`settings_backup.dart`, `MoveSettings` in Settings): a JSON file marked
  `arcvertSettings: 1` with the choices, slices and learned counts, never the results folder or anything else of this
  device's. Bringing one in shows what changes first; slices merge by id or name, counts keep the larger.
  The owner tried it on devices on 17 November 2026: it works.
- **Right-click to convert** on desktops: Finder's Open With (`CFBundleDocumentTypes`, rank Alternate) and a
  `NSServices` item; Explorer's verb for files and folders from the installer, a copy per item handing its path to the
  running one (`WM_COPYDATA`). Both reach Dart on `radial/open` and open as a drop. Not in the portable zip or the
  Microsoft Store build, which can't write those registry keys. Finder's Convert with Arcvert shows the dial at the
  cursor (owner's request); the owner tried it on a Mac on 17 November 2026: it works.
- Next candidates, in the owner's list from 17 November 2026: a pattern for result names, a notification when a long
  job ends.

## 0.16.0: Arcvert

**Done**, 17 November 2026. The next release after 0.10.1. The owner found another converter already called ShiftDrop
in the Microsoft Store, chose the name Arcvert, and chose (17 November 2026) not to publish the 0.13.0 to 0.15.0 drafts,
built under the old name: 0.16.0 holds all of them, as 0.13.0 held 0.11 and 0.12.

- **The new name** everywhere, with settings and history carried over on desktops, the Windows installer replacing
  ShiftDrop, and `shiftdrop.pages.dev` kept as a pointer for old copies (`docs/legacy-site/`).
- **Help** with common questions, shortcuts and What's new; **Report a problem** and **Suggest a feature** by email
  (`arcvert.support@gmail.com`) or GitHub; a once-per-update What's new note.

## 0.15.0: PDF passwords, RAR in parts, menu speed

**Not published**: in 0.16.0. Built 16 November 2026 as ShiftDrop, and tried by the owner on real devices. With it,
everything planned before 1.0 is built; what remains is the checklist below.

- **Add password to a PDF** (`lockPdf`), in pure Dart rather than by bundling qpdf, so it works on every platform.
- **RAR files in several parts** (`archive_parts.dart`, `joinArchiveParts`): `part1.rar` or `.rar`, `.r00` names.
- **Menu speed** in Settings on a Mac or Windows (`menu_speed.dart`): each Shift-drag menu times itself, for the
  checklist's 100 ms.

## 1.0 checklist (launch 12 April 2027)

- **Done** (owner, 16 November 2026): Windows tried: Shift-drag from Explorer, Alt for Tools, the native rings, dragging
  results out, open at login.
- **Done** (owner, 16 November 2026: under 100 ms on Mac and Windows): the menu opens within 100 ms of pressing Shift,
  measured on both desktops. Each menu now times itself (`menu_speed.dart`):
  do about 20 Shift-drags of a photo, a PDF and a folder, then read the line under the key in **Settings**. Waiting is
  counted at its longest (the check runs 30 times a second), and the screen may take one more refresh to show the menu.
  If it's over, `flutter run` prints each drag's parts (wait, find, ask, draw) to say which to speed up.
- No crash bugs open. Real-device tries: an iPhone HEIC photo, a form photo accepted by a real form, at least three
  Android phone brands.
- SignPath signing for Windows, and the Microsoft Store package, built with `--dart-define=ARCVERT_STORE=true`.
- A native Hindi speaker has reviewed `app_hi.arb`.
- Android package name registered with Google, with the real signing key.
