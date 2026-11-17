import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:radial_core/radial_core.dart';

import 'about.dart';
import 'app_settings.dart';
import 'home_parts.dart';
import 'open_page.dart';
import 'theme.dart';
import 'words.dart';

/// Where the app is running, which decides the questions and shortcuts that apply.
enum HelpPlace { mac, windows, phone, browser }

HelpPlace get helpPlaceHere {
  if (kIsWeb) return HelpPlace.browser;
  return switch (defaultTargetPlatform) {
    TargetPlatform.macOS => HelpPlace.mac,
    TargetPlatform.windows => HelpPlace.windows,
    _ => HelpPlace.phone,
  };
}

/// The version What's new describes. A test fails if it falls behind `appVersion`, so each release
/// says what it brought.
const whatsNewVersion = '0.16.0';

/// Since 0.10.1, the last release most people had, as 0.13 to 0.15 were never published.
List<String> whatsNew(Words words) => [
  words.whatsNewName,
  words.whatsNewLook,
  words.whatsNewPdfPassword,
  words.whatsNewRarParts,
  words.whatsNewPages,
  words.whatsNewHelp,
];

/// One common question and its answer.
class HelpTopic {
  const HelpTopic(this.question, this.answer);

  final String question;
  final String answer;

  bool matches(String query) {
    final wanted = query.trim().toLowerCase();
    return wanted.isEmpty ||
        question.toLowerCase().contains(wanted) ||
        answer.toLowerCase().contains(wanted);
  }
}

/// The questions that apply in [place], most asked first. [key] is the key held for Shift-drag.
List<HelpTopic> helpTopics(Words words, HelpPlace place, {required String key}) {
  final desktop = place == HelpPlace.mac || place == HelpPlace.windows;
  return [
    HelpTopic(words.faqConvertQ, words.faqConvertA),
    if (desktop) HelpTopic(words.faqShiftDragQ, words.faqShiftDragA(key)),
    if (place == HelpPlace.windows) HelpTopic(words.faqAltShiftQ, words.faqAltShiftA),
    HelpTopic(words.faqWhereQ, desktop ? words.faqWhereDesktopA : words.faqWhereOtherA),
    HelpTopic(words.faqUndoQ, desktop ? words.faqUndoDesktopA : words.faqUndoOtherA),
    HelpTopic(words.faqUploadQ, words.faqUploadA),
    HelpTopic(words.faqFormQ, words.faqFormA),
    HelpTopic(words.faqSlicesQ, words.faqSlicesA),
    HelpTopic(words.faqPdfTextQ, words.faqPdfTextA),
    HelpTopic(words.faqLockedQ, words.faqLockedA),
    HelpTopic(words.faqRarPartsQ, words.faqRarPartsA),
    if (place == HelpPlace.mac) HelpTopic(words.faqMacOpenQ, words.faqMacOpenA),
    if (place == HelpPlace.windows) HelpTopic(words.faqWindowsWarnQ, words.faqWindowsWarnA),
    HelpTopic(words.faqSlowQ, words.faqSlowA),
  ];
}

/// The keys the menus answer to, with what each does. None on a phone, which has no keyboard.
List<(List<String>, String)> helpShortcuts(Words words, HelpPlace place) {
  if (place == HelpPlace.phone) return const [];
  return [
    ([words.keyArrows], words.shortcutMove),
    (['Enter'], words.shortcutRun),
    (['Tab'], words.shortcutChoices),
    (['Esc'], words.shortcutClose),
    if (place == HelpPlace.mac) (['Option'], words.shortcutTools),
    if (place == HelpPlace.windows) (['Alt'], words.shortcutTools),
    ([words.keyArrows], words.shortcutCompare),
  ];
}

Future<void> openHelp(BuildContext context) {
  // A note pointing here has done its job.
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  return Navigator.of(context)
      .push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const HelpScreen()));
}

/// Common questions, shortcuts and support, all on the device. Reporting a problem or suggesting
/// an idea fills in a page on GitHub and opens it in the browser, where the person sends it or
/// doesn't. The app itself never sends anything.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, this.place, this.open = openPage, this.email = supportEmail});

  /// Where the app runs. Null asks the platform.
  final HelpPlace? place;
  final Future<bool> Function(Uri address) open;

  /// Where reports and ideas are emailed, or null to offer GitHub and copying only.
  final String? email;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  HelpPlace get _place => widget.place ?? helpPlaceHere;

  Future<void> _openOrSay(Uri address) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final words = context.words;
    if (!await widget.open(address)) {
      messenger?.showSnackBar(SnackBar(content: Text(words.pageFailed(address.toString()))));
    }
  }

  Future<void> _report() async {
    final facts = reportFacts(
      appVersion: appVersion,
      platform: platformLabel,
      language: Localizations.localeOf(context).languageCode,
    );
    final email = widget.email;
    final choice = await showDialog<_Report>(
      context: context,
      builder: (_) => _ReportDialog(facts: facts, canEmail: email != null),
    );
    if (choice == null || !mounted) return;
    if (choice.way == _Way.email && email != null) {
      await _openOrSay(problemEmail(to: email, facts: facts, what: choice.what));
    } else if (choice.way == _Way.copy) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      final words = context.words;
      final text = [if (choice.what.trim().isNotEmpty) choice.what.trim(), facts].join('\n\n');
      try {
        await Clipboard.setData(ClipboardData(text: text));
      } catch (error) {
        debugPrint('Copying failed: $error');
        return;
      }
      messenger?.showSnackBar(SnackBar(content: Text(words.reportCopied)));
    } else {
      await _openOrSay(problemReport(facts: facts, what: choice.what));
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    final sd = context.sd;
    final key = triggerKeyName(SettingsScope.maybeOf(context)?.value.triggerKey ?? 'shift');
    final query = _search.text;
    final searching = query.trim().isNotEmpty;
    final topics = [
      for (final topic in helpTopics(words, _place, key: key))
        if (topic.matches(query)) topic,
    ];
    final shortcuts = helpShortcuts(words, _place);
    return Scaffold(
      appBar: AppBar(title: Text(words.help)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(words.helpOffline, style: TextStyle(color: sd.muted, fontSize: 13)),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: words.helpSearch,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (!searching) ...[_WhatsNew(words: words), const SizedBox(height: 20)],
                SdSectionTitle(words.helpQuestions),
                const SizedBox(height: 4),
                if (topics.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(words.helpNoMatch(query.trim())),
                  ),
                for (final topic in topics)
                  ExpansionTile(
                    key: ValueKey('${topic.question} $searching'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    expandedAlignment: Alignment.centerLeft,
                    initiallyExpanded: searching,
                    title: Text(topic.question),
                    children: [Text(topic.answer, style: TextStyle(color: sd.text2))],
                  ),
                if (!searching && shortcuts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SdSectionTitle(words.helpShortcuts),
                  const SizedBox(height: 8),
                  for (final (keys, meaning) in shortcuts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: Wrap(spacing: 4, children: [for (final k in keys) KeyCap(k)]),
                          ),
                          Expanded(child: Text(meaning)),
                        ],
                      ),
                    ),
                ],
                if (!searching) ...[
                  const SizedBox(height: 20),
                  SdSectionTitle(words.helpSupport),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bug_report_outlined),
                    title: Text(words.reportProblem),
                    subtitle: Text(words.reportProblemWhy),
                    onTap: _report,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lightbulb_outline),
                    title: Text(words.suggestFeature),
                    subtitle: Text(words.suggestFeatureWhy),
                    onTap: () => _openOrSay(
                      widget.email == null
                          ? featureIdea(appVersion: appVersion)
                          : ideaEmail(to: widget.email!, appVersion: appVersion),
                    ),
                    // Email comes first where there is an address; GitHub stays for those who use it.
                    trailing: widget.email == null
                        ? null
                        : IconButton(
                            tooltip: words.suggestOnGitHub,
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () => _openOrSay(featureIdea(appVersion: appVersion)),
                          ),
                  ),
                  if (widget.email case final email?)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SelectableText(
                        words.writeToUs(email),
                        style: TextStyle(color: sd.muted, fontSize: 13),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WhatsNew extends StatelessWidget {
  const _WhatsNew({required this.words});

  final Words words;

  @override
  Widget build(BuildContext context) {
    final sd = context.sd;
    return SdPanel(
      tint: (fill: sd.accentSoft, edge: sd.accentLine),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            words.whatsNewTitle(whatsNewVersion),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 8),
          for (final line in whatsNew(words))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Icon(Icons.circle, size: 6, color: sd.accent),
                  ),
                  Expanded(child: Text(line)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _Way { email, github, copy }

/// What the person typed in the report dialog, and how they chose to send it.
class _Report {
  const _Report(this.what, this.way);

  final String what;
  final _Way way;
}

/// Asks what happened, and shows exactly what else the report will hold before anything opens.
class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.facts, required this.canEmail});

  final String facts;
  final bool canEmail;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _what = TextEditingController();

  @override
  void dispose() {
    _what.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    final sd = context.sd;
    return AlertDialog(
      title: Text(words.reportProblem),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _what,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                maxLength: maxReportText,
                decoration: InputDecoration(
                  labelText: words.reportWhatHappened,
                  helperText: words.reportHint,
                  helperMaxLines: 3,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(words.reportIncludes, style: TextStyle(color: sd.muted, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sd.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(widget.facts, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(words.cancel)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_Report(_what.text, _Way.copy)),
          child: Text(words.reportCopy),
        ),
        if (widget.canEmail) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(_Report(_what.text, _Way.github)),
            child: Text(words.reportOpen),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_Report(_what.text, _Way.email)),
            child: Text(words.reportEmail),
          ),
        ] else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_Report(_what.text, _Way.github)),
            child: Text(words.reportOpen),
          ),
      ],
    );
  }
}
