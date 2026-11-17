import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:radial_core/radial_core.dart';

import 'words.dart';
import 'menu_speed.dart';

/// `MainFlutterWindow.swift` or `shift_drag.cpp` on the other side.
const shiftDragChannel = MethodChannel('radial/shift_drag');

/// Answers the system-wide Shift-drag menu: what these files can become, and what was chosen. Returns
/// how to stop.
///
/// The menu asks with `tools` true while Alt (Option on a Mac) is held as well, and each slice comes
/// with the labels of its outer-ring choices, if it has any. A choice comes back as its index:
/// none, or 0, is what the slice itself does.
void Function() listenForShiftDrag({
  required Future<List<RadialAction>> Function(List<String> paths, ActionMode mode) menuFor,
  required Future<String?> Function(RadialAction action, List<String> paths) sizeOf,
  required void Function(RadialAction action, List<String> paths, ActionOptions options) chosen,
}) {
  if (!Platform.isMacOS && !Platform.isWindows) return () {};
  // What the menu last offered. Slices the user made aren't in the catalogue, so a choice or a
  // size asked for is looked up here first.
  var offered = const <RadialAction>[];
  RadialAction? find(Object? id) {
    if (id is! String) return null;
    return offered.where((action) => action.id == id).firstOrNull ?? actionById(id);
  }

  shiftDragChannel.setMethodCallHandler((call) async {
    if (call.method == 'menuTiming') {
      final timing = MenuTiming.fromWire(call.arguments);
      if (timing != null) MenuSpeed.instance.add(timing);
      return null;
    }
    final arguments = call.arguments as Map;
    final paths = (arguments['paths'] as List).cast<String>();
    if (call.method == 'menuFor') {
      final mode = arguments['tools'] == true ? ActionMode.tools : ActionMode.convert;
      offered = await menuFor(paths, mode);
      return [for (final action in offered) shiftDragSlice(action, deviceWords)];
    }
    if (call.method == 'sizeOf') {
      // What the centre shows while the drag rests on a slice, such as "About 240 KB".
      final action = find(arguments['id']);
      return action == null ? null : await sizeOf(action, paths);
    }
    if (call.method == 'chosen') {
      final action = find(arguments['id']);
      if (action != null) chosen(action, paths, shiftDragOptions(action, arguments['choice']));
    }
    return null;
  });
  sendNativeWords();
  return () => shiftDragChannel.setMethodCallHandler(null);
}

/// A slice as the native menu draws it.
Map<String, Object> shiftDragSlice(RadialAction action, Words words) {
  final choices = ringChoices(action);
  return {
    'id': action.id,
    // A slice the user made has their name, which may be longer than a slice can show.
    'label': action is MyFitAction
        ? shortSliceLabel(action.label)
        : actionLabel(words, action.label),
    // Make it fit is drawn in amber, as in the window.
    if (action.isFit) 'fit': true,
    if (choices.isNotEmpty)
      'choices': [for (final choice in choices) ringChoiceLabel(words, choice)],
  };
}

/// [label] cut to what the native menus can draw on a slice, at a word where it can be.
String shortSliceLabel(String label, {int most = 18}) {
  if (label.length <= most) return label;
  final cut = label.substring(0, most - 3);
  final space = cut.lastIndexOf(' ');
  return '${(space >= most ~/ 2 ? cut.substring(0, space) : cut).trimRight()}...';
}

/// What a choice from the native menu's outer ring runs with. The first is the slice itself, and
/// runs as plain options so the slice's size trial can be reused.
ActionOptions shiftDragOptions(RadialAction action, Object? choice) {
  final choices = ringChoices(action);
  if (choice is! int || choice <= 0 || choice >= choices.length) return const ActionOptions();
  return choices[choice].options;
}

/// Gives the native menus their words in the app's language, again whenever it changes.
void sendNativeWords() {
  if (!Platform.isMacOS && !Platform.isWindows) return;
  final words = deviceWords;
  shiftDragChannel
      .invokeMethod<void>('setWords', {
        'cancel': words.cancel,
        'tools': words.modeTools,
        'dragToApp': words.dragToApp,
        'trayStillRunning': words.trayStillRunning,
        'trayHowToQuit': words.trayHowToQuit,
        'trayOpen': words.trayOpen,
        'trayQuit': words.trayQuit,
        // Not a word: the theme rides along, so the menus need no message of their own for it.
        'theme': chosenTheme,
        'trigger': chosenTrigger,
      })
      .catchError((Object _) {
        // The native side keeps its English.
      });
}

/// Writes [files], whose names are paths inside an archive with `/` between folders, into a new
/// folder named [name] beside [originalPath], or in [folder]. A name already there gets a number.
/// It's built under a `.part` name and renamed at the end, so a half-written folder never looks
/// finished. Returns where the folder is.
Future<String> saveFolderBesideOriginal(
  String originalPath,
  String name,
  List<PortableFile> files, {
  String? folder,
}) async {
  final into = folder ?? p.dirname(originalPath);
  var target = p.join(into, name);
  for (var n = 2; FileSystemEntity.typeSync(target) != FileSystemEntityType.notFound; n++) {
    target = p.join(into, '$name $n');
  }
  final part = Directory('$target.part');
  try {
    for (final file in files) {
      final path = p.joinAll([part.path, ...file.name.split('/')]);
      // The archive engine already refused paths that leave the folder; this makes sure.
      if (!p.isWithin(part.path, path)) throw Fail.pointsOutside(name);
      await Directory(p.dirname(path)).create(recursive: true);
      await File(path).writeAsBytes(file.bytes);
    }
    await part.rename(target);
  } on FileSystemException {
    if (part.existsSync()) part.deleteSync(recursive: true);
    throw Fail.cantSaveBeside(name);
  }
  return target;
}

/// Writes [file] next to the file it came from, or into [folder] if given, under a free name.
/// Returns where. Originals and anything else already there are never replaced.
Future<String> saveBesideOriginal(String originalPath, PortableFile file, {String? folder}) async {
  final into = folder ?? p.dirname(originalPath);
  bool taken(String name) => File(p.join(into, name)).existsSync();
  final name = !taken(file.name)
      ? file.name
      : freeOutputName(
          inputName: file.name,
          extension: splitFileName(file.name).extension,
          suffix: 'copy',
          exists: taken,
        );
  final path = p.join(into, name);
  // It appears whole or not at all, so nothing can pick up half a file.
  final part = File('$path.part');
  try {
    await part.writeAsBytes(file.bytes, flush: true);
    await part.rename(path);
  } on FileSystemException {
    if (part.existsSync()) part.deleteSync();
    throw Fail.cantSaveBeside(name);
  }
  return path;
}

/// Brings the window forward, as the user may have closed it or be in another app.
void showAppWindow() {
  if (Platform.isMacOS || Platform.isWindows) shiftDragChannel.invokeMethod<void>('showWindow');
}

/// Whether the app opens when the user signs in, so Shift-drag works from then on.
enum LoginItem {
  /// Not on this platform, or this version of it.
  unsupported,
  off,
  on,

  /// Asked for, but macOS wants the user to allow it in System Settings.
  needsApproval;

  static LoginItem _from(String? answer) => switch (answer) {
    'on' => on,
    'off' => off,
    'approval' => needsApproval,
    _ => unsupported,
  };
}

Future<LoginItem> loginItem() async {
  if (!Platform.isMacOS && !Platform.isWindows) return LoginItem.unsupported;
  try {
    return LoginItem._from(await shiftDragChannel.invokeMethod<String>('loginItem'));
  } catch (_) {
    return LoginItem.unsupported;
  }
}

/// Turns opening at login on or off, and answers with how it is now.
Future<LoginItem> setLoginItem(bool on) async {
  try {
    return LoginItem._from(await shiftDragChannel.invokeMethod<String>('setLoginItem', {'on': on}));
  } catch (_) {
    return loginItem();
  }
}
