import 'package:radial_core/radial_core.dart';
import 'package:test/test.dart';

void main() {
  test('reads pages and ranges as people type them', () {
    expect(parsePageRange('1-3, 7', 10), [1, 2, 3, 7]);
    expect(parsePageRange(' 2 ,4-5 ', 10), [2, 4, 5]);
    expect(parsePageRange('9', 9), [9]);
  });

  test('keeps the order given, each page once, and reads a range backwards', () {
    expect(parsePageRange('5, 1-2, 2', 6), [5, 1, 2]);
    expect(parsePageRange('4-2', 6), [4, 3, 2]);
  });

  test('says what is wrong, in words that can be translated', () {
    Matcher fails(String key) => throwsA(isA<EngineFailed>().having((e) => e.key, 'key', key));
    expect(() => parsePageRange('', 5), fails('noPagesChosen'));
    expect(() => parsePageRange(' , ', 5), fails('noPagesChosen'));
    expect(() => parsePageRange('1-', 5), fails('badPageRange'));
    expect(() => parsePageRange('a', 5), fails('badPageRange'));
    expect(() => parsePageRange('0', 5), fails('pageOutOfRange'));
    expect(() => parsePageRange('2-6', 5), fails('pageOutOfRange'));
  });

  test('writes pages back with runs joined, and reads its own writing', () {
    expect(formatPageRange([7, 1, 2, 3]), '1-3, 7');
    expect(formatPageRange([4]), '4');
    expect(formatPageRange([]), '');
    expect(parsePageRange(formatPageRange([1, 2, 5, 6, 9]), 9), [1, 2, 5, 6, 9]);
  });
}
