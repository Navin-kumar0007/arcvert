import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<File> _file() async {
  return File(p.join((await getApplicationSupportDirectory()).path, 'settings.json'));
}

/// Where the app kept its files when it was called ShiftDrop, before 0.16: the same folder under
/// the old name, `io.github.navinkumar0007.shiftdrop` on a Mac and `ShiftDrop contributors\ShiftDrop`
/// on Windows. Null if the name doesn't appear in [folder].
String? oldNameFolder(String folder) {
  String older(String part) =>
      part.replaceAll('Arcvert', 'ShiftDrop').replaceAll('arcvert', 'shiftdrop');
  final parent = p.dirname(folder);
  final old = p.join(p.dirname(parent), older(p.basename(parent)), older(p.basename(folder)));
  return old == folder ? null : old;
}

/// What a desktop kept while the app was called ShiftDrop, copied into [folder] the first time
/// Arcvert opens there. The old files are only read, never changed, so going back still works.
Future<void> bringOverOldName(Directory folder) async {
  if (File(p.join(folder.path, 'settings.json')).existsSync()) return;
  final old = oldNameFolder(folder.path);
  if (old == null || !Directory(old).existsSync()) return;
  for (final name in const ['settings.json', 'history.json']) {
    final from = File(p.join(old, name));
    final to = File(p.join(folder.path, name));
    if (!from.existsSync() || to.existsSync()) continue;
    try {
      await folder.create(recursive: true);
      await from.copy(to.path);
    } on FileSystemException catch (error) {
      // Starting afresh is fine: neither file is needed to work.
      stderr.writeln('Could not bring over $name: $error');
    }
  }
}

/// The saved settings, or null if there are none.
Future<String?> readSettingsText() async {
  if (Platform.isMacOS || Platform.isWindows) {
    await bringOverOldName(await getApplicationSupportDirectory());
  }
  final file = await _file();
  return file.existsSync() ? file.readAsString() : null;
}

/// Replaces the saved settings, whole or not at all, as history is.
Future<void> writeSettingsText(String text) async {
  final file = await _file();
  await file.parent.create(recursive: true);
  final part = File('${file.path}.part');
  await part.writeAsString(text, flush: true);
  await part.rename(file.path);
}

/// Whether results can be written into [path]: it is a folder that exists and takes a new file.
Future<bool> folderWritable(String path) async {
  final folder = Directory(path);
  if (!folder.existsSync()) return false;
  try {
    final trial = await folder.createTemp('.arcvert-');
    await trial.delete();
    return true;
  } on FileSystemException {
    return false;
  }
}
