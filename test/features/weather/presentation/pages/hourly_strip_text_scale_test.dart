import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clarity/features/weather/presentation/widgets/clay_weather_icon.dart';

/// A structural stand-in for the hourly strip: the same content shape (label,
/// icon, temperature) in a horizontally scrolling row.
///
/// [fixedHeight] reproduces the shipped bug — a horizontal viewport with a
/// hardcoded height, whose padding eats into the space left for the cards.
/// That clipped the labels at large accessibility text scales and rendered a
/// "BOTTOM OVERFLOWED BY 14 PIXELS" stripe on the weather page.
///
/// The real strip lives inside pages needing Firebase, blocs and network, so
/// this pins the layout property rather than the widget.
class _HourlyStripHarness extends StatelessWidget {
  const _HourlyStripHarness({this.fixedHeight});

  final double? fixedHeight;

  static const _padding = EdgeInsets.symmetric(horizontal: 24, vertical: 26);

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 8; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          const SizedBox(width: 88, child: _HourlyCard()),
        ],
      ],
    );

    if (fixedHeight != null) {
      // Buggy shape: padding sits inside the fixed height, so the cards get
      // fixedHeight minus 52 no matter how large the text is.
      return SizedBox(
        height: fixedHeight,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: _padding,
          children: [IntrinsicHeight(child: row)],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: _padding,
      child: IntrinsicHeight(child: row),
    );
  }
}

class _HourlyCard extends StatelessWidget {
  const _HourlyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('12 PM',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          SizedBox(height: 12),
          ClayWeatherIcon(condition: 'Clear Sky', size: 44),
          SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('38°',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

Future<void> _pumpAt(WidgetTester tester, double textScale, {double? fixedHeight}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: _HourlyStripHarness(fixedHeight: fixedHeight)),
          ),
        ),
      ),
    ),
  );
}

/// Height the cards actually get, i.e. the strip minus its vertical padding.
double _cardHeight(WidgetTester tester) =>
    tester.getSize(find.byType(IntrinsicHeight)).height;

void main() {
  group('hourly strip sizing', () {
    // Android offers up to 2.0x in accessibility settings.
    testWidgets('cards grow with the text scale', (tester) async {
      await _pumpAt(tester, 1.0);
      final base = _cardHeight(tester);

      await _pumpAt(tester, 2.0);
      final scaled = _cardHeight(tester);

      expect(scaled, greaterThan(base),
          reason: 'cards that do not grow with text are cards that clip');
    });

    testWidgets('growth is proportionate, not merely nonzero', (tester) async {
      await _pumpAt(tester, 1.0);
      final base = _cardHeight(tester);

      await _pumpAt(tester, 1.5);
      final scaled = _cardHeight(tester);

      // The two labels (15sp + 18sp) gain roughly half their height at 1.5x;
      // the 44px icon and 56px of padding do not move. ~20px is the floor
      // below which the labels start getting clipped.
      expect(scaled - base, greaterThan(15),
          reason: 'grew by only ${scaled - base}px at 1.5x — too little to '
              'clear the enlarged labels');
    });

    testWidgets('a fixed-height viewport is what regressed, and is detectable',
        (tester) async {
      // Guards the guard: proves these assertions fail against the shipped bug
      // rather than passing vacuously.
      await _pumpAt(tester, 1.0, fixedHeight: 204);
      final base = _cardHeight(tester);

      await _pumpAt(tester, 2.0, fixedHeight: 204);
      final scaled = _cardHeight(tester);

      expect(scaled, equals(base),
          reason: 'the buggy shape should be frozen at 204 - 52 regardless of '
              'text scale; if this ever changes, the other tests here are no '
              'longer testing what they claim');
    });
  });
}
