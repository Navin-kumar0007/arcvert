import 'package:radial_core/radial_core.dart';
import 'package:test/test.dart';

RadialAction tool(String id) => RadialAction(
  id: id,
  label: id,
  mode: ActionMode.tools,
  engine: Engine.builtIn,
  accepts: const {FileKind.txt},
  suffix: 'edited',
);

List<RadialAction> tools(int count) => [for (var i = 0; i < count; i++) tool('t$i')];

void main() {
  test('nothing makes no pages', () => expect(menuPages(const []), isEmpty));

  test('eight fit on one page, with no More needed', () {
    final pages = menuPages(tools(8));
    expect(pages, hasLength(1));
    expect(pages.single, hasLength(8));
  });

  test('nine make two pages, each leaving a slot for More', () {
    expect(menuPages(tools(9)).map((page) => page.length), [7, 2]);
  });

  test('page boundaries: every page shows More, so none holds over 7', () {
    expect(menuPages(tools(14)).map((page) => page.length), [7, 7]);
    expect(menuPages(tools(15)).map((page) => page.length), [7, 7, 1]);
    expect(menuPages(tools(16)).map((page) => page.length), [7, 7, 2]);
  });

  test('every action appears exactly once, for any count', () {
    for (var count = 0; count < 40; count++) {
      final actions = tools(count);
      final flat = menuPages(actions).expand((page) => page).toList();
      expect(flat.toSet(), actions.toSet(), reason: '$count actions');
      expect(flat, hasLength(count), reason: '$count actions');
    }
  });

  test('no page exceeds 8 slices once More is counted', () {
    for (var count = 1; count < 40; count++) {
      final pages = menuPages(tools(count));
      final more = pages.length > 1 ? 1 : 0;
      for (final page in pages) {
        expect(page.length + more, lessThanOrEqualTo(menuSlots), reason: '$count actions');
      }
    }
  });

  test('a real image: WhatsApp is on the first page', () {
    final actions = actionsFor(const [FileKind.jpg], ActionMode.convert);
    expect(actions.length, greaterThan(menuSlots));
    final first = menuPages(actions).first.map((action) => action.id);
    expect(first, contains('fit-whatsapp-photo'));
    expect(first, contains('image-to-png'));
  });

  test('tools keep their order', () {
    final actions = actionsFor(const [FileKind.jpg], ActionMode.tools);
    expect(menuPages(actions).expand((page) => page), actions);
  });

  test('formats alternate with fits, and leftovers follow', () {
    final actions = actionsFor(const [FileKind.pdf], ActionMode.convert);
    final ids = menuPages(actions).first.map((action) => action.id).toList();
    expect(ids.take(6), [
      'pdf-to-jpg',
      'fit-email-pdf',
      'pdf-to-png',
      'fit-pdf-100kb',
      'pdf-to-docx',
      'fit-pdf-500kb',
    ]);
    expect(ids.skip(6), ['fit-pdf-1mb']);
  });

  test('too few slots is refused', () {
    expect(() => menuPages(tools(3), slots: 1), throwsArgumentError);
  });

  group('orderByUse', () {
    final actions = actionsFor(const [FileKind.jpg], ActionMode.tools);
    List<String> ids(List<RadialAction> list) => [for (final action in list) action.id];

    test('nothing used keeps the usual order', () {
      expect(ids(orderByUse(actions, const {})), ids(actions));
    });

    test('the most used come first, the rest as they were', () {
      final ordered = orderByUse(actions, const {'image-compress': 9, 'image-rotate': 4});
      expect(ids(ordered).take(2), ['image-compress', 'image-rotate']);
      final rest = [
        for (final id in ids(actions))
          if (id != 'image-compress' && id != 'image-rotate') id,
      ];
      expect(ids(ordered).skip(2), rest);
    });

    test('a couple of uses is not yet a habit', () {
      expect(ids(orderByUse(actions, const {'image-flip': 2})), ids(actions));
    });

    test('ties keep the usual order', () {
      final last = actions.last.id;
      final first = actions.first.id;
      final ordered = orderByUse(actions, {last: 5, first: 5});
      expect(ids(ordered).take(2), [first, last]);
    });

    test('nothing is lost or repeated', () {
      final ordered = orderByUse(actions, {for (final action in actions) action.id: 3});
      expect(ids(ordered).toSet(), ids(actions).toSet());
      expect(ordered, hasLength(actions.length));
    });
  });
}
