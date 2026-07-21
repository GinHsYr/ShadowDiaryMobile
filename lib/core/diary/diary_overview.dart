class DiaryOverview {
  DiaryOverview({
    required Iterable<DateTime> diaryDates,
    required this.diaryCount,
    required this.streakDays,
    required this.characterCount,
  }) : assert(diaryCount >= 0),
       assert(streakDays >= 0),
       assert(characterCount >= 0),
       diaryDates = List<DateTime>.unmodifiable(diaryDates);

  static final empty = DiaryOverview(
    diaryDates: const <DateTime>[],
    diaryCount: 0,
    streakDays: 0,
    characterCount: 0,
  );

  final List<DateTime> diaryDates;
  final int diaryCount;
  final int streakDays;
  final int characterCount;
}

typedef DiaryOverviewSource = ({
  DateTime createdAt,
  String title,
  String plainContent,
});

bool hasWrittenDiaryContent({
  required String title,
  required String plainContent,
}) {
  return title.trim().isNotEmpty || plainContent.trim().isNotEmpty;
}

DiaryOverview calculateDiaryOverview(
  Iterable<DiaryOverviewSource> entries, {
  required DateTime today,
}) {
  final datesByKey = <int, DateTime>{};
  var diaryCount = 0;
  var characterCount = 0;

  for (final entry in entries) {
    if (!hasWrittenDiaryContent(
      title: entry.title,
      plainContent: entry.plainContent,
    )) {
      continue;
    }
    diaryCount++;
    characterCount += entry.plainContent.runes.length;
    final date = DateTime(
      entry.createdAt.year,
      entry.createdAt.month,
      entry.createdAt.day,
    );
    datesByKey[_dayKey(date)] = date;
  }

  final diaryDates = datesByKey.values.toList()..sort();
  var cursor = DateTime(today.year, today.month, today.day);
  if (!datesByKey.containsKey(_dayKey(cursor))) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }

  var streakDays = 0;
  while (datesByKey.containsKey(_dayKey(cursor))) {
    streakDays++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }

  return DiaryOverview(
    diaryDates: diaryDates,
    diaryCount: diaryCount,
    streakDays: streakDays,
    characterCount: characterCount,
  );
}

int _dayKey(DateTime date) {
  return date.year * 10000 + date.month * 100 + date.day;
}
