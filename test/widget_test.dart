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

  test('Cyberpunk OLED theme token validation', () {
    final theme = appVisualThemeFromKey('cyberpunk-oled');
    expect(theme, equals(AppVisualTheme.cyberpunkOled));

    final palette = AppPalette.fromBrightness(true, visualTheme: theme);
    expect(palette.isCyberpunkOled, isTrue);
    expect(palette.background, equals(const Color(0xff000000)));
    expect(palette.primary, equals(const Color(0xffff0055)));
    expect(palette.secondary, equals(const Color(0xfffcee0a)));
    expect(palette.glow, equals(const Color(0xff00f0ff)));
  });
}
