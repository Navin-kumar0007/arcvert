import 'package:web/web.dart' as web;

/// What the app ever opens: web pages, and email drafts the person sends themselves.
const openableSchemes = {'https', 'mailto'};

/// Opens a web page in another tab, or an email draft in the email app. Only `https` and `mailto`
/// addresses. With `noopener` the browser gives nothing back, so this can't tell whether a blocker
/// stopped it.
Future<bool> openPage(Uri address) async {
  if (!openableSchemes.contains(address.scheme)) return false;
  if (address.scheme == 'mailto') {
    // In this tab: the email app takes it, and the page stays as it was.
    web.window.location.href = address.toString();
    return true;
  }
  web.window.open(address.toString(), '_blank', 'noopener');
  return true;
}
