import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:radial_core/radial_core.dart';

import 'app_settings.dart';
import 'open_page.dart';
import 'option_screens.dart' show FormDialog;
import 'presets.dart';
import 'shift_drag.dart';
import 'update_check.dart';
import 'home_parts.dart' show triggerKeyName;
import 'theme.dart';
import 'words.dart';
import 'menu_speed.dart';

/// Opens Settings over the current screen.
Future<void> openSettings(BuildContext context, {VoidCallback? onShowGuide}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => SettingsScreen(onShowGuide: onShowGuide),
    ),
  );
}

/// Every choice the app has, in one place. Each is saved as soon as it changes.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.onShowGuide,
    this.desktop,
    this.updateWay,
    this.chooseFolder = _chooseFolder,
    this.loadPresets = loadBundledPresets,
  });

  /// Opens the first-launch guide again, after Settings closes.
  final VoidCallback? onShowGuide;

  /// Whether this is a Mac or Windows, with folders to save into and a login to open at. Null
  /// asks the platform.
  final bool? desktop;
  final UpdateWay? updateWay;
  final Future<String?> Function() chooseFolder;

  /// The form presets a new slice can be filled in from.
  final Future<List<Preset>> Function() loadPresets;

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    final settings = SettingsScope.maybeOf(context);
    final isDesktop =
        desktop ??
        (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.windows));
    final updates = updateWay ?? updateWayHere;
    return Scaffold(
      appBar: AppBar(title: Text(words.settingsTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (settings != null) ...[
                  if (isDesktop) ResultsFolderChoice(settings: settings, choose: chooseFolder),
                  ThemeChoice(settings: settings),
                  LanguageChoice(settings: settings),
                  const SizedBox(height: 8),
                  PreviewsSwitch(settings: settings),
                  LearnOrderSwitch(settings: settings),
                  MyFitsList(settings: settings, loadPresets: loadPresets),
                ],
                if (isDesktop && settings != null) TriggerKeyChoice(settings: settings),
                if (isDesktop) const OpenAtLogin(),
                if (settings != null && updates == UpdateWay.check)
                  UpdateChecks(settings: settings),
                if (updates == UpdateWay.page) const GetNewest(),
                if (onShowGuide != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.school_outlined),
                    title: Text(words.showGuide),
                    onTap: () {
                      Navigator.of(context).pop();
                      onShowGuide!();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> _chooseFolder() => FilePicker.getDirectoryPath();

/// A heading and its choices, as each setting is laid out.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child, this.below});

  final String label;
  final Widget child;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
          ?below,
        ],
      ),
    );
  }
}

/// Where results go on a desktop: beside each original, or one folder chosen here. A folder
/// that's gone is still shown, and results go beside the originals until it's back or changed.
class ResultsFolderChoice extends StatelessWidget {
  const ResultsFolderChoice({super.key, required this.settings, required this.choose});

  final SettingsStore settings;
  final Future<String?> Function() choose;

  Future<void> _pick() async {
    final String? folder;
    try {
      folder = await choose();
    } catch (error) {
      debugPrint('Choosing a folder failed: $error');
      return;
    }
    if (folder == null || folder.isEmpty) return;
    await settings.change((old) => old.copyWith(resultsFolder: () => folder));
  }

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    return ValueListenableBuilder(
      valueListenable: settings,
      builder: (context, value, _) {
        final folder = value.resultsFolder;
        return _Labelled(
          label: words.resultsWhere,
          below: folder == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          folder,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          semanticsLabel: words.resultsFolderIs(p.basename(folder)),
                        ),
                      ),
                      TextButton(onPressed: _pick, child: Text(words.resultsChange)),
                    ],
                  ),
                ),
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(words.resultsBeside)),
              ButtonSegment(value: true, label: Text(words.resultsInFolder)),
            ],
            selected: {folder != null},
            onSelectionChanged: (chosen) {
              if (chosen.single) {
                _pick();
              } else {
                settings.change((old) => old.copyWith(resultsFolder: () => null));
              }
            },
          ),
        );
      },
    );
  }
}

/// Light, dark, or as the system is: three cards, each with a small picture of the dial in it.
class ThemeChoice extends StatelessWidget {
  const ThemeChoice({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    return ValueListenableBuilder(
      valueListenable: settings,
      builder: (context, value, _) => _Labelled(
        label: words.theme,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              ('system', words.themeSystem, [SdColors.light, SdColors.dark]),
              ('light', words.themeLight, [SdColors.light]),
              ('dark', words.themeDark, [SdColors.dark]),
            ];
            return Row(
              children: [
                for (final (id, label, looks) in cards) ...[
                  if (id != 'system') const SizedBox(width: 10),
                  Expanded(
                    child: _ThemeCard(
                      label: label,
                      looks: looks,
                      selected: value.theme == id,
                      onTap: () => settings.change((old) => old.copyWith(theme: id)),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.label,
    required this.looks,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final List<SdColors> looks;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sd = context.sd;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: sd.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? sd.accent : sd.line, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 64,
                      child: Row(
                        children: [
                          for (final look in looks)
                            Expanded(
                              child: ColoredBox(
                                color: look.bg,
                                child: Center(
                                  child: CustomPaint(
                                    size: const Size.square(38),
                                    painter: _MiniDial(look),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (selected) Icon(Icons.check_circle, size: 18, color: sd.accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniDial extends CustomPainter {
  const _MiniDial(this.look);

  final SdColors look;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = look.surface2;
    canvas.drawCircle(centre, radius, ring);
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -1.5708,
      1.0472,
      false,
      ring..color = look.amber,
    );
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -0.5236,
      1.0472,
      false,
      ring..color = look.accent,
    );
  }

  @override
  bool shouldRepaint(_MiniDial oldDelegate) => oldDelegate.look != look;
}

/// The switch for showing a small picture of each file and result.
class PreviewsSwitch extends StatelessWidget {
  const PreviewsSwitch({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    return ValueListenableBuilder(
      valueListenable: settings,
      builder: (context, value, _) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(words.showPreviews),
        subtitle: Text(words.showPreviewsWhy),
        value: value.showPreviews,
        onChanged: (on) => settings.change((old) => old.copyWith(showPreviews: on)),
      ),
    );
  }
}

/// The app's language: the device's, or one chosen here.
class LanguageChoice extends StatelessWidget {
  const LanguageChoice({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    return ValueListenableBuilder(
      valueListenable: settings,
      builder: (context, value, _) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(words.language, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: '', label: Text(words.languageDevice)),
                // Each language named in itself, so it can be found whatever is showing.
                const ButtonSegment(value: 'en', label: Text('English')),
                const ButtonSegment(
                  value: 'hi',
                  label: Text('\u0939\u093f\u0928\u094d\u0926\u0940'),
                ),
              ],
              selected: {value.language ?? ''},
              onSelectionChanged: (chosen) {
                final language = chosen.single;
                settings.change(
                  (old) => old.copyWith(language: () => language.isEmpty ? null : language),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The switch for the daily check for a newer version, on copies downloaded from the website.
class UpdateChecks extends StatelessWidget {
  const UpdateChecks({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    return ValueListenableBuilder(
      valueListenable: settings,
      builder: (context, value, _) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(words.checkUpdates),
        subtitle: Text(words.checkUpdatesWhy),
        value: value.checkForUpdates,
        onChanged: (on) => settings.change((old) => old.copyWith(checkForUpdates: on)),
      ),
    );
  }
}

/// Where the app can't check by itself, a way to the download page in the browser.
class GetNewest extends StatelessWidget {
  const GetNewest({super.key, this.open = openPage});

  final Future<bool> Function(Uri address) open;

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.system_update_alt),
      title: Text(words.getNewest),
      subtitle: Text(words.getNewestWhy),
      onTap: () async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (!await open(releasesPage)) {
          messenger?.showSnackBar(
            SnackBar(content: Text(words.pageFailed(releasesPage.toString()))),
          );
        }
      },
    );
  }
}

/// The switch for opening at login, shown only where the app can do it.
class OpenAtLogin extends StatefulWidget {
  const OpenAtLogin({super.key, this.read = loginItem, this.write = setLoginItem});

  final Future<LoginItem> Function() read;
  final Future<LoginItem> Function(bool on) write;

  @override
  State<OpenAtLogin> createState() => _OpenAtLoginState();
}

class _OpenAtLoginState extends State<OpenAtLogin> {
  LoginItem _state = LoginItem.unsupported;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.read().then((state) {
      if (mounted) setState(() => _state = state);
    });
  }

  Future<void> _set(bool on) async {
    setState(() => _busy = true);
    final state = await widget.write(on);
    if (mounted) {
      setState(() {
        _state = state;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == LoginItem.unsupported) return const SizedBox.shrink();
    final words = context.words;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(words.openAtLogin),
        subtitle: Text(
          _state == LoginItem.needsApproval ? words.openAtLoginApprove : words.openAtLoginWhy,
        ),
        value: _state != LoginItem.off,
        onChanged: _busy ? null : _set,
      ),
    );
  }
}

/// Whether the menus put the most-used actions first, and a way to forget what was learned.
class LearnOrderSwitch extends StatelessWidget {
  const LearnOrderSwitch({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    return ValueListenableBuilder(
      valueListenable: settings,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(words.learnOrder),
            subtitle: Text(words.learnOrderWhy),
            value: value.learnOrder,
            onChanged: (on) => settings.change((old) => old.copyWith(learnOrder: on)),
          ),
          if (value.uses.isNotEmpty)
            TextButton(
              onPressed: () async {
                await settings.change((old) => old.copyWith(uses: const {}));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(words.learnOrderForgotten)));
                }
              },
              child: Text(words.learnOrderForget),
            ),
        ],
      ),
    );
  }
}

/// Which key, held while dragging from another app, opens the menu: Shift, or Control if Shift
/// already means something in the apps someone drags from.
class TriggerKeyChoice extends StatelessWidget {
  const TriggerKeyChoice({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    return ValueListenableBuilder(
      valueListenable: settings,
      builder: (context, value, _) => _Labelled(
        label: words.triggerKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final key in const ['shift', 'control'])
                  ButtonSegment(value: key, label: Text(triggerKeyName(key))),
              ],
              selected: {value.triggerKey},
              onSelectionChanged: (chosen) =>
                  settings.change((old) => old.copyWith(triggerKey: chosen.single)),
            ),
            const SizedBox(height: 6),
            Text(words.triggerKeyWhy, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            ValueListenableBuilder(
              valueListenable: MenuSpeed.instance,
              builder: (context, _, _) {
                final speed = MenuSpeed.instance.summary;
                return Text(
                  speed == null
                      ? words.menuSpeedNone(triggerKeyName(value.triggerKey))
                      : words.menuSpeed(speed.usual, speed.slowest, speed.count),
                  key: const ValueKey('menu speed'),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The Make it fit slices the user made: each to change or delete, and a way to add one without
/// a file, as well as from Form photo.
class MyFitsList extends StatelessWidget {
  const MyFitsList({super.key, required this.settings, this.loadPresets});

  final SettingsStore settings;
  final Future<List<Preset>> Function()? loadPresets;

  Future<void> _edit(BuildContext context, MyFit? fit) {
    return showDialog<FormTarget>(
      context: context,
      builder: (_) => FormDialog(
        loadPresets: loadPresets,
        myFits: settings.value.myFits,
        sliceOnly: true,
        editing: fit,
        onKeep: (kept) => settings.change((old) => old.keepMyFit(kept)),
      ),
    );
  }

  Future<void> _delete(BuildContext context, MyFit fit) async {
    final words = context.words;
    final messenger = ScaffoldMessenger.of(context);
    final before = settings.value;
    final at = before.myFits.indexOf(fit);
    final count = before.uses[fit.id];
    await settings.change((old) => old.forgetMyFit(fit.id));
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(words.sliceDeleted(fit.name)),
        persist: false,
        action: SnackBarAction(
          label: words.undo,
          onPressed: () => settings.change((now) {
            if (now.myFits.any((kept) => kept.id == fit.id)) return now;
            final fits = [...now.myFits]..insert(at.clamp(0, now.myFits.length), fit);
            return now.copyWith(
              myFits: List.unmodifiable(fits),
              uses: count == null ? null : {...now.uses, fit.id: count},
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    final styles = Theme.of(context).textTheme;
    return ValueListenableBuilder(
      valueListenable: settings,
      builder: (context, value, _) => _Labelled(
        label: words.yourSlices,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              words.yourSlicesWhy,
              style: styles.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            for (final fit in value.myFits)
              ListTile(
                key: ValueKey(fit.id),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: Text(fit.name),
                subtitle: Text(mySliceSummary(words, fit.form)),
                onTap: () => _edit(context, fit),
                trailing: IconButton(
                  tooltip: words.deleteSlice,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(context, fit),
                ),
              ),
            if (value.myFits.length < MyFit.most)
              TextButton.icon(
                onPressed: () => _edit(context, null),
                icon: const Icon(Icons.add),
                label: Text(words.addSlice),
              )
            else
              Text(words.slicesFull(MyFit.most), style: styles.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// What a slice makes, in a few words: `200 x 230 px, 20-50 KB, signature`.
String mySliceSummary(Words words, FormTarget form) {
  final width = form.width;
  final height = form.height;
  final atLeast = form.minBytes == null ? null : formMinKb(form.minBytes!);
  final atMost = form.maxBytes == null ? null : formMaxKb(form.maxBytes!);
  final parts = [
    if (width != null && height != null) '$width x $height px',
    if (atLeast != null && atMost != null)
      '$atLeast-$atMost KB'
    else if (atMost != null)
      words.sliceUpToKb(atMost)
    else if (atLeast != null)
      words.sliceAtLeastKb(atLeast),
    if (form.signature) words.sliceSignature,
  ];
  return parts.isEmpty ? words.sliceAnySize : parts.join(', ');
}
