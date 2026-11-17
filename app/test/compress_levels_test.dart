import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radial_core/radial_core.dart';
import 'package:arcvert/pdf_engine.dart';
import 'package:arcvert/words.dart';

void main() {
  test('PDF Compress: best quality redraws sharper, smallest goes straight to light steps', () {
    final medium = compressSteps(null);
    final high = compressSteps(CompressLevel.high);
    final small = compressSteps(CompressLevel.small);
    expect(high.first.$1, greaterThan(medium.first.$1));
    expect(high.first.$2, greaterThan(medium.first.$2));
    expect(small.first.$1, lessThan(medium.first.$1));
    expect(small.last, medium.last, reason: 'never lower than the lowest readable step');
  });

  test('the levels have words in every language the app speaks', () {
    for (final locale in const [Locale('en'), Locale('hi')]) {
      final words = wordsFor(locale);
      for (final choice in ringChoices(actionById('image-compress')!)) {
        final label = ringChoiceLabel(words, choice);
        expect(label, isNotEmpty);
        if (locale.languageCode == 'hi') expect(label, isNot(choice.label));
      }
    }
  });
}
