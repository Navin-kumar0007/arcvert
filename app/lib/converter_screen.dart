import 'dart:async';
import 'dart:collection';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:radial_core/radial_core.dart';

import 'about.dart';
import 'app_settings.dart';
import 'conversion.dart';
import 'drop_files.dart';
import 'file_chip.dart';
import 'history_screen.dart';
import 'history_store.dart';
import 'help_screen.dart';
import 'home_parts.dart';
import 'live_look.dart';
import 'keep_going.dart';
import 'option_screens.dart';
import 'presets.dart';
import 'preview.dart';
import 'preview_view.dart';
import 'radial_menu.dart';
import 'reorder_dialog.dart';
import 'settings_screen.dart';
import 'settings_store.dart';
import 'shared_files.dart';
import 'shift_drag.dart';
import 'size_preview.dart';
import 'theme.dart';
import 'thumb_arc.dart';
import 'words.dart';

typedef FilesPicker = Future<List<PickedFile>> Function();
typedef DropReader = Future<DroppedFiles> Function(List<DropItem> items);
typedef ShiftDragListener = void Function() Function({
  required Future<List<RadialAction>> Function(List<String> paths, ActionMode mode) menuFor,
  required Future<String?> Function(RadialAction action, List<String> paths) sizeOf,
  required void Function(RadialAction action, List<String> paths, ActionOptions options) chosen,
});
typedef KeepWorking = Future<void> Function(bool working);
typedef FileSaver = Future<SavedAs?> Function(PortableFile file);
typedef ArchiveUnpacker = Future<Uint8List> Function(PickedFile file);
typedef ResultHandOver = Future<void> Function(ConvertedFile output);
typedef MediaProbe = Future<MediaInfo> Function(PickedFile file);
typedef FrameReader = Future<Uint8List> Function(PickedFile file, double seconds);
typedef Converter = Future<List<PortableFile>> Function(
  RadialAction action,
  List<PortableFile> files,
  void Function(double progress) onProgress,
  ActionOptions options,
);

typedef PdfConverter = Future<List<PdfResult>> Function(
  RadialAction action,
  List<PortableFile> files,
  void Function(double progress) onProgress,
  ActionOptions options,
);
typedef PhotoDecoder = Future<Uint8List> Function(PickedFile file);
typedef MediaConverter = Future<List<ConvertedFile>> Function(
  RadialAction action,
  List<PickedFile> files,
  List<FileKind> kinds,
  void Function(double progress) onProgress,
  ConvertControl control,
  ActionOptions options,
);

/// Results past this many in a list show their tick rather than a picture, as each takes a moment.
const _thumbnailRows = 30;

/// As many slices as the Shift-drag menu can label readably.
const _shiftDragSlices = 8;

/// A result, and the original it belongs beside. Files can fail along the way, so position in the
/// list says nothing about that.
class _Result {
  _Result(this.output, this.from, this.bytesBefore);

  final ConvertedFile output;
  final PickedFile from;
  final int? bytesBefore;
}

/// The window's three menus. Convert and Make it fit are both the Shift menu's actions, split so
/// purposes don't crowd formats; Tools is the Shift + Option menu.
enum _Tab { convert, fit, tools }

class _Job {
  _Job(this.name, this.bytesBefore);

  final String name;

  /// What this result can fairly be compared with. Null for one of many files from one archive.
  final int? bytesBefore;
  FileChipState state = FileChipState.working;
  double? progress;
  ConvertedFile? output;
  PickedFile? from;
  String? message;

  /// For a failure: facts for a bug report, without file names (`failureDetails`).
  String? details;
  bool saved = false;

  /// What was done, as the menu called it.
  String? actionLabel;

  /// Its line in the history, once saved.
  int? historyId;
  bool undone = false;
}

/// Pick files, choose a slice, save the result. The same screen on every platform. On desktop
/// the Shift-drag trigger will open the same menu at the cursor.
Future<List<PdfResult>> _defaultPdf(
  RadialAction action,
  List<PortableFile> files,
  void Function(double) onProgress,
  ActionOptions options,
) => convertPdf(action, files, onProgress, options: options);

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({
    super.key,
    required this.pickFiles,
    required this.saveFile,
    this.converter = convert,
    this.mediaConverter = convertMedia,
    this.pdfConverter = _defaultPdf,
    this.photoDecoder = decodeHeic,
    this.archiveUnpacker = unpackArchive,
    this.dragResultOut = dragOut,
    this.shareResult = shareOut,
    this.resultsDrag,
    this.resultsShare,
    this.historyReader = readHistoryText,
    this.historyWriter = writeHistoryText,
    this.trashResult = moveResultToTrash,
    this.revealResult = showResultInFolder,
    this.undoAvailable,
    this.mediaProbe = probeMedia,
    this.frameReader = videoFrame,
    this.presetLoader = loadBundledPresets,
    this.dropReader = readDroppedFiles,
    this.sharedFiles = listenForSharedFiles,
    this.shiftDrag = listenForShiftDrag,
    this.keepWorking = keepWorkingInBackground,
    this.mediaAvailable,
    this.acceptsDrops,
    this.savesBeside,
    this.showGuide,
    this.folderCheck = folderWritable,
    this.pdfPage = pdfFirstPage,
  });

  final FilesPicker pickFiles;
  final FileSaver saveFile;
  final Converter converter;
  final MediaConverter mediaConverter;
  final PdfConverter pdfConverter;
  final PhotoDecoder photoDecoder;
  final ArchiveUnpacker archiveUnpacker;
  final ResultHandOver dragResultOut;
  final ResultHandOver shareResult;

  /// Whether results can be dragged to other apps, or shared with them. Null asks the platform.
  final bool? resultsDrag;
  final bool? resultsShare;
  final Future<String?> Function() historyReader;
  final Future<void> Function(String text) historyWriter;
  final Future<void> Function(String path, int expectedSize) trashResult;
  final Future<void> Function(String path) revealResult;

  /// Whether saved results can be undone and shown. Null asks the platform.
  final bool? undoAvailable;
  final MediaProbe mediaProbe;
  final FrameReader frameReader;
  final Future<List<Preset>> Function() presetLoader;
  final DropReader dropReader;

  /// What other apps share with this one. Called once.
  final Stream<SharedFiles> Function() sharedFiles;

  /// Starts listening for the system-wide Shift-drag menu, and returns how to stop.
  final ShiftDragListener shiftDrag;

  /// Asks the platform to keep the app going while a job runs, even if the user leaves it.
  final KeepWorking keepWorking;

  /// Whether this device can run video. Null asks the platform.
  final bool? mediaAvailable;

  /// Whether files can be dropped on the window. Null asks the platform: phones have no window to
  /// drag onto, and sharing is how files arrive there.
  final bool? acceptsDrops;

  /// Whether many results can go straight beside their originals. Null asks the platform: a phone's
  /// copies sit in a cache nobody would look in, and a browser has no folders to write to.
  final bool? savesBeside;

  /// Opens the first-launch guide again, from Settings.
  final VoidCallback? showGuide;

  /// Whether results can be written into a folder chosen in Settings.
  final Future<bool> Function(String folder) folderCheck;

  /// Draws page 1 of a PDF, for previews.
  final PdfPageReader pdfPage;

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  List<PickedFile> _files = const [];
  List<FileKind> _kinds = const [];
  _Tab _tab = _Tab.convert;
  bool _menuOpen = false;
  List<_Job> _jobs = const [];
  ConvertControl? _control;
  SizePreviews? _previews;

  /// The one file being Shift-dragged and its menu's trials, so the slice it's dropped on can take
  /// its trial. Kept until the next drag, as the native menu doesn't say when one is cancelled.
  ({List<String> paths, PickedFile file, SizePreviews previews})? _dragged;

  /// Jobs still running, as an earlier one can still be finishing when the next starts.
  int _working = 0;
  late final bool _mediaAvailable = widget.mediaAvailable ?? mediaEngineAvailable();
  late final bool _acceptsDrops =
      widget.acceptsDrops ??
      (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);
  late final bool _savesBeside =
      widget.savesBeside ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows));
  late final bool _resultsDrag = widget.resultsDrag ?? canDragOut;
  late final bool _resultsShare = widget.resultsShare ?? canShareOut;
  late final bool _undoAvailable = widget.undoAvailable ?? canUndoSaved;
  HistoryLog _history = HistoryLog();
  bool _savingAll = false;
  bool _dragging = false;
  bool _receiving = false;

  /// A chosen folder that can't be used is said once, not on every job.
  bool _saidFolderGone = false;

  /// Small pictures of the files and their results, made one at a time and kept until other files
  /// are opened.
  late final PreviewCache _looks = PreviewCache(
    Previewer(
      readPicture: _pictureToShow,
      frameAt: widget.frameReader,
      probe: widget.mediaProbe,
      pdfPage: widget.pdfPage,
      namesInside: (file) => _namesInside[file],
    ),
  );

  /// Unpacks a 7z or RAR for a job, noting the names inside for its preview on the way. A RAR in
  /// several parts needs them all, and says which is missing.
  Future<Uint8List> _unpack(PickedFile file) async {
    final missing = file.missingPart;
    if (missing != null) throw Fail.partMissing(missing, file.name);
    final Uint8List zip;
    try {
      zip = await widget.archiveUnpacker(file);
    } on EngineFailed catch (failure) {
      final split = rarSplitOf(file.head);
      final alone = file.moreParts.isEmpty && split != null && split != RarSplit.whole;
      if (failure.key == 'damagedOrPart' && alone) throw Fail.choosePartsTogether(file.name);
      rethrow;
    }
    try {
      _namesInside[file] = archiveNames(zip, FileKind.zip);
      _looks.forget(file);
    } catch (_) {
      // The job goes on; the preview just has no names.
    }
    return zip;
  }

  /// A locked PDF a job has just opened is drawn now, while its password is still in hand, and only
  /// the picture is kept.
  void _lookInsideUnlocked(List<PickedFile> files, List<FileKind> kinds, String password) {
    if (!_showPreviews) return;
    for (var i = 0; i < files.length; i++) {
      if (kinds[i] != FileKind.pdf) continue;
      final subject = PreviewSubject(file: files[i], kind: kinds[i], password: password);
      _looks
        ..forget(files[i])
        ..of(files[i], subject)
        ..of(files[i], subject, width: 1600);
    }
  }

  /// The names inside 7z and RAR files a job has unpacked, for their previews.
  final _namesInside = Expando<List<String>>('names inside');

  /// The preview panel hidden for now, from its own button. Settings turns previews off for good.
  bool _previewHidden = false;

  /// Only where there are settings to say so: tests of this screen alone make none.
  bool get _showPreviews => SettingsScope.maybeOf(context)?.value.showPreviews ?? false;

  Future<Preview> _lookAt(PickedFile file, FileKind kind, {int width = 600}) {
    return _looks.of(
      file,
      PreviewSubject(file: file, kind: kind),
      width: width,
    );
  }

  /// A result's preview, or null where it can't be reached.
  Future<Preview>? _lookAtResult(_Job job, {int width = 600}) {
    final output = job.output;
    if (output == null || job.undone) return null;
    final subject = PreviewSubject.ofResult(output);
    return subject == null ? null : _looks.of(job, subject, width: width);
  }

  /// The result to show beside the first file: its own, or the one that came of all of them.
  _Job? get _firstResult {
    final done = [
      for (final job in _jobs)
        if (job.state == FileChipState.done && job.output != null && !job.undone) job,
    ];
    if (done.isEmpty) return null;
    for (final job in done) {
      if (identical(job.from, _files.first)) return job;
    }
    return done.first;
  }

  late final StreamSubscription<SharedFiles> _shares;
  late final void Function() _stopShiftDrag;

  @override
  void initState() {
    super.initState();
    _shares = widget.sharedFiles().listen(_shared);
    _stopShiftDrag = widget.shiftDrag(
      menuFor: _menuFor,
      sizeOf: _sizeInShiftDrag,
      chosen: _chosenFromShiftDrag,
    );
    cleanUpHandedOver();
    _loadHistory();
  }

  @override
  void dispose() {
    _shares.cancel();
    _stopShiftDrag();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final loaded = HistoryLog.decode(await widget.historyReader());
      final forgot = loaded.prune(DateTime.now());
      // Anything already added while this was reading stays, newest first.
      final added = _history.items;
      _history = HistoryLog([...added, ...loaded.items]);
      if (mounted) setState(() {});
      if (forgot > 0 || added.isNotEmpty) await _storeHistory();
    } catch (error) {
      debugPrint('Could not read history: $error');
    }
  }

  /// A list that can't be written must never get in the way of the conversion itself.
  Future<void> _storeHistory() async {
    try {
      await widget.historyWriter(_history.encode());
    } catch (error) {
      debugPrint('Could not write history: $error');
    }
  }

  HistoryItem _remember({
    required String actionLabel,
    required String name,
    required int bytesAfter,
    String? path,
    int? bytesBefore,
  }) {
    final item = _history.add(
      finishedAt: DateTime.now(),
      actionLabel: actionLabel,
      name: name,
      path: path,
      bytesBefore: bytesBefore,
      bytesAfter: bytesAfter,
    );
    _storeHistory();
    return item;
  }

  void _rememberJob(_Job job, {String? path}) {
    final output = job.output;
    if (output == null || job.historyId != null) return;
    job.historyId = _remember(
      actionLabel: job.actionLabel ?? '',
      name: output.name,
      path: path,
      bytesBefore: job.bytesBefore,
      bytesAfter: output.size,
    ).id;
  }

  /// Moves a saved result to the Trash. True if it went.
  Future<bool> _undo(HistoryItem item) async {
    final path = item.path;
    if (path == null || item.undoneAt != null) return false;
    try {
      await widget.trashResult(path, item.bytesAfter);
    } on EngineFailed catch (error) {
      _sayOnTop(failureText(_words, error));
      return false;
    } catch (error) {
      debugPrint('Undo failed: $error');
      _sayOnTop(_words.undoFailed);
      return false;
    }
    _history.markUndone(item.id, DateTime.now());
    await _storeHistory();
    if (!mounted) return true;
    setState(() {
      for (final job in _jobs) {
        if (job.historyId == item.id) job.undone = true;
      }
    });
    _sayOnTop(_words.movedTo(trashName(_words)));
    return true;
  }

  Future<void> _reveal(HistoryItem item) async {
    final path = item.path;
    if (path == null) return;
    try {
      await widget.revealResult(path);
    } on EngineFailed catch (error) {
      _sayOnTop(failureText(_words, error));
    } catch (error) {
      debugPrint('Showing a file failed: $error');
      _sayOnTop(_words.showFailed);
    }
  }

  /// Says something over whichever screen is showing, as history opens above this one.
  void _sayOnTop(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openHistory() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => HistoryScreen(
          log: _history,
          onClear: () async {
            _history.clear();
            setState(() {
              for (final job in _jobs) {
                job.historyId = null;
              }
            });
            await _storeHistory();
          },
          onUndo: _undoAvailable ? _undo : null,
          onShow: _undoAvailable ? _reveal : null,
        ),
      ),
    );
  }

  /// What the Shift-drag menu offers: Convert, or Tools with Alt (Option on a Mac) held as well. It
  /// has room for few slices, and a drag can't stop to ask questions, so actions that ask first are
  /// left out.
  Future<List<RadialAction>> _menuFor(List<String> paths, ActionMode mode) async {
    // Switching to Tools mid-drag asks again about the same file, which keeps its trials.
    final same = _draggedFor(paths);
    _dragged = null;
    final List<PickedFile> files;
    try {
      files = joinArchiveParts(
        (await _readDrop([for (final path in paths) DropItemFile(path)])).files,
      );
    } catch (_) {
      return const [];
    }
    final kinds = [for (final file in files) detectKind(file.head, fileName: file.name)];
    // One file only, as the menu's centre has room for one size.
    if (files.length == 1) {
      _dragged =
          same ??
          (
            paths: List.unmodifiable(paths),
            file: files.single,
            previews: SizePreviews(
              files.single,
              kinds.single,
              _trial,
              readMedia: widget.mediaProbe,
            ),
          );
    }
    return _learned(
      availableActions(
        kinds,
        mode,
        mediaAvailable: _mediaAvailable,
        mediaOutputs: mediaOutputsHere(),
      ),
    ).where((action) => !needsOptions(action)).take(_shiftDragSlices).toList();
  }

  /// A slice was chosen outside the window, so results go straight beside the originals. A choice
  /// from the outer ring comes with its options.
  Future<void> _chosenFromShiftDrag(
    RadialAction action,
    List<String> paths,
    ActionOptions options,
  ) async {
    final dragged = _draggedFor(paths);
    _dragged = null;
    final List<PickedFile> files;
    if (dragged != null) {
      // Read moments ago for the menu, and the same file keeps the trial its slice made.
      files = [dragged.file];
    } else {
      try {
        files = (await _readDrop([for (final path in paths) DropItemFile(path)])).files;
      } catch (_) {
        showAppWindow();
        if (mounted) _say(_words.openFailed);
        return;
      }
    }
    if (!mounted) return;
    _open(files);
    // Opening the menu again offers the same kind of actions.
    setState(() => _tab = _tabOf(action));
    if (dragged != null) _previews = dragged.previews;
    await _start(action, options, saveBeside: true);
  }

  /// What the Shift-drag menu's centre says while resting on a slice, or null if it can't tell.
  Future<String?> _sizeInShiftDrag(RadialAction action, List<String> paths) async {
    final guess = await _draggedFor(paths)?.previews.guess(action);
    return guess?.describe(deviceWords);
  }

  ({List<String> paths, PickedFile file, SizePreviews previews})? _draggedFor(List<String> paths) {
    final dragged = _dragged;
    return dragged != null && listEquals(dragged.paths, paths) ? dragged : null;
  }

  /// The folder chosen in Settings for results, if there is one and it can take them. Otherwise
  /// null, for beside each original, and a folder that's gone or locked is said once.
  Future<String?> _resultsFolder() async {
    if (!_savesBeside) return null;
    final chosen = SettingsScope.read(context)?.value.resultsFolder;
    if (chosen == null) return null;
    var usable = false;
    try {
      usable = await widget.folderCheck(chosen);
    } catch (_) {
      // Treated as unusable.
    }
    if (usable) return chosen;
    if (!_saidFolderGone && mounted) {
      _saidFolderGone = true;
      _say(_words.resultsFolderGone(chosen));
    }
    return null;
  }

  /// Saves results held in memory next to what they came from, or into [folder]. Video is
  /// already there.
  Future<List<_Result>> _saveBeside(List<_Result> results, String? folder) async {
    final saved = <_Result>[];
    for (final result in results) {
      final inMemory = result.output.inMemory;
      final original = result.from.path;
      if (inMemory == null || original == null) {
        saved.add(result);
        continue;
      }
      final path = await saveBesideOriginal(original, inMemory, folder: folder);
      saved.add(_Result(_savedAt(result.output, path), result.from, result.bytesBefore));
    }
    return saved;
  }

  /// Each archive's files written into one folder beside it, named after it, with the archive's own
  /// folders inside. The folder is then the result: shown, dragged on, or undone as one.
  Future<List<_Result>> _extractToFolders(List<_Result> results, String? folder) async {
    final byArchive = LinkedHashMap<PickedFile, List<_Result>>.identity();
    for (final result in results) {
      (byArchive[result.from] ??= []).add(result);
    }
    final folders = <_Result>[];
    for (final MapEntry(key: archive, value: extracted) in byArchive.entries) {
      final files = [for (final result in extracted) result.output.inMemory!];
      final stem = splitFileName(archive.name).stem;
      final path = await saveFolderBesideOriginal(
        archive.path!,
        '${stem.endsWith('.tar') ? stem.substring(0, stem.length - 4) : stem} (extracted)',
        files,
        folder: folder,
      );
      final size = files.fold<int>(0, (sum, file) => sum + file.bytes.length);
      folders.add(
        _Result(ConvertedFile(name: p.basename(path), size: size, savedPath: path), archive, null),
      );
    }
    return folders;
  }

  ConvertedFile _savedAt(ConvertedFile output, String path) {
    return ConvertedFile(
      name: output.name,
      size: output.size,
      inMemory: output.inMemory,
      savedPath: path,
      note: output.note,
    );
  }

  void _shared(SharedFiles shared) {
    if (!mounted) return;
    setState(() => _receiving = shared.receiving);
    if (shared.receiving) return;
    _open(shared.files);
    if (shared.failed > 0) {
      _say(shared.files.isEmpty ? _words.sharedNothing : _words.sharedSome);
    }
  }

  Words get _words => context.words;

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pick() async {
    final List<PickedFile> files;
    try {
      files = await widget.pickFiles();
    } catch (error) {
      debugPrint('Choosing files failed: $error');
      if (mounted) _say(_words.openFailed);
      return;
    }
    if (mounted) _open(files);
  }

  /// What a drop opens. Files from folders are narrowed to those that can go together.
  Future<({List<PickedFile> files, int leftOut, DroppedFiles dropped})> _readDrop(
    List<DropItem> items,
  ) async {
    final dropped = await widget.dropReader(items);
    final inFolders = dropped.inFolders;
    final kept = pickFromFolder([
      for (final file in inFolders) detectKind(file.head, fileName: file.name),
    ], canUse: _canUse);
    return (
      files: [...dropped.loose, for (final i in kept) inFolders[i]],
      leftOut: inFolders.length - kept.length,
      dropped: dropped,
    );
  }

  bool _canUse(FileKind kind) {
    return ActionMode.values.any((mode) {
      return availableActions(
        [kind],
        mode,
        mediaAvailable: _mediaAvailable,
        mediaOutputs: mediaOutputsHere(),
      ).isNotEmpty;
    });
  }

  /// Files dropped on the window, which then behave as if they had been chosen.
  Future<void> _dropped(List<DropItem> items) async {
    final ({List<PickedFile> files, int leftOut, DroppedFiles dropped}) read;
    try {
      read = await _readDrop(items);
    } catch (_) {
      if (mounted) _say(_words.openFailed);
      return;
    }
    if (!mounted) return;
    if (read.files.isEmpty) {
      if (read.dropped.folders > 0) _say(_words.folderNothing);
      return;
    }
    _open(read.files);
    if (read.dropped.tooMany) {
      _say(_words.folderTooMany(maxFolderFiles));
    } else if (read.leftOut > 0) {
      _say(_words.folderLeftOut(read.leftOut));
    }
  }

  void _open(List<PickedFile> chosen) {
    if (chosen.isEmpty) return;
    final files = joinArchiveParts(chosen);
    _stopRunningJob();
    _looks.clear();
    setState(() {
      _files = files;
      _kinds = [for (final file in files) detectKind(file.head, fileName: file.name)];
      _menuOpen = true;
      _jobs = const [];
    });
  }

  /// A failure message, or null if these files can be read into memory.
  String? _tooLarge() {
    var total = 0;
    for (final file in _files) {
      if (file.size > maxInMemoryBytes) {
        return _words.fileTooLarge(file.name, formatBytes(maxInMemoryBytes));
      }
      total += file.size;
    }
    if (total <= maxInMemoryBytes) return null;
    return _words.filesTooLarge(formatBytes(maxInMemoryBytes));
  }

  void _stopRunningJob() {
    _control?.cancel?.call();
    _control = null;
  }

  void _cancel() {
    _stopRunningJob();
    setState(() {
      _jobs = const [];
      _menuOpen = true;
    });
  }

  /// True if these are worked on whole in memory, rather than piece by piece as video is.
  bool _inMemory(RadialAction action, List<FileKind> kinds) {
    return kinds.every((kind) {
      return canRunPdf(action, kind) ||
          canRunPortably(action, kind) ||
          canRunUnpacked(action, kind) ||
          canRunDecoded(action, kind);
    });
  }

  /// Runs each file alone unless the action combines them. So one damaged file costs only itself,
  /// joining [failed], and only one file is held in memory on its way in.
  Future<List<_Result>> _run(
    RadialAction action,
    List<PickedFile> files,
    List<FileKind> kinds,
    void Function(double) onProgress,
    ConvertControl control,
    ActionOptions options, {
    required List<_Job> failed,
    required bool Function() wanted,
    required bool outsideTheWindow,
  }) async {
    if (_inMemory(action, kinds)) {
      final tooLarge = _tooLarge();
      if (tooLarge != null) throw EngineFailed(tooLarge);
    }

    // Files in a batch often share a password, so one that worked is tried on the next before
    // asking. It lasts only as long as this job.
    String? remembered;
    Future<List<_Result>> unlocking(
      List<PickedFile> some,
      List<FileKind> theirKinds,
      void Function(double) progress,
    ) async {
      var current = remembered == null ? options : options.withPassword(remembered!);
      var typedOne = false;
      while (true) {
        try {
          final results = await _runTogether(action, some, theirKinds, progress, control, current);
          final password = current.password;
          if (password != null && mounted) _lookInsideUnlocked(some, theirKinds, password);
          return results;
        } on PasswordNeeded catch (needed) {
          if (!wanted()) throw const JobCancelled();
          if (outsideTheWindow) showAppWindow();
          if (!mounted) rethrow;
          final password = await askForPassword(context, needed.fileName, wrong: typedOne);
          if (password == null) rethrow;
          if (!wanted()) throw const JobCancelled();
          typedOne = true;
          remembered = password;
          current = options.withPassword(password);
        }
      }
    }

    if (files.length == 1 || combinesFiles(action)) {
      return unlocking(files, kinds, onProgress);
    }
    _Job failure(PickedFile file, String message, FileKind kind, EngineFailed? error) {
      return _Job(file.name, null)
        ..state = FileChipState.failed
        ..message = message
        ..details = _failureDetails(action, [kind], error);
    }

    final results = <_Result>[];
    for (var i = 0; i < files.length; i++) {
      if (!wanted()) throw const JobCancelled();
      try {
        results.addAll(
          await unlocking(
            [files[i]],
            [kinds[i]],
            (progress) => onProgress((i + progress) / files.length),
          ),
        );
      } on JobCancelled {
        rethrow;
      } on EngineFailed catch (error) {
        failed.add(failure(files[i], failureText(deviceWords, error), kinds[i], error));
      } catch (_) {
        failed.add(failure(files[i], deviceWords.convertFailed, kinds[i], null));
      }
    }
    return results;
  }

  /// Pictures and subtitles in memory, or video and audio piece by piece.
  Future<List<_Result>> _runTogether(
    RadialAction action,
    List<PickedFile> files,
    List<FileKind> kinds,
    void Function(double) onProgress,
    ConvertControl control,
    ActionOptions options,
  ) async {
    final before = files.fold<int>(0, (sum, file) => sum + file.size);
    List<_Result> matched(List<ConvertedFile> outputs) {
      return [
        for (var i = 0; i < outputs.length; i++)
          outputs.length == files.length
              ? _Result(outputs[i], files[i], files[i].size)
              : _Result(outputs[i], files.first, outputs.length < files.length ? before : null),
      ];
    }

    List<_Result> portable(List<PortableFile> outputs) {
      return matched([
        for (final output in outputs)
          ConvertedFile(name: output.name, size: output.bytes.length, inMemory: output),
      ]);
    }

    final isPdf = kinds.every((kind) => canRunPdf(action, kind));
    if (!_inMemory(action, kinds)) {
      return matched(
        await widget.mediaConverter(action, files, kinds, onProgress, control, options),
      );
    }
    // The menu may have tried this already, to show its size.
    // Trials run with no options, so a ring's choice or a password needs its own run.
    final tried = files.length == 1 && identical(options, const ActionOptions())
        ? _previews?.take(action, files.single)
        : null;
    if (tried != null) return portable(await tried);
    final List<PortableFile> inputs;
    try {
      inputs = [
        for (var i = 0; i < files.length; i++)
          PortableFile(files[i].name, await switch (kinds[i]) {
            FileKind.heic => widget.photoDecoder(files[i]),
            FileKind.sevenZip || FileKind.rar => _unpack(files[i]),
            _ => files[i].read(),
          }),
      ];
    } on EngineFailed {
      rethrow;
    } catch (_) {
      throw EngineFailed(deviceWords.readFailed);
    }
    if (isPdf) {
      final results = await widget.pdfConverter(action, inputs, onProgress, options);
      return matched([
        for (final result in results)
          ConvertedFile(
            name: result.file.name,
            size: result.file.bytes.length,
            inMemory: result.file,
            note: result.note,
          ),
      ]);
    }
    return portable(await widget.converter(action, inputs, onProgress, options));
  }

  /// The menu's trials for one file, made again when another file is chosen. Only one file, as
  /// the centre has room for one size.
  SizePreviews? get _sizePreviews {
    if (_files.length != 1) return _previews = null;
    final current = _previews;
    if (current != null && identical(current.file, _files.single)) return current;
    return _previews = SizePreviews(
      _files.single,
      _kinds.single,
      _trial,
      readMedia: widget.mediaProbe,
    );
  }

  Future<List<PortableFile>> _trial(RadialAction action, List<PortableFile> files) {
    return widget.converter(action, files, (_) {}, const ActionOptions());
  }

  /// Asks anything the action needs to know, then starts it.
  Future<void> _choose(RadialAction action) async {
    if (!await _putInOrder(action)) return;
    if (!needsOptions(action)) {
      await _start(action, const ActionOptions());
      return;
    }
    await _askThenStart(action);
  }

  /// A ring's choice, as Scanned document's Under 200 KB: its options are complete, but files
  /// that go together are still put in order first.
  Future<void> _chooseWith(RadialAction action, ActionOptions options) async {
    if (!await _putInOrder(action)) return;
    await _start(action, options);
  }

  /// Pages or clips go one after another, so their order is asked first. False if that was
  /// cancelled. From a Shift-drag there's no screen to ask on, and they go in the order dragged.
  Future<bool> _putInOrder(RadialAction action) async {
    if (keepsOrder(action) && _files.length > 1) {
      final files = _files;
      final kinds = _kinds;
      final order = await askForOrder(
        context,
        action: action,
        files: files,
        kinds: kinds,
        picture: _showPreviews
            ? (i) => PreviewThumb(preview: _lookAt(files[i], kinds[i]), kind: kinds[i], size: 44)
            : null,
      );
      if (order == null || !mounted) return false;
      setState(() {
        _files = [for (final i in order) _files[i]];
        _kinds = [for (final i in order) _kinds[i]];
      });
    }
    return true;
  }

  Future<void> _askThenStart(RadialAction action) async {
    if (action.id == 'image-crop' || action.id == 'image-form') {
      final tooLarge = _tooLarge();
      if (tooLarge != null) {
        _say(tooLarge);
        return;
      }
    }
    final file = _files.first;
    final kind = _kinds.first;
    final options = await askForOptions(
      context,
      action,
      loadPicture: () => _pictureToShow(file, kind),
      loadPresets: widget.presetLoader,
      fileCount: _files.length,
      openPdfPages: kind == FileKind.pdf
          ? () async => PdfPagePictures.open(await file.read(), file.name)
          : null,
      trimPreview: TrimPreview(
        seconds: () async => (await widget.mediaProbe(file)).seconds,
        frameAt: kind.family == FileFamily.video
            ? (seconds) => widget.frameReader(file, seconds)
            : null,
      ),
    );
    if (options != null && mounted) await _start(action, options);
  }

  /// The picture as something the screen can draw, with its pixels where the engine will see them.
  Future<Uint8List> _pictureToShow(PickedFile file, FileKind kind) async {
    if (kind == FileKind.heic) return widget.photoDecoder(file);
    final bytes = await file.read();
    if (kind != FileKind.tiff) return bytes;
    final png = await widget.converter(
      actionById('image-to-png')!,
      [PortableFile(file.name, bytes)],
      (_) {},
      const ActionOptions(),
    );
    return png.single.bytes;
  }

  Future<void> _start(RadialAction action, ActionOptions options, {bool saveBeside = false}) async {
    final settings = SettingsScope.maybeOf(context);
    _usesAtStart ??= settings?.value.uses;
    if (settings != null && settings.value.learnOrder) {
      unawaited(settings.change((old) => old.usedOnce(action.id)));
    }
    final folder = await _resultsFolder();
    if (!mounted) return;
    final before = _files.fold<int>(0, (sum, file) => sum + file.size);
    final files = _files;
    final kinds = _kinds;
    // On a desktop an archive extracts into a folder beside it, keeping its own folders.
    final toFolders =
        action.id == 'archive-extract' && _savesBeside && files.every((file) => file.path != null);
    if (toFolders) options = ActionOptions(keepFolders: true, password: options.password);
    final jobs = [_Job(_workingName(), before)];
    final control = ConvertControl()..outputFolder = folder;
    _stopRunningJob();
    _control = control;
    setState(() {
      _menuOpen = false;
      _jobs = jobs;
    });
    final job = jobs.single;
    final failed = <_Job>[];
    if (_working++ == 0) unawaited(widget.keepWorking(true));
    try {
      var results = await _run(
        action,
        files,
        kinds,
        (progress) {
          if (mounted && identical(_jobs, jobs)) setState(() => job.progress = progress);
        },
        control,
        options,
        failed: failed,
        wanted: () => mounted && identical(_jobs, jobs),
        outsideTheWindow: saveBeside,
      );
      if (toFolders) {
        results = await _extractToFolders(results, folder);
      } else if (saveBeside) {
        results = await _saveBeside(results, folder);
      }
      if (saveBeside) {
        if (failed.isNotEmpty) showAppWindow();
        // Ready at the cursor to drag straight on, as the window may be behind other apps.
        showChipAtCursor([
          for (final result in results)
            if (result.output.savedPath != null) result.output.savedPath!,
        ]);
      }
      if (!mounted || !identical(_jobs, jobs)) return;
      setState(() {
        _jobs = [
          for (final result in results)
            _Job(result.output.name, result.bytesBefore)
              ..state = FileChipState.done
              ..output = result.output
              ..from = result.from
              ..actionLabel = action.label
              ..saved = result.output.savedPath != null,
          ...failed,
        ];
        for (final done in _jobs) {
          final path = done.output?.savedPath;
          if (path != null) _rememberJob(done, path: path);
        }
      });
    } on JobCancelled {
      // The screen already moved on.
    } on EngineFailed catch (error) {
      if (saveBeside) showAppWindow();
      if (!mounted || !identical(_jobs, jobs)) return;
      setState(() {
        job
          ..state = FileChipState.failed
          ..message = failureText(_words, error)
          ..details = _failureDetails(action, kinds, error);
      });
    } catch (error) {
      if (saveBeside) showAppWindow();
      if (!mounted || !identical(_jobs, jobs)) return;
      setState(() {
        job
          ..state = FileChipState.failed
          ..message = _words.convertFailed
          ..details = _failureDetails(action, kinds, null);
      });
    } finally {
      if (--_working == 0) unawaited(widget.keepWorking(false));
    }
  }

  /// The kind is said only when every file shares it.
  String _failureDetails(RadialAction action, List<FileKind> kinds, EngineFailed? error) {
    return failureDetails(
      appVersion: appVersion,
      platform: platformLabel,
      action: action.label,
      kind: kinds.isNotEmpty && kinds.every((kind) => kind == kinds.first) ? kinds.first : null,
      failure: error,
    );
  }

  Future<void> _copyDetails(String details) async {
    try {
      await Clipboard.setData(ClipboardData(text: details));
    } catch (error) {
      debugPrint('Copying failed: $error');
      return;
    }
    if (mounted) _say(_words.detailsCopied);
  }

  String _workingName() {
    final first = _files.first.name;
    return _files.length == 1 ? first : _words.andMore(first, _files.length - 1);
  }

  Future<void> _save(_Job job) async {
    final output = job.output;
    if (output == null) return;
    final SavedAs? saved;
    try {
      final inMemory = output.inMemory;
      if (inMemory != null) {
        saved = await widget.saveFile(inMemory);
      } else {
        saved = await output.download?.call() == true ? const SavedAs() : null;
      }
    } catch (error) {
      debugPrint('Saving failed: $error');
      if (mounted) _say(_words.saveFailed);
      return;
    }
    if (!mounted || saved == null) return;
    final path = saved.path;
    setState(() {
      job.saved = true;
      _rememberJob(job, path: path);
    });
  }

  /// Results that have no home yet and can be saved with others. Video brings its own way to save.
  List<_Job> get _waitingToSave => [
    for (final job in _jobs)
      if (job.output?.inMemory != null && job.output?.savedPath == null && !job.saved) job,
  ];

  /// Beside the originals where there's a folder to write to. Elsewhere one ZIP, as each file would
  /// otherwise ask where to go.
  Future<void> _saveAll() async {
    final waiting = _waitingToSave;
    setState(() => _savingAll = true);
    try {
      if (_savesBeside) {
        final folder = await _resultsFolder();
        for (final job in waiting) {
          final output = job.output!;
          final path = await saveBesideOriginal(job.from!.path!, output.inMemory!, folder: folder);
          if (!mounted) return;
          setState(() {
            job
              ..output = _savedAt(output, path)
              ..saved = true;
            _rememberJob(job, path: path);
          });
        }
      } else {
        final zip = zipFiles([for (final job in waiting) job.output!.inMemory!]);
        final saved = await widget.saveFile(zip);
        if (!mounted || saved == null) return;
        // One file came of them, so one line, and undoing it must not touch the others.
        _remember(
          actionLabel: waiting.first.actionLabel ?? '',
          name: zip.name,
          path: saved.path,
          bytesAfter: zip.bytes.length,
        );
        setState(() {
          for (final job in waiting) {
            job.saved = true;
          }
        });
      }
    } on EngineFailed catch (error) {
      if (mounted) _say(failureText(_words, error));
    } catch (_) {
      if (mounted) _say(_words.saveAllFailed);
    } finally {
      if (mounted) setState(() => _savingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).textTheme;
    final words = context.words;
    final screen = Scaffold(
      appBar: _buildBar(words),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final centre = _buildCentre(styles, words);
            final side = _buildSide(words);
            final info = _files.isEmpty ? _buildInfo() : null;
            final Widget body;
            if (wide) {
              body = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 290, child: info ?? _buildFileCard(words)),
                  const SizedBox(width: 24),
                  Expanded(child: centre),
                  const SizedBox(width: 24),
                  SizedBox(width: 310, child: side),
                ],
              );
            } else {
              body = Column(
                children: [
                  if (_files.isNotEmpty) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: _buildFileCard(words),
                    ),
                    const SizedBox(height: 16),
                  ],
                  centre,
                  const SizedBox(height: 28),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      children: [
                        side,
                        if (info != null) ...[const SizedBox(height: 16), info],
                      ],
                    ),
                  ),
                ],
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: body,
                ),
              ),
            );
          },
        ),
      ),
    );
    if (!_acceptsDrops) return screen;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        _dropped(details.files);
      },
      child: Stack(fit: StackFit.expand, children: [screen, if (_dragging) _buildDropHint(styles)]),
    );
  }

  PreferredSizeWidget _buildBar(Words words) {
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 860;
    Widget labelled(String label, IconData icon, VoidCallback onPressed) {
      if (narrow) return IconButton(tooltip: label, icon: Icon(icon), onPressed: onPressed);
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(label),
          ),
        ),
      );
    }

    return AppBar(
      toolbarHeight: 64,
      titleSpacing: 20,
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SdLogo(),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'ShiftDrop',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.2),
            ),
          ),
        ],
      ),
      actions: [
        if (width >= 1100) const Center(child: OfflineBadge()),
        labelled(words.history, Icons.history, _openHistory),
        if (SettingsScope.maybeOf(context) != null)
          labelled(
            words.settingsTitle,
            Icons.tune,
            () => openSettings(context, onShowGuide: widget.showGuide),
          ),
        IconButton(
          tooltip: words.help,
          icon: const Icon(Icons.help_outline),
          onPressed: () => openHelp(context),
        ),
        IconButton(
          tooltip: words.about,
          icon: const Icon(Icons.info_outline),
          onPressed: () => showAbout(context),
        ),
        const SizedBox(width: 12),
      ],
      bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
    );
  }

  /// Where Shift-drag works: a desktop app, not a browser.
  bool get _hasShiftDrag =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  /// Before any file: how to use the app from anywhere, and what Make it fit offers.
  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasShiftDrag) ...[const ShiftDragTip(), const SizedBox(height: 16)],
        const FitPanel(),
      ],
    );
  }

  Widget _buildSide(Words words) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_files.isEmpty) ...[
          RecentPanel(
            items: [
              for (final item in _history.items)
                if (item.undoneAt == null) item,
            ].take(4).toList(),
            onOpenHistory: _openHistory,
            onUndo: _undoAvailable ? (item) => _undo(item) : null,
          ),
          const SizedBox(height: 16),
        ] else if (_menuOpen && !_thumbArc) ...[
          _buildKeys(words),
          const SizedBox(height: 16),
        ],
        const PrivacyPanel(),
      ],
    );
  }

  /// The keys that work the dial, while it's open.
  Widget _buildKeys(Words words) {
    final sd = context.sd;
    Widget row(List<String> keys, String what) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Wrap(spacing: 4, children: [for (final key in keys) KeyCap(key)]),
            ),
            Expanded(
              child: Text(what, style: TextStyle(fontSize: 13, color: sd.text2)),
            ),
          ],
        ),
      );
    }

    return SdPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row([words.keyArrows], words.keysChoose),
          row(['Tab'], words.keysRing),
          row(['Enter'], words.keysRun),
          row(['Esc'], words.keysClose),
        ],
      ),
    );
  }

  /// The chosen files: a preview where Settings allow, what they are, and ways to change them.
  Widget _buildFileCard(Words words) {
    return SdPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showPreviews) ...[_buildPreview(), const SizedBox(height: 12)],
          Text(_summary(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.add, size: 18),
            label: Text(words.chooseOtherFiles, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: _working > 0 ? null : _clearFiles, child: Text(words.clearFiles)),
        ],
      ),
    );
  }

  void _clearFiles() {
    setState(() {
      _files = const [];
      _kinds = const [];
      _jobs = const [];
      _menuOpen = false;
      _previewHidden = false;
    });
  }

  /// The centre of the dial before any file: a way to choose some, and where to drop them.
  Widget _buildPickHub(Words words) {
    final sd = context.sd;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: sd.accentSoft, shape: BoxShape.circle),
            child: Icon(Icons.upload_rounded, color: sd.accent),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _pick, child: Text(words.chooseFiles)),
          if (_acceptsDrops) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: 150,
              child: Text(
                words.dropAnywhere,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: sd.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCentre(TextTheme styles, Words words) {
    final sd = context.sd;
    final receiving = [
      if (_receiving) ...[
        const SizedBox(height: 16),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 8),
        Text(words.receiving, textAlign: TextAlign.center),
      ],
    ];
    if (_files.isEmpty) {
      return Column(
        children: [
          Text(
            words.homeTitle,
            textAlign: TextAlign.center,
            style: styles.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.4),
          ),
          const SizedBox(height: 6),
          Text(
            words.homeSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: sd.muted, fontSize: 15),
          ),
          const SizedBox(height: 22),
          IdleDial(centre: _buildPickHub(words)),
          ...receiving,
          const SizedBox(height: 22),
          const FamilyChips(),
        ],
      );
    }
    final tabs = _tabs;
    return Column(
      children: [
        ...receiving,
        if (tabs.length > 1) ...[
          ModeTabs<_Tab>(
            tabs: [for (final tab in tabs) (tab, _tabLabel(words, tab))],
            selected: _shownTab,
            isFit: (tab) => tab == _Tab.fit,
            onSelected: (tab) {
              setState(() {
                _tab = tab;
                _menuOpen = true;
                _jobs = const [];
              });
            },
          ),
          const SizedBox(height: 16),
        ],
        if (_menuOpen) _buildMenu(styles),
        if (_menuOpen && _jobs.isNotEmpty) const SizedBox(height: 16),
        for (final job in _jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Center(child: _buildChip(job)),
          ),
        if (_waitingToSave.length > 1)
          Center(
            child: FilledButton.icon(
              onPressed: _savingAll ? null : _saveAll,
              icon: const Icon(Icons.save_alt),
              label: Text(_saveAllLabel(words)),
            ),
          ),
        if (!_menuOpen)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _menuOpen = true),
              icon: const Icon(Icons.refresh),
              label: Text(words.openMenuAgain),
            ),
          ),
      ],
    );
  }

  Widget _buildPreview() {
    if (_previewHidden) {
      return Center(
        child: TextButton.icon(
          onPressed: () => setState(() => _previewHidden = false),
          icon: const Icon(Icons.visibility_outlined),
          label: Text(_words.previewShow),
        ),
      );
    }
    final file = _files.first;
    final kind = _kinds.first;
    final result = _firstResult;
    final resultKind = result?.output == null
        ? kind
        : PreviewSubject.ofResult(result!.output!)?.kind ?? kind;
    return PreviewPanel(
      key: ValueKey((file, result)),
      before: _lookAt(file, kind),
      after: result == null ? null : _lookAtResult(result),
      kind: kind,
      afterKind: resultKind,
      name: file.name,
      // Smaller while the menu is open, so the menu still fits a small window.
      height: _menuOpen ? 120 : 180,
      onHide: () => setState(() => _previewHidden = true),
      onEnlarge: () => showPreviewLarge(
        context,
        name: result?.output?.name ?? file.name,
        kind: resultKind,
        before: _lookAt(file, kind, width: 1600),
        after: result == null ? null : _lookAtResult(result, width: 1600),
      ),
    );
  }

  String _saveAllLabel(Words words) {
    if (!_savesBeside) return words.saveAllZip;
    final folder = SettingsScope.maybeOf(context)?.value.resultsFolder;
    return folder == null ? words.saveAllBeside : words.saveAllTo(p.basename(folder));
  }

  /// Where a saved result went, when that's the folder chosen in Settings rather than beside its
  /// original.
  String? _savedInFolder(_Job job) {
    final saved = job.output?.savedPath;
    final original = job.from?.path;
    if (saved == null || original == null || p.dirname(saved) == p.dirname(original)) return null;
    return p.basename(p.dirname(saved));
  }

  Widget _buildDropHint(TextTheme styles) {
    final sd = context.sd;
    return IgnorePointer(
      child: ColoredBox(
        color: sd.bg.withValues(alpha: 0.92),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            decoration: BoxDecoration(
              color: sd.accentSoft,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: sd.accent, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.file_download_outlined, size: 40, color: sd.accent),
                const SizedBox(height: 12),
                Text(_words.dropToConvert, style: styles.headlineSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _summary() {
    final total = _files.fold<int>(0, (sum, file) => sum + file.size);
    final names = _files.length == 1 ? _files.first.name : _words.fileCount(_files.length);
    return '$names · ${formatBytes(total)}';
  }

  String _tabLabel(Words words, _Tab tab) => switch (tab) {
    _Tab.convert => words.modeConvert,
    _Tab.fit => words.modeFit,
    _Tab.tools => words.modeTools,
  };

  _Tab _tabOf(RadialAction action) {
    if (action.mode == ActionMode.tools) return _Tab.tools;
    return action.isFit ? _Tab.fit : _Tab.convert;
  }

  /// The menu behind [_tab]: Convert and Tools as their own menus, with Make it fit taken out of
  /// Convert into its own.
  ActionMode get _mode => _tab == _Tab.tools ? ActionMode.tools : ActionMode.convert;

  List<RadialAction> _actionsFor(_Tab tab) {
    final all = availableActions(
      _kinds,
      tab == _Tab.tools ? ActionMode.tools : ActionMode.convert,
      mediaAvailable: _mediaAvailable,
      mediaOutputs: mediaOutputsHere(),
    );
    return _learned(switch (tab) {
      _Tab.convert => [
        for (final action in all)
          if (!action.isFit) action,
      ],
      _Tab.fit => [
        for (final action in all)
          if (action.isFit) action,
      ],
      _Tab.tools => all,
    });
  }

  /// How often each action had been used when the app started. The menus order by this, not by
  /// the live count, so slices never move while someone is using them.
  Map<String, int>? _usesAtStart;

  /// [actions] with the most used first, where Settings allow.
  List<RadialAction> _learned(List<RadialAction> actions) {
    final settings = SettingsScope.maybeOf(context)?.value;
    if (settings == null || !settings.learnOrder) return actions;
    return orderByUse(actions, _usesAtStart ??= settings.uses);
  }

  /// The tabs these files have anything in.
  List<_Tab> get _tabs => [
    for (final tab in _Tab.values)
      if (_actionsFor(tab).isNotEmpty) tab,
  ];

  /// The chosen tab, or the first with anything in it when the chosen one is empty for these files.
  _Tab get _shownTab {
    final tabs = _tabs;
    return tabs.isEmpty || tabs.contains(_tab) ? _tab : tabs.first;
  }

  /// The picture in the dial's centre, turned, flipped or resized as the highlighted slice would,
  /// before anything runs. One picture only, and only where previews are on.
  Widget? _centreLook(RadialAction action, ActionOptions options, double side) {
    if (!_showPreviews || _files.length != 1) return null;
    final kind = _kinds.single;
    if (kind.family != FileFamily.image) return null;
    final look = liveLookFor(action, options);
    if (look == null) return null;
    return LiveLookView(preview: _lookAt(_files.single, kind), look: look, size: side);
  }

  /// A phone gets the half dial along the bottom, within reach of a thumb.
  bool get _thumbArc {
    final phone =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return phone && MediaQuery.sizeOf(context).width < 600;
  }

  Widget _buildMenu(TextTheme styles) {
    final tab = _shownTab;
    final actions = _actionsFor(tab);
    if (_thumbArc && actions.isNotEmpty) {
      return ThumbArc(
        key: ValueKey(tab),
        actions: actions,
        fileCount: _files.length,
        sizeOf: _sizePreviews?.guess,
        onSelected: _choose,
        onChoice: _chooseWith,
        onCancelled: () => setState(() => _menuOpen = false),
      );
    }
    return Column(
      children: [
        RadialMenu(
          actions: actions,
          diameter: 400,
          centreLook: _centreLook,
          fileCount: _files.length,
          sizeOf: _sizePreviews?.guess,
          onSelected: _choose,
          // Ring choices are complete options, so nothing is asked first.
          onChoice: _chooseWith,
          onCancelled: () => setState(() => _menuOpen = false),
        ),
        if (actions.isEmpty) ...[
          const SizedBox(height: 12),
          Text(
            notAvailableMessage(_words, _kinds, tab == _Tab.tools ? ActionMode.tools : _mode),
            textAlign: TextAlign.center,
            style: styles.bodyMedium,
          ),
        ],
      ],
    );
  }

  /// Hands a result to another app. Nothing is lost if it fails, so a plain note is enough.
  Future<void> _handOver(ResultHandOver handOver, ConvertedFile output) async {
    try {
      await handOver(output);
    } on EngineFailed catch (error) {
      if (mounted) _say(failureText(_words, error));
    } catch (error) {
      debugPrint('Handing over failed: $error');
      if (mounted) _say(_words.handOverFailed);
    }
  }

  Widget _buildChip(_Job job) {
    final output = job.output;
    final canHandOver =
        !job.undone &&
        output != null &&
        (output.inMemory != null || output.savedPath != null || output.cachedPath != null);
    final remembered = job.historyId == null ? null : _history.find(job.historyId!);
    final canReach = _undoAvailable && !job.undone && remembered?.path != null;
    final note = output?.note;
    final before = job.bytesBefore;
    final look = _showPreviews && _jobs.indexOf(job) < _thumbnailRows
        ? _lookAtResult(job, width: 120)
        : null;
    final sizes = output == null
        ? null
        : '${before == null ? formatBytes(output.size) : _words.sizeChange(formatBytes(before), formatBytes(output.size))}'
              '${note == null ? '' : '\n$note'}';
    return FileChip(
      name: job.name,
      state: job.state,
      progress: job.progress ?? 0,
      indeterminate: job.state == FileChipState.working && job.progress == null,
      detail: job.undone
          ? _words.movedTo(trashName(_words))
          : _savedInFolder(job) != null
          ? _words.savedIn(_savedInFolder(job)!, sizes ?? '')
          : output?.savedPath != null
          ? _words.savedBeside(sizes ?? '')
          : job.saved
          ? _words.saved(sizes ?? '')
          : sizes,
      message: job.message,
      onCopyDetails: job.details == null ? null : () => _copyDetails(job.details!),
      fadeAfter: null,
      onSave: job.undone || output == null || output.savedPath != null ? null : () => _save(job),
      onUndo: canReach ? () => _undo(remembered!) : null,
      onShowInFolder: canReach ? () => _reveal(remembered!) : null,
      onShare: _resultsShare && canHandOver ? () => _handOver(widget.shareResult, output) : null,
      onDragOut: _resultsDrag && canHandOver ? () => _handOver(widget.dragResultOut, output) : null,
      onCancel: job.state == FileChipState.working ? _cancel : null,
      thumbnail: look == null
          ? null
          : PreviewThumb(preview: look, kind: PreviewSubject.ofResult(output!)!.kind),
      kept: output == null || before == null || before <= 0 || output.size >= before
          ? null
          : output.size / before,
    );
  }
}
