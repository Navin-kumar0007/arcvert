# Changelog

## 0.14.0 (unreleased)

- **Extract pages** from a PDF, on every platform: pick pages from pictures of each, or type them, such as 1-3, 7.
  They come out as one PDF, in the order typed.
- Pictures keep when they were taken, the camera and lens, and how they were exposed, when converted, compressed,
  turned, flipped, resized or cropped. Where they were taken never comes along, nor serial numbers or the owner's
  name. Make it fit and Strip metadata keep no details at all, as their files are made to be sent.

## 0.13.0 (beta, 16 November 2026)

- **Clean up a signature** in Form photo: a signature photographed or scanned on paper is cropped to the ink, the
  paper made white and the ink darker, then fitted to the form's size and KB limits without cutting into it. Blue ink
  stays blue. The signature presets turn it on; photos never get it, as forms refuse retouched ones.
- **Scanned document** in Make it fit: photos of pages become one clean greyscale PDF, with white paper and black
  print, under 1 MB, or 500 KB or 200 KB from the outer ring. Put the pages in order first. It prints at A4 size.
- Resting on **Rotate**, **Flip** or **Resize**, or one of their choices, shows the picture already turned, flipped
  or smaller in the middle of the menu, with its new size in pixels, before anything is converted.
- **Compress** has three levels on its outer ring, for pictures, video and PDFs: **Balanced**, as before, **Best
  quality**, which keeps more detail, and **Smallest**, which makes the file as small as still looks right.
- The chip after a Shift-drag shows the result's own picture, from Quick Look on a Mac and the shell on Windows,
  where it used to show a file icon or nothing.
- Fixed in the web app: Rotate's 180° and 90° left, Flip's upside down and Resize's sizes ran as their first choice,
  as the worker that converts in a browser was never told the choice.
- Fixed: the menu no longer turns back to its first page, and loses what's highlighted, while previews load.
- Fixed: choosing a size from Scanned document's ring asks for the page order first, as the slice does.
- Fixed: a PDF's preview in the web app showed "Can't preview this" until a PDF action had run.
- Compress never hands back a larger file of the same kind; it says the picture is as small as that level makes it.

## 0.12.0 (beta, 15 November 2026)

- A new look, in light and dark, following the device unless **Settings** says otherwise. The main screen shows the
  dial before any file is in: drop files on it, or choose them from its middle. Beside it, how Shift-drag works, what
  Make it fit offers, your recent results with Undo, and what stays on the device.
- **Make it fit** has its own tab and its own amber colour, apart from the formats in **Convert** and the **Tools**.
- Results show how much smaller they came out, and where they can be dragged on.
- **Settings** shows the three themes as small pictures to choose from.
- On a phone, the menu is half a dial along the bottom, in reach of a thumb, with a big button to run what's chosen
  and its choices, such as Rotate's 180°, above it.
- The Shift-drag menu and the chip after it, on Mac and Windows, have the same colours, in light and dark.
- Text is set in Inter, with headings in Space Grotesk, both shipped in the app.
- **Copy details** on a file that failed puts the app's version, the platform, the action, the kind of file and the
  failure's name on the clipboard, ready to paste into a bug report. Never the file's name or anything inside it.

## 0.11.0 (beta, 11 November 2026)

- Settings, behind the gear at the top: where results go (beside the original, or one folder of your choice, on Mac
  and Windows), theme, language, previews, open at login and update checks. About now only says what the app is.
- Merging PDFs, video or sound, and One PDF from pictures, first show the files in a list to put in order, by
  dragging or with arrow buttons.
- Previews: the first file's first page before converting, and its result after, with a line to drag across
  pictures to compare them, sizes and weights underneath, a small picture on each result, and Enlarge to zoom in.
  Settings turns them off.

## 0.10.1 (beta, 16 November 2026)

- Fixed in the web app: Rotate's 180° and 90° left, Flip's upside down and Resize's sizes from the outer ring ran as
  the slice's first choice, as the worker that converts in a browser was never told the choice. The apps for Mac,
  Windows and Android were not affected.

## 0.10.0 (beta, 11 November 2026)

This is the first version that tells you about the next one. Copies of 0.9 don't check, so install this one by hand.

- A short guide on first launch, with a practice Shift-drag on a sample photo. **About** shows it again.
- Mac and Windows copies from the website check once a day for a newer version and offer the download. The only
  thing the app fetches, and **About** turns it off. On Android, **About** links to the download page instead.
- Hold Option (Mac) or Alt (Windows) during a Shift-drag for Tools, such as Compress, Rotate and Resize, with the
  outer ring of choices for Rotate, Flip and Resize there too.
- Choose English or Hindi for the app in **About**, whatever the device's language.
- Rest on a slice and the menu says how big the result will be. For one picture it really makes it, so choosing that slice is then instant. This works in the Shift-drag menu on Mac and Windows too.
- PDF to Word keeps simple tables as real Word tables, bold text, and the pictures on text pages.
- Rotate, Flip and Resize show their choices around the slice: 180° or a quarter turn left, upside down, or a long side of 1920, 1280 or 640 pixels. On a phone, tap once to see them.
- Videos and sound show a size as well, worked out from their length without converting, when it can be told honestly.

## 0.9.1 (beta, 9 November 2026)

- Android: a long conversion keeps going when you leave the app, with a notification while it runs.
- Mac and Windows: About has an "Open at login" switch. At login the app starts quietly, ready for Shift-drag.
- Links point to the project's new address, github.com/Navin-kumar0007/shiftdrop.

## 0.9.0 (beta, 8 November 2026)

First version people can try.

- Convert pictures (including HEIC), video, audio, PDFs, archives (including 7z and RAR) and subtitles.
- Shift-drag menu on macOS and Windows, a share target on Android, and a web app for everything else.
- Make it fit: WhatsApp, Email, Instagram and size limits.
- Form photos, with presets that show their sources.
- PDF to Word, password removal, merging, splitting, rotating and compressing.
- Crop, trim with a preview of both ends, and subtitle shift.
- Whole folders can be dropped or Shift-dragged.
- Drag results out to other apps on a desktop, or share them on a phone.
- History, with undo that moves a result to the Trash.
- English and Hindi, following the device's language.
