import 'package:flutter/material.dart';

/// ShiftDrop's own colours, light and dark, beyond what Material's scheme names. Teal is the brand
/// and every "go" action; amber marks Make it fit, as on the app icon. Read with `context.sd`.
@immutable
class SdColors extends ThemeExtension<SdColors> {
  const SdColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.line2,
    required this.text,
    required this.text2,
    required this.muted,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.accentLine,
    required this.accentText,
    required this.amber,
    required this.amberInk,
    required this.amberSoft,
    required this.amberLine,
    required this.amberText,
    required this.badSoft,
    required this.badLine,
    required this.badText,
    required this.track,
    required this.dialFill,
    required this.cardShadow,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color line2;
  final Color text;
  final Color text2;
  final Color muted;
  final Color accent;
  final Color accentInk;
  final Color accentSoft;
  final Color accentLine;
  final Color accentText;

  /// Amber is the same in both themes as a fill; [amberText] is the shade that reads on [bg].
  final Color amber;
  final Color amberInk;
  final Color amberSoft;
  final Color amberLine;
  final Color amberText;
  final Color badSoft;
  final Color badLine;
  final Color badText;

  /// The empty part of a bar.
  final Color track;

  /// The slices of the dial before anything is highlighted.
  final Color dialFill;
  final List<BoxShadow> cardShadow;

  static const dark = SdColors(
    bg: Color(0xFF0D1412),
    surface: Color(0xFF141D1A),
    surface2: Color(0xFF1B2723),
    line: Color(0x12FFFFFF),
    line2: Color(0x21FFFFFF),
    text: Color(0xFFE7EFEB),
    text2: Color(0xFFC3D1CB),
    muted: Color(0xFF9AACA5),
    accent: Color(0xFF34C3A6),
    accentInk: Color(0xFF03231D),
    accentSoft: Color(0x2034C3A6),
    accentLine: Color(0x5234C3A6),
    accentText: Color(0xFF7FE0CB),
    amber: Color(0xFFF4B740),
    amberInk: Color(0xFF2A1C00),
    amberSoft: Color(0x1AF4B740),
    amberLine: Color(0x66F4B740),
    amberText: Color(0xFFF4C76A),
    badSoft: Color(0x14F27A6E),
    badLine: Color(0x57F27A6E),
    badText: Color(0xFFF5B4AC),
    track: Color(0x1FFFFFFF),
    dialFill: Color(0xFF141D1A),
    cardShadow: [],
  );

  static const light = SdColors(
    bg: Color(0xFFF4F7F5),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFE9EFEC),
    line: Color(0x140F1A17),
    line2: Color(0x290F1A17),
    text: Color(0xFF0F1A17),
    text2: Color(0xFF33433D),
    muted: Color(0xFF55665F),
    accent: Color(0xFF0B6E5F),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0x140B6E5F),
    accentLine: Color(0x4D0B6E5F),
    accentText: Color(0xFF0B5A4C),
    amber: Color(0xFFF4B740),
    amberInk: Color(0xFF2A1C00),
    amberSoft: Color(0x29F4B740),
    amberLine: Color(0x73B0780A),
    amberText: Color(0xFF8A5A00),
    badSoft: Color(0x0DC43C2D),
    badLine: Color(0x4DC43C2D),
    badText: Color(0xFF9A2F24),
    track: Color(0x1A0F1A17),
    dialFill: Color(0xFFFFFFFF),
    cardShadow: [BoxShadow(color: Color(0x0F0F1A17), blurRadius: 3, offset: Offset(0, 1))],
  );

  @override
  SdColors copyWith() => this;

  @override
  SdColors lerp(SdColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return SdColors(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surface2: c(surface2, other.surface2),
      line: c(line, other.line),
      line2: c(line2, other.line2),
      text: c(text, other.text),
      text2: c(text2, other.text2),
      muted: c(muted, other.muted),
      accent: c(accent, other.accent),
      accentInk: c(accentInk, other.accentInk),
      accentSoft: c(accentSoft, other.accentSoft),
      accentLine: c(accentLine, other.accentLine),
      accentText: c(accentText, other.accentText),
      amber: c(amber, other.amber),
      amberInk: c(amberInk, other.amberInk),
      amberSoft: c(amberSoft, other.amberSoft),
      amberLine: c(amberLine, other.amberLine),
      amberText: c(amberText, other.amberText),
      badSoft: c(badSoft, other.badSoft),
      badLine: c(badLine, other.badLine),
      badText: c(badText, other.badText),
      track: c(track, other.track),
      dialFill: c(dialFill, other.dialFill),
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}

extension SdColorsOf on BuildContext {
  /// ShiftDrop's colours for the current theme. Falls back by brightness where no theme set them,
  /// as in tests that build a bare MaterialApp.
  SdColors get sd {
    final theme = Theme.of(this);
    return theme.extension<SdColors>() ??
        (theme.brightness == Brightness.light ? SdColors.light : SdColors.dark);
  }
}

/// The app's whole look for one brightness: Material's scheme filled from [SdColors], and every
/// common control shaped to match, so screens that only use Material widgets follow too.
ThemeData shiftDropTheme(Brightness brightness) {
  final sd = brightness == Brightness.dark ? SdColors.dark : SdColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: sd.accent,
    onPrimary: sd.accentInk,
    primaryContainer: sd.accentSoft,
    onPrimaryContainer: sd.accentText,
    secondary: sd.amber,
    onSecondary: sd.amberInk,
    secondaryContainer: sd.amberSoft,
    onSecondaryContainer: sd.amberText,
    tertiary: sd.accentText,
    onTertiary: sd.accentInk,
    error: sd.badText,
    onError: sd.bg,
    errorContainer: sd.badSoft,
    onErrorContainer: sd.badText,
    surface: sd.bg,
    onSurface: sd.text,
    onSurfaceVariant: sd.muted,
    surfaceContainerLowest: sd.bg,
    surfaceContainerLow: sd.surface,
    surfaceContainer: sd.surface,
    surfaceContainerHigh: sd.surface2,
    surfaceContainerHighest: sd.surface2,
    outline: sd.line2,
    outlineVariant: sd.line,
    inverseSurface: sd.text,
    onInverseSurface: sd.bg,
    inversePrimary: sd.accentText,
    shadow: Colors.black,
    scrim: Colors.black,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: 'Inter');
  const radius12 = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)));
  const buttonSize = Size(44, 44);
  return base.copyWith(
    scaffoldBackgroundColor: sd.bg,
    extensions: [sd],
    textTheme: _withHeadings(
      base.textTheme.apply(
        fontFamily: 'Inter',
        fontFamilyFallback: const ['NotoSansDevanagari'],
        bodyColor: sd.text,
        displayColor: sd.text,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: sd.bg,
      foregroundColor: sd.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: DividerThemeData(color: sd.line, space: 1),
    cardTheme: CardThemeData(
      color: sd.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: sd.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        shape: radius12,
        textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: radius12,
        foregroundColor: sd.text,
        side: BorderSide(color: sd.line2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: buttonSize, shape: radius12),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: buttonSize, foregroundColor: sd.text),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: sd.surface,
        foregroundColor: sd.text2,
        selectedBackgroundColor: sd.accent,
        selectedForegroundColor: sd.accentInk,
        side: BorderSide(color: sd.line),
        minimumSize: buttonSize,
        textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? sd.accentInk : sd.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? sd.accent : sd.surface2,
      ),
      trackOutlineColor: WidgetStateProperty.all(sd.line2),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: sd.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: sd.text,
      contentTextStyle: TextStyle(fontFamily: bodyFont, color: sd.bg),
      shape: radius12,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: sd.text, borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(fontFamily: bodyFont, color: sd.bg, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: sd.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: sd.line2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: sd.line2),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: sd.accent,
      linearTrackColor: sd.track,
    ),
    bannerTheme: MaterialBannerThemeData(backgroundColor: sd.surface2),
  );
}

/// Headlines in Space Grotesk, which only has the weight headings use.
TextTheme _withHeadings(TextTheme theme) {
  TextStyle? heading(TextStyle? style) => style?.copyWith(
    fontFamily: headingFont,
    fontFamilyFallback: const ['Inter', 'NotoSansDevanagari'],
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );
  return theme.copyWith(
    displayLarge: heading(theme.displayLarge),
    displayMedium: heading(theme.displayMedium),
    displaySmall: heading(theme.displaySmall),
    headlineLarge: heading(theme.headlineLarge),
    headlineMedium: heading(theme.headlineMedium),
    headlineSmall: heading(theme.headlineSmall),
  );
}

/// For titles and big numbers, such as the size in the middle of the dial.
const headingFont = 'SpaceGrotesk';

/// Everything else. Named wherever a style is built from scratch, as a button's own text style
/// replaces the theme's rather than adding to it.
const bodyFont = 'Inter';

/// Section titles: small, spaced capitals in the muted colour.
class SdSectionTitle extends StatelessWidget {
  const SdSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: context.sd.muted,
      ),
    );
  }
}

/// A rounded panel on the page: the surface colour, a hairline edge, and in light theme a soft
/// shadow.
class SdPanel extends StatelessWidget {
  const SdPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Accent panels pass their soft colour and edge.
  final ({Color fill, Color edge})? tint;

  @override
  Widget build(BuildContext context) {
    final sd = context.sd;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint?.fill ?? sd.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint?.edge ?? sd.line),
        boxShadow: tint == null ? sd.cardShadow : const [],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// The app's mark, drawn: a teal tile with the dial and its amber slice.
class SdLogo extends StatelessWidget {
  const SdLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(size: Size.square(size), painter: const _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 32;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(9 * s)),
      Paint()..color = const Color(0xFF0B6E5F),
    );
    final centre = size.center(Offset.zero);
    final ring = Rect.fromCircle(center: centre, radius: 8 * s);
    Paint stroke(Color colour) => Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s;
    canvas.drawCircle(centre, 8 * s, stroke(Colors.white));
    canvas.drawArc(ring, -1.5708, 1.0472, false, stroke(const Color(0xFFF4B740)));
    canvas.drawCircle(centre, 2.6 * s, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}
