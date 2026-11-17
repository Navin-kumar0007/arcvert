import 'shared_files.dart';

/// Browsers aren't offered files by other apps.
Stream<SharedFiles> listenForSharedFiles() => const Stream.empty();

/// Nor do they open files from a right-click menu.
Stream<List<String>> listenForOpenedFiles() => const Stream.empty();
