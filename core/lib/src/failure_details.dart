import 'action_options.dart';
import 'file_kind.dart';

/// What a failed file's "Copy details" puts on the clipboard, ready to paste into a bug report.
///
/// Only facts about the app and the job: never a file's name, its contents, a folder, or what an
/// engine printed, which can hold paths. So a failure's blanks are left out too, as most of them
/// are names. Stays English whatever the app's language, as it is read by whoever fixes the bug.
String failureDetails({
  required String appVersion,
  required String platform,
  required String action,
  FileKind? kind,
  EngineFailed? failure,
}) {
  final kindText = kind == null ? 'unknown' : '${kind.family.name} (${kind.extension})';
  return [
    'Arcvert $appVersion',
    'Platform: $platform',
    'Action: $action',
    'File kind: $kindText',
    'Error: ${failure?.key ?? (failure == null ? 'unexpected' : 'unnamed')}',
  ].join('\n');
}
