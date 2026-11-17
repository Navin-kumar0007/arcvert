import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:radial_core/radial_core.dart' show MyFit;

import 'app_settings.dart';

/// What marks a file as Arcvert's settings, and the version of its layout.
const _marker = 'arcvertSettings';
const _layout = 1;

/// A settings file is a few KB; anything far larger isn't one.
const maxBackupBytes = 1024 * 1024;

/// The settings worth bringing to another device, as a file to keep: choices, slices and the learned
/// order. Never what belongs to this device alone: a results folder, when updates were last checked,
/// whether the guide or What's new was seen. Holds no files, file names or history.
String exportSettings(AppSettings settings, {required String appVersion, DateTime? now}) {
  final portable = jsonDecode(settings.encode()) as Map<String, Object?>
    ..remove('welcomed')
    ..remove('lastUpdateCheck')
    ..remove('resultsFolder')
    ..remove('whatsNewSeen');
  return const JsonEncoder.withIndent('  ').convert({
    _marker: _layout,
    'appVersion': appVersion,
    'exported': _day(now),
    'settings': portable,
  });
}

/// The name a settings file is offered under: `Arcvert settings 2026-11-17.json`.
String backupFileName({DateTime? now}) => 'Arcvert settings ${_day(now)}.json';

String _day(DateTime? now) => (now ?? DateTime.now()).toIso8601String().substring(0, 10);

/// Settings read from a file, ready to bring in.
class SettingsBackup {
  const SettingsBackup(this.settings, this._keys);

  /// Read as [AppSettings.decode] reads them, so anything damaged is the default.
  final AppSettings settings;

  /// Which settings the file had, so ones it lacks are left as they are.
  final Set<String> _keys;

  bool has(String key) => _keys.contains(key);
}

/// Reads a settings file. Throws [FormatException] if it isn't one.
SettingsBackup readSettingsBackup(Uint8List bytes) {
  if (bytes.length > maxBackupBytes) throw const FormatException('Too large');
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const FormatException('Not JSON');
  }
  if (json is! Map || json[_marker] is! int) throw const FormatException('Not Arcvert settings');
  final settings = json['settings'];
  if (settings is! Map) throw const FormatException('No settings');
  return SettingsBackup(AppSettings.decode(jsonEncode(settings)), {
    for (final key in settings.keys) '$key',
  });
}

/// What bringing a file in would change, worked out before it is done.
class SettingsImport {
  const SettingsImport({
    required this.result,
    required this.slicesAdded,
    required this.slicesChanged,
    required this.slicesLeftOut,
  });

  /// The settings once brought in.
  final AppSettings result;
  final int slicesAdded;
  final int slicesChanged;

  /// Slices with no room left, as there can be [MyFit.most].
  final int slicesLeftOut;
}

/// [current] with [backup] brought in. Choices the file has replace these; its slices join these,
/// each replacing one with the same id or name; learned counts keep the larger of the two. What
/// belongs to this device is kept.
SettingsImport importSettings(AppSettings current, SettingsBackup backup) {
  final from = backup.settings;
  var added = 0, changed = 0, leftOut = 0;
  final fits = [...current.myFits];
  for (final fit in from.myFits) {
    final at = fits.indexWhere(
      (old) => old.id == fit.id || old.name.toLowerCase() == fit.name.toLowerCase(),
    );
    if (at >= 0) {
      // Keeps this device's id, so its learned count stays with it.
      final kept = MyFit(id: fits[at].id, name: fit.name, form: fit.form);
      if (fits[at] != kept) changed++;
      fits[at] = kept;
    } else if (fits.length < MyFit.most) {
      fits.add(fit);
      added++;
    } else {
      leftOut++;
    }
  }
  final uses = {...current.uses};
  for (final MapEntry(:key, :value) in from.uses.entries) {
    if (value > (uses[key] ?? 0)) uses[key] = value;
  }
  final result = current.copyWith(
    checkForUpdates: backup.has('checkForUpdates') ? from.checkForUpdates : null,
    language: backup.has('language') ? () => from.language : null,
    theme: backup.has('theme') ? from.theme : null,
    showPreviews: backup.has('showPreviews') ? from.showPreviews : null,
    learnOrder: backup.has('learnOrder') ? from.learnOrder : null,
    uses: uses.length > AppSettings.mostUses ? null : uses,
    triggerKey: backup.has('triggerKey') ? from.triggerKey : null,
    myFits: List.unmodifiable(fits),
  );
  return SettingsImport(
    result: result,
    slicesAdded: added,
    slicesChanged: changed,
    slicesLeftOut: leftOut,
  );
}

/// Offers the settings file to save: a save dialog, or a download in a browser. False if cancelled.
Future<bool> saveSettingsFile(String name, Uint8List bytes) async {
  final saved = await FilePicker.saveFile(
    fileName: name,
    bytes: bytes,
    mimeType: 'application/json',
  );
  // A browser just downloads it, with nothing to return.
  return kIsWeb || saved != null;
}

/// Asks for a settings file and reads it. Null if none was chosen.
Future<Uint8List?> pickSettingsFile() async {
  final picked = await FilePicker.pickFiles();
  if (picked.isEmpty) return null;
  final file = picked.first;
  // Too large to be one: not read, and refused as not a settings file.
  if ((await file.length() ?? 0) > maxBackupBytes) return Uint8List(maxBackupBytes + 1);
  return file.readAsBytes();
}
