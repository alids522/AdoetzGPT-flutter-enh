import 'package:adoetzgpt/main.dart';
import 'package:adoetzgpt/state/app_state.dart';
import 'package:adoetzgpt/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('AdoetzGPT boots', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AdoetzAppState()..initialize(),
        child: const AdoetzGptApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('New dynamic visual themes token validation', () {
    // Synthwave 80s
    final synthwave = appVisualThemeFromKey('synthwave-80s');
    expect(synthwave, equals(AppVisualTheme.synthwave80s));
    final pSynth = AppPalette.fromBrightness(true, visualTheme: synthwave);
    expect(pSynth.isSynthwave80s, isTrue);
    expect(pSynth.primary, equals(const Color(0xffff2a85)));

    // Matrix Phosphor
    final matrix = appVisualThemeFromKey('matrix-phosphor');
    expect(matrix, equals(AppVisualTheme.matrixPhosphor));
    final pMatrix = AppPalette.fromBrightness(true, visualTheme: matrix);
    expect(pMatrix.isMatrixPhosphor, isTrue);
    expect(pMatrix.primary, equals(const Color(0xff00ff66)));

    // Solar Flare
    final solar = appVisualThemeFromKey('solar-flare');
    expect(solar, equals(AppVisualTheme.solarFlare));
    final pSolar = AppPalette.fromBrightness(true, visualTheme: solar);
    expect(pSolar.isSolarFlare, isTrue);
    expect(pSolar.primary, equals(const Color(0xffff5e00)));
  });
}
