/// Where people report problems and suggest ideas: the project's public issues on GitHub. The app
/// only fills in a new issue and opens it in the browser. The person reads it there and sends it
/// themselves, or doesn't: nothing is ever sent by the app.
library;

const _newIssue = 'https://github.com/Navin-kumar0007/shiftdrop/issues/new';

/// How much of what someone typed goes into the address, as browsers and GitHub limit its length.
const maxReportText = 2000;

/// The facts a report starts with: the app's version, the platform and the language. Never a file
/// name, a folder or anything from a file. English, as whoever fixes the problem reads it.
String reportFacts({
  required String appVersion,
  required String platform,
  required String language,
}) => 'ShiftDrop $appVersion\nPlatform: $platform\nLanguage: $language';

String _cut(String text) {
  final trimmed = text.trim();
  return trimmed.length > maxReportText ? trimmed.substring(0, maxReportText) : trimmed;
}

/// A new problem report, with what the person typed in [what] and the app's facts below it.
Uri problemReport({required String facts, String what = ''}) {
  final described = _cut(what);
  final body = [
    '**What happened**',
    described.isEmpty ? '(Please describe what happened, and what you expected.)' : described,
    '',
    '**About the app**',
    '```',
    facts,
    '```',
  ].join('\n');
  return Uri.parse(
    _newIssue,
  ).replace(queryParameters: {'title': 'Problem: ', 'body': body, 'labels': 'bug'});
}

/// A new idea, with the app's version so it's clear what it was suggested against.
Uri featureIdea({required String appVersion}) {
  final body = [
    '**The idea**',
    '(What would you like ShiftDrop to do, and what is it for?)',
    '',
    'Suggested from ShiftDrop $appVersion.',
  ].join('\n');
  return Uri.parse(
    _newIssue,
  ).replace(queryParameters: {'title': 'Idea: ', 'body': body, 'labels': 'idea'});
}
