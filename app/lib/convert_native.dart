import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:radial_core/engines.dart';
import 'package:radial_core/radial_core.dart';

import 'android_media.dart';
import 'picked_file.dart';

class _Request {
  const _Request(this.actionId, this.files, this.options);

  final String actionId;
  final List<PortableFile> files;
  final ActionOptions options;
}

Future<List<PortableFile>> _run(_Request request) {
  return runPortable(actionById(request.actionId)!, request.files, options: request.options);
}

/// Converts in a background isolate, so the app stays responsive. Isolates report no progress
/// through `compute`, so [onProgress] is not called here.
Future<List<PortableFile>> convert(
  RadialAction action,
  List<PortableFile> files,
  void Function(double progress) onProgress, [
  ActionOptions options = const ActionOptions(),
]) {
  return compute(_run, _Request(action.id, files, options));
}

/// On a desktop the engines ship inside the app.
EngineTools _appEngines() {
  final folder = p.dirname(Platform.resolvedExecutable);
  return EngineTools(
    bundledFolder: Platform.isMacOS
        ? p.join(p.dirname(folder), 'Resources', 'engines')
        : p.join(folder, 'engines'),
  );
}

/// True if these tools can run video on a desktop.
bool mediaEngineAvailableWith(EngineTools tools) {
  if (!Platform.isMacOS && !Platform.isWindows) return false;
  return tools.find('ffmpeg') != null && tools.find('ffprobe') != null;
}

/// Android brings its own encoders.
bool mediaEngineAvailable() => Platform.isAndroid || mediaEngineAvailableWith(_appEngines());

/// What video and audio can become here, or null for everything that can be planned.
Set<FileKind>? mediaOutputsHere() => Platform.isAndroid ? phoneMediaOutputs : null;

/// Reads a HEIC photo, upright, as a PNG. Desktops use the FFmpeg they already carry.
Future<Uint8List> decodeHeicWith(EngineTools tools, String path) async {
  final result = await Process.run(
    tools.ffmpeg,
    [
      '-hide_banner',
      '-loglevel',
      'error',
      '-i',
      path,
      '-frames:v',
      '1',
      '-c:v',
      'png',
      '-f',
      'image2pipe',
      '-',
    ],
    stdoutEncoding: null,
    stderrEncoding: null,
  );
  final png = result.stdout as List<int>;
  if (result.exitCode != 0 || png.isEmpty) {
    throw Fail.photoDamaged;
  }
  return Uint8List.fromList(png);
}

/// Reads a HEIC photo as a PNG, so the picture engine can take it from there.
Future<Uint8List> decodeHeic(PickedFile file) async {
  final path = file.path;
  if (path == null) throw Fail.cantRead(file.name);
  return Platform.isAndroid ? decodeHeicOnPhone(path) : decodeHeicWith(_appEngines(), path);
}

/// A 7z or RAR unpacked into a ZIP, so the archive engine can take it from there. A RAR in several
/// parts reads them all, in order: those chosen with it, or on a desktop those found beside it.
Future<Uint8List> unpackArchive(PickedFile file) async {
  var path = file.path;
  if (path == null) throw Fail.cantRead(file.name);
  var parts = [for (final part in file.moreParts) part.path ?? (throw Fail.cantRead(part.name))];
  if (parts.isEmpty && !Platform.isAndroid) {
    final beside = await _partsBeside(path, file.head);
    if (beside != null) {
      path = beside.first;
      parts = beside.sublist(1);
    }
  }
  return Platform.isAndroid
      ? unpackOnPhone(path, moreParts: parts)
      : unpackToZip(path, moreParts: parts);
}

/// Every part of the RAR at [path], in order, if it is one of several and they are beside it.
/// Phones can't look: other apps hand over files one by one.
Future<List<String>?> _partsBeside(String path, List<int> head) async {
  final split = rarSplitOf(head);
  if (split == null || split == RarSplit.whole) return null;
  final folder = p.dirname(path);
  final names = <String>[];
  try {
    await for (final entry in Directory(folder).list()) {
      if (entry is File) names.add(p.basename(entry.path));
    }
  } on FileSystemException {
    return null;
  }
  final found = partsBeside(p.basename(path), names);
  if (found == null) return null;
  final missing = found.missing;
  if (missing != null) throw Fail.partMissing(missing, found.name);
  return [for (final name in found.parts) p.join(folder, name)];
}

/// What is inside a video or audio file, read without changing it.
Future<MediaInfo> probeMedia(PickedFile file) async {
  final path = file.path;
  if (path == null) throw Fail.cantRead(file.name);
  return Platform.isAndroid ? probeOnPhone(path) : ActionRunner(_appEngines()).probe(path);
}

/// One frame of a video, to show before trimming.
Future<Uint8List> videoFrame(PickedFile file, double seconds) async {
  final path = file.path;
  if (path == null) throw Fail.cantRead(file.name);
  return Platform.isAndroid
      ? videoFrameOnPhone(path, seconds)
      : ActionRunner(_appEngines()).frameAt(path, seconds);
}

/// Runs the engine as a separate process and saves beside the original, so size is not limited
/// by memory. The original is never touched.
Future<List<ConvertedFile>> convertMedia(
  RadialAction action,
  List<PickedFile> files,
  List<FileKind> kinds,
  void Function(double progress) onProgress,
  ConvertControl control, [
  ActionOptions options = const ActionOptions(),
]) async {
  if (Platform.isAndroid) {
    return convertMediaOnPhone(action, files, kinds, onProgress, control, options);
  }
  final paths = <String>[];
  for (final file in files) {
    final path = file.path;
    if (path == null) throw Fail.cantRead(file.name);
    paths.add(path);
  }

  final runner = ActionRunner(_appEngines());
  final queue = JobQueue(maxParallel: 1);
  final results = <ConvertedFile>[];
  try {
    for (var i = 0; i < paths.length; i++) {
      final job = queue.add(
        (context) => runner.run(
          action,
          [paths[i]],
          context,
          options: options,
          outputFolder: control.outputFolder,
        ),
      );
      control.cancel = job.cancel;
      final progress = queue.changes.listen((changed) {
        if (identical(changed, job) && changed.progress > 0) {
          onProgress((i + changed.progress) / paths.length);
        }
      });
      try {
        for (final output in await job.result) {
          results.add(
            ConvertedFile(
              name: p.basename(output),
              size: await sizeOnDisk(output),
              savedPath: output,
            ),
          );
        }
      } finally {
        await progress.cancel();
      }
    }
  } finally {
    control.cancel = null;
    await queue.dispose();
  }
  return results;
}
