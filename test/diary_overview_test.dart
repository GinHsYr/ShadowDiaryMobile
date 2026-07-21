import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/diary/diary_overview.dart';

void main() {
  test('counts an image-only diary without counting image placeholders', () {
    final overview = calculateDiaryOverview([
      (
        createdAt: DateTime(2026, 7, 20),
        title: '',
        plainContent: '\uFFFC\n\uFFFC\n\uFFFC',
      ),
      (
        createdAt: DateTime(2026, 7, 19),
        title: '',
        plainContent: 'A\uFFFC\u{1f642}',
      ),
    ], today: DateTime(2026, 7, 20));

    expect(overview.diaryCount, 2);
    expect(overview.streakDays, 2);
    expect(overview.characterCount, 2);
    expect(overview.diaryDates, [DateTime(2026, 7, 19), DateTime(2026, 7, 20)]);
  });
}
