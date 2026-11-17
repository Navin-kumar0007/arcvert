import 'action_options.dart';
import 'actions.dart';
import 'file_kind.dart';
import 'preset.dart';

/// A Make it fit slice someone made for themselves: a form's sizes kept under a name of their own,
/// such as "College form". It sits first in Make it fit and in the Shift-drag menu, and runs as
/// Form photo with those sizes, so a drop makes the JPEG the form wants without asking anything.
class MyFit {
  const MyFit({required this.id, required this.name, required this.form});

  /// Starts with [myFitPrefix] and is never used again for another slice, as the learned order
  /// counts uses by id.
  final String id;
  final String name;
  final FormTarget form;

  /// The most kept, so the menus and the settings file stay small.
  static const most = 12;

  /// The longest name, which still fits a slice.
  static const longestName = 30;

  MyFit copyWith({String? name, FormTarget? form}) =>
      MyFit(id: id, name: name ?? this.name, form: form ?? this.form);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (form.width != null) 'width': form.width,
    if (form.height != null) 'height': form.height,
    if (form.minBytes != null) 'minBytes': form.minBytes,
    if (form.maxBytes != null) 'maxBytes': form.maxBytes,
    if (form.signature) 'signature': true,
  };

  /// The slice [toJson] wrote, or null if it is damaged in any way.
  static MyFit? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || !isMyFitId(id) || name is! String) return null;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > longestName) return null;
    int? positive(String key) {
      final value = json[key];
      return value is int && value > 0 ? value : null;
    }

    final width = positive('width');
    final height = positive('height');
    final minBytes = positive('minBytes');
    final maxBytes = positive('maxBytes');
    // Pixel sizes come as a pair, and the smallest size can't be over the largest.
    if ((width == null) != (height == null)) return null;
    if (minBytes != null && maxBytes != null && minBytes > maxBytes) return null;
    return MyFit(
      id: id,
      name: trimmed,
      form: FormTarget(
        width: width,
        height: height,
        minBytes: minBytes,
        maxBytes: maxBytes,
        signature: json['signature'] == true,
      ),
    );
  }

  /// The slice in the menus.
  MyFitAction get action => MyFitAction(this);

  /// The same, as a preset Form photo can fill its boxes from.
  Preset get asPreset => Preset(
    id: id,
    labels: {'en': name},
    accepts: const ['image/*'],
    output: PresetOutput(
      format: FileKind.jpg,
      width: form.width,
      height: form.height,
      minBytes: form.minBytes,
      maxBytes: form.maxBytes,
      signature: form.signature,
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is MyFit &&
      other.id == id &&
      other.name == name &&
      other.form.width == form.width &&
      other.form.height == form.height &&
      other.form.minBytes == form.minBytes &&
      other.form.maxBytes == form.maxBytes &&
      other.form.signature == form.signature;

  @override
  int get hashCode =>
      Object.hash(id, name, form.width, form.height, form.minBytes, form.maxBytes, form.signature);
}

const myFitPrefix = 'my-fit-';

bool isMyFitId(String id) => RegExp(r'^my-fit-[a-z0-9]+$').hasMatch(id);

/// An id no slice has had, from the time it was made. [taken] are the ids in use now.
String newMyFitId(Iterable<String> taken, {DateTime? now}) {
  var stamp = (now ?? DateTime.now()).microsecondsSinceEpoch;
  final used = taken.toSet();
  while (used.contains('$myFitPrefix${stamp.toRadixString(36)}')) {
    stamp++;
  }
  return '$myFitPrefix${stamp.toRadixString(36)}';
}

/// The word in brackets in a result's name, from the slice's name: `photo (college form).jpg`.
/// Leaves out what file names can't hold.
String myFitSuffix(String name) {
  final cleaned = name
      .toLowerCase()
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f()\[\]]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final cut = cleaned.length > MyFit.longestName
      ? cleaned.substring(0, MyFit.longestName).trim()
      : cleaned;
  // "converted" is what plain format changes say, and a dot at the end confuses Windows.
  final suffix = cut.replaceAll(RegExp(r'[.\s]+$'), '');
  return suffix.isEmpty || suffix == 'converted' ? 'form' : suffix;
}

/// A [MyFit] as a slice. Engines only know the catalogue, so it runs as Form photo
/// ([runsAs]).
class MyFitAction extends RadialAction {
  MyFitAction(this.fit)
    : super(
        id: fit.id,
        label: fit.name,
        mode: ActionMode.convert,
        engine: Engine.builtIn,
        accepts: _formPhoto.accepts,
        suffix: myFitSuffix(fit.name),
        output: FileKind.jpg,
        maxBytes: fit.form.maxBytes,
      );

  final MyFit fit;

  // Its name is the user's, so it never counts as a plain format change.
  @override
  bool get isFormatChange => false;

  @override
  bool operator ==(Object other) => other is MyFitAction && other.fit == fit;

  @override
  int get hashCode => fit.hashCode;
}

final RadialAction _formPhoto = actionById('image-form')!;

/// What the engines are given for [action]: the catalogue's own actions as they are, and a slice
/// someone made as Form photo with its sizes and its name for the result.
({RadialAction action, ActionOptions options}) runsAs(RadialAction action, ActionOptions options) {
  if (action is! MyFitAction) return (action: action, options: options);
  return (
    action: _formPhoto,
    options: ActionOptions(form: action.fit.form, crop: options.crop, nameSuffix: action.suffix),
  );
}

/// The slices in [fits] for these files, in the order they were made: only pictures, and only on
/// the Shift menu.
List<RadialAction> myFitsFor(Iterable<FileKind> kinds, ActionMode mode, Iterable<MyFit> fits) {
  final files = kinds.toList();
  if (mode != ActionMode.convert || files.isEmpty) return const [];
  if (!files.every(_formPhoto.accepts.contains)) return const [];
  return [for (final fit in fits) fit.action];
}
