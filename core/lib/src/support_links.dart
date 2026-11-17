/// Where people report problems and suggest ideas: by email to [supportEmail], or as a public
/// issue on GitHub for those who use it. The app only fills in an email draft or a new issue and
/// opens it. The person reads it there and sends it themselves, or doesn't: nothing is ever sent by
/// the app.
library;

/// The address reports and ideas are emailed to, or null until there is one: the app then offers
/// GitHub and copying only. Shown in the app and on the website.
// arcvert.support@gmail.com once the owner has made it (ShiftDrop's address was retired with the name).
const String? supportEmail = null;

const _newIssue = 'https://github.com/Navin-kumar0007/arcvert/issues/new';

/// A `mailto:` address. Spaces must be `%20`: a `+` from form encoding shows as a `+` in many email
/// apps.
Uri _email(String to, String subject, String body) => Uri.parse(
  'mailto:$to?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
);

/// How much of what someone typed goes into the address, as browsers and GitHub limit its length.
const maxReportText = 2000;

/// The facts a report starts with: the app's version, the platform and the language. Never a file
/// name, a folder or anything from a file. English, as whoever fixes the problem reads it.
String reportFacts({
  required String appVersion,
  required String platform,
  required String language,
}) => 'Arcvert $appVersion\nPlatform: $platform\nLanguage: $language';

String _cut(String text) {
  final trimmed = text.trim();
  return trimmed.length > maxReportText ? trimmed.substring(0, maxReportText) : trimmed;
}

String _described(String what) {
  final described = _cut(what);
  return described.isEmpty ? '(Please describe what happened, and what you expected.)' : described;
}

/// A problem report as an email draft to [to], with what the person typed in [what] and the app's
/// facts below it.
Uri problemEmail({required String to, required String facts, String what = ''}) {
  return _email(to, 'Arcvert problem', '${_described(what)}\n\n---\n$facts\n');
}

/// An idea as an email draft to [to].
Uri ideaEmail({required String to, required String appVersion}) {
  return _email(
    to,
    'Arcvert idea',
    '(What would you like Arcvert to do, and what is it for?)\n\n---\nArcvert $appVersion\n',
  );
}

/// A new problem report on GitHub, with what the person typed in [what] and the app's facts below
/// it.
Uri problemReport({required String facts, String what = ''}) {
  final body = [
    '**What happened**',
    _described(what),
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
    '(What would you like Arcvert to do, and what is it for?)',
    '',
    'Suggested from Arcvert $appVersion.',
  ].join('\n');
  return Uri.parse(
    _newIssue,
  ).replace(queryParameters: {'title': 'Idea: ', 'body': body, 'labels': 'idea'});
}
