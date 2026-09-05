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

    // Nordic Frost (Professional Calm)
    final nordic = appVisualThemeFromKey('nordic-frost');
    expect(nordic, equals(AppVisualTheme.nordicFrost));
    final pNordic = AppPalette.fromBrightness(true, visualTheme: nordic);
    expect(pNordic.isNordicFrost, isTrue);
    expect(pNordic.primary, equals(const Color(0xff38bdf8)));

    // Obsidian Slate (Professional Strong Dark)
    final obsidian = appVisualThemeFromKey('obsidian-slate');
    expect(obsidian, equals(AppVisualTheme.obsidianSlate));
    final pObsidian = AppPalette.fromBrightness(true, visualTheme: obsidian);
    expect(pObsidian.isObsidianSlate, isTrue);
    expect(pObsidian.primary, equals(const Color(0xff94a3b8)));

    // Tokyo Executive (Professional Sapphire & Champagne)
    final tokyo = appVisualThemeFromKey('tokyo-executive');
    expect(tokyo, equals(AppVisualTheme.tokyoExecutive));
    final pTokyo = AppPalette.fromBrightness(true, visualTheme: tokyo);
    expect(pTokyo.isTokyoExecutive, isTrue);
    expect(pTokyo.primary, equals(const Color(0xff2563eb)));
  });

  test('Voice personas list count and default', () {
    const expectedVoices = [
      'Zephyr',
      'Puck',
      'Charon',
      'Kore',
      'Fenrir',
      'Leda',
      'Orus',
      'Aoede',
      'Callirrhoe',
      'Autonoe',
      'Enceladus',
      'Iapetus',
      'Umbriel',
      'Algieba',
      'Despina',
      'Erinome',
      'Algenib',
      'Rasalgethi',
      'Laomedeia',
      'Achernar',
      'Alnilam',
      'Schedar',
      'Gacrux',
      'Pulcherrima',
      'Achird',
      'Zubenelgenubi',
      'Vindemiatrix',
      'Sadachbia',
      'Sadaltager',
      'Sulafat',
    ];
    expect(expectedVoices.length, equals(30));
    expect(expectedVoices.contains('Zephyr'), isTrue);
    expect(expectedVoices.contains('Sulafat'), isTrue);
    expect(expectedVoices.contains('Sadaltager'), isTrue);
  });
}
