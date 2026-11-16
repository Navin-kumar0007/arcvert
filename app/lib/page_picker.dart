import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:radial_core/radial_core.dart';

import 'pdf_engine.dart';
import 'theme.dart';
import 'words.dart';

/// Asks which pages to take, as a range such as `1-3, 7`, or returns null if the user changed
/// their mind. [open] gives the PDF to draw the pages from; without it, or if it can't be opened,
/// the pages can still be typed.
Future<String?> askForPages(BuildContext context, {Future<PdfPagePictures> Function()? open}) {
  return showDialog<String>(
    context: context,
    builder: (_) => PagePickerDialog(open: open),
  );
}

class PagePickerDialog extends StatefulWidget {
  const PagePickerDialog({super.key, this.open});

  final Future<PdfPagePictures> Function()? open;

  @override
  State<PagePickerDialog> createState() => _PagePickerDialogState();
}

class _PagePickerDialogState extends State<PagePickerDialog> {
  final _field = TextEditingController();
  PdfPagePictures? _pdf;
  bool _opening = true;
  final _chosen = <int>{};
  final _pictures = <int, Future<Uint8List>>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    _openPdf();
  }

  Future<void> _openPdf() async {
    final open = widget.open;
    PdfPagePictures? pdf;
    if (open != null) {
      try {
        pdf = await open();
      } catch (error) {
        debugPrint('Pages can\'t be shown: $error');
      }
    }
    if (!mounted) {
      await pdf?.close();
      return;
    }
    setState(() {
      _pdf = pdf;
      _opening = false;
    });
  }

  @override
  void dispose() {
    _field.dispose();
    _pdf?.close();
    super.dispose();
  }

  Future<Uint8List> _picture(int number) =>
      _pictures.putIfAbsent(number, () => _pdf!.picture(number, width: 180));

  void _toggle(int number) {
    setState(() {
      if (!_chosen.remove(number)) _chosen.add(number);
      _field.text = formatPageRange(_chosen);
      _error = null;
    });
  }

  void _setAll(bool on) {
    final pdf = _pdf;
    if (pdf == null) return;
    setState(() {
      _chosen.clear();
      if (on) _chosen.addAll([for (var i = 1; i <= pdf.count; i++) i]);
      _field.text = formatPageRange(_chosen);
      _error = null;
    });
  }

  /// Typed pages pick the pictures too, once they make sense.
  void _typed(String text) {
    final pdf = _pdf;
    if (pdf == null) return;
    try {
      final pages = parsePageRange(text, pdf.count);
      setState(() {
        _chosen
          ..clear()
          ..addAll(pages);
        _error = null;
      });
    } on EngineFailed {
      // Half typed: the pictures stay as they were until it reads.
    }
  }

  void _finish() {
    final words = context.words;
    final text = _field.text.trim();
    final pdf = _pdf;
    try {
      // With the PDF at hand, a range it doesn't have is said here. Without it, the job says so.
      if (pdf != null) {
        parsePageRange(text, pdf.count);
      } else if (text.isEmpty) {
        throw Fail.noPagesChosen;
      }
    } on EngineFailed catch (failure) {
      setState(() => _error = failureText(words, failure));
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final words = context.words;
    final sd = context.sd;
    final pdf = _pdf;
    return AlertDialog(
      title: Text(words.choosePages),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_opening)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (pdf == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(words.pagesCantShow, style: TextStyle(color: sd.muted)),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      words.pagesChosen(_chosen.length, pdf.count),
                      style: TextStyle(color: sd.muted),
                    ),
                  ),
                  TextButton(onPressed: () => _setAll(true), child: Text(words.pagesAll)),
                  TextButton(onPressed: () => _setAll(false), child: Text(words.pagesNone)),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 120,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: pdf.count,
                  itemBuilder: (context, index) => _tile(index + 1),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _field,
              decoration: InputDecoration(labelText: words.pagesField, errorText: _error),
              onChanged: _typed,
              onSubmitted: (_) => _finish(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(words.cancel)),
        FilledButton(onPressed: _finish, child: Text(words.extractPagesGo)),
      ],
    );
  }

  Widget _tile(int number) {
    final sd = context.sd;
    final on = _chosen.contains(number);
    return Semantics(
      checked: on,
      button: true,
      label: context.words.pageNumber(number),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _toggle(number),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? sd.accent : sd.line2, width: on ? 3 : 1),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FutureBuilder<Uint8List>(
                      future: _picture(number),
                      builder: (context, made) {
                        final png = made.data;
                        if (png == null) return ColoredBox(color: sd.surface2);
                        return Image.memory(png, fit: BoxFit.contain, gaplessPlayback: true);
                      },
                    ),
                    if (on)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Icon(Icons.check_circle, size: 20, color: sd.accent),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text('$number', style: TextStyle(fontSize: 12, color: sd.text2)),
            ],
          ),
        ),
      ),
    );
  }
}
