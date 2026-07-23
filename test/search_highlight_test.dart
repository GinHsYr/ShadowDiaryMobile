import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/diary/diary_search.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings.dart';
import 'package:shadow_diary_mobile/core/theme/app_theme.dart';
import 'package:shadow_diary_mobile/features/search/search_page.dart';

void main() {
  testWidgets('highlights longest safe matches and honors standalone aliases', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(ThemeSeed.neutral),
        home: const Scaffold(
          body: SearchHighlightedText(
            text: 'Apple met A and Alice',
            keywords: [
              SearchHighlightKeyword('A', standalone: true),
              SearchHighlightKeyword('Alice'),
            ],
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(SearchHighlightedText),
        matching: find.byType(RichText),
      ),
    );
    final root = richText.text as TextSpan;
    final highlighted = <String?>[];
    void collectHighlights(InlineSpan span) {
      if (span is! TextSpan) return;
      if (span.style?.backgroundColor != null) highlighted.add(span.text);
      for (final child in span.children ?? const <InlineSpan>[]) {
        collectHighlights(child);
      }
    }

    collectHighlights(root);

    expect(highlighted, ['A', 'Alice']);
    expect(tester.takeException(), isNull);
  });
}
