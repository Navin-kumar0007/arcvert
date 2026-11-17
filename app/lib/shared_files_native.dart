import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';

import 'drop_files_native.dart';
import 'picked_file.dart';
import 'shared_files.dart';

/// `ShareReceiver.kt` on the other side.
const shareChannel = MethodChannel('radial/share');

/// Only Android shares files with apps this way so far.
Stream<SharedFiles> listenForSharedFiles() {
  if (!Platform.isAndroid) return const Stream.empty();
  return listenOnShareChannel();
}

/// `OpenedFiles` in `AppDelegate.swift` or `FlutterWindow` in `flutter_window.cpp` on the other side.
const openChannel = MethodChannel('radial/open');

/// Paths opened from outside the app on a Mac or Windows: Open With or the Convert with Arcvert
/// service in Finder, or Convert with Arcvert in Explorer's right-click menu. The app may have been
/// started to open them, so they wait on the other side until this listens.
Stream<List<String>> listenForOpenedFiles() {
  if (!Platform.isMacOS && !Platform.isWindows) return const Stream.empty();
  late final StreamController<List<String>> events;
  events = StreamController<List<String>>(
    onListen: () {
      openChannel.setMethodCallHandler((call) async {
        if (call.method != 'open') return;
        final paths = ((call.arguments as Map)['paths'] as List).whereType<String>().toList();
        if (paths.isNotEmpty) events.add(paths);
      });
      // Nothing answers in tests of the screen alone.
      openChannel.invokeMethod<void>('listen').catchError((Object _) {});
    },
    onCancel: () => openChannel.setMethodCallHandler(null),
  );
  return events.stream;
}

/// Everything is copied to real files before it arrives here, so it reads like a dropped file.
Stream<SharedFiles> listenOnShareChannel() {
  late final StreamController<SharedFiles> events;
  events = StreamController<SharedFiles>(
    onListen: () {
      shareChannel.setMethodCallHandler((call) async {
        if (call.method == 'receiving') {
          events.add(const SharedFiles.receiving());
        } else if (call.method == 'shared') {
          final arguments = call.arguments as Map;
          final paths = (arguments['paths'] as List).cast<String>();
          var failed = arguments['failed'] as int;
          final files = <PickedFile>[];
          for (final path in paths) {
            try {
              files.addAll((await readDroppedFiles([DropItemFile(path)])).loose);
            } on FileSystemException {
              failed++;
            }
          }
          events.add(SharedFiles.arrived(files, failed: failed));
        }
      });
      shareChannel.invokeMethod<void>('listen');
    },
    onCancel: () => shareChannel.setMethodCallHandler(null),
  );
  return events.stream;
}
