import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:wheel_slider/wheel_slider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../l10n/app_localizations.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '👋 ${l10n.homeGreeting}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          const HomeCalendar(),
        ],
      ),
    );
  }
}

/// The home-page month calendar.
///
/// [diaryDates] is intentionally date-only input so the widget can be wired to
/// the diary repository without exposing database rows to the presentation
/// layer. Duplicate dates count as one completed writing day.
class HomeCalendar extends StatefulWidget {
  const HomeCalendar({
    this.diaryDates = const <DateTime>[],
    this.initialDate,
    super.key,
  });

  final Iterable<DateTime> diaryDates;
  final DateTime? initialDate;

  @override
  State<HomeCalendar> createState() => _HomeCalendarState();
}

class _HomeCalendarState extends State<HomeCalendar> {
  late final DateTime _today;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late Set<int> _diaryDayKeys;

  @override
  void initState() {
    super.initState();
    _today = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
    _focusedDay = _today;
    _selectedDay = _today;
    _diaryDayKeys = _toDayKeys(widget.diaryDates);
  }

  @override
  void didUpdateWidget(HomeCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _diaryDayKeys = _toDayKeys(widget.diaryDates);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final daysInMonth = _daysInMonth(_focusedDay);
    final writtenDays = _writtenDaysInMonth(_focusedDay);
    final progress = writtenDays / daysInMonth;

    return Card(
      key: const Key('home-calendar-card'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CalendarHeader(
              monthLabel: MaterialLocalizations.of(
                context,
              ).formatMonthYear(_focusedDay),
              onPreviousMonth: () => _changeMonth(-1),
              onNextMonth: () => _changeMonth(1),
              onChooseMonth: _showMonthYearPicker,
            ),
            const SizedBox(height: AppSpacing.xs),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  key: const Key('calendar-shortcuts'),
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Row(
                      key: const Key('calendar-shortcut-row'),
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ShortcutButton(
                          label: l10n.calendarToday,
                          onPressed: () => _selectDay(_today),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _ShortcutButton(
                          label: l10n.calendarYesterday,
                          onPressed: () => _selectDay(
                            _today.subtract(const Duration(days: 1)),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _ShortcutButton(
                          label: l10n.calendarLastWeekSameDay,
                          onPressed: () => _selectDay(
                            _today.subtract(const Duration(days: 7)),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _ShortcutButton(
                          label: l10n.calendarLastMonthSameDay,
                          onPressed: () =>
                              _selectDay(_sameDayLastMonth(_today)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            TableCalendar<bool>(
              key: const Key('home-month-calendar'),
              locale: locale,
              firstDay: DateTime(1970),
              lastDay: DateTime(2100, 12, 31),
              focusedDay: _focusedDay,
              currentDay: _today,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              eventLoader: (day) =>
                  _hasDiary(day) ? const <bool>[true] : const <bool>[],
              headerVisible: false,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              calendarFormat: CalendarFormat.month,
              rowHeight: 36,
              daysOfWeekHeight: 28,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              availableGestures: AvailableGestures.horizontalSwipe,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = DateUtils.dateOnly(selectedDay);
                  _focusedDay = DateUtils.dateOnly(focusedDay);
                });
              },
              onPageChanged: (focusedDay) {
                setState(() => _focusedDay = DateUtils.dateOnly(focusedDay));
              },
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: theme.textTheme.labelLarge!.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
                weekendStyle: theme.textTheme.labelLarge!.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: true,
                cellMargin: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 1,
                ),
                defaultTextStyle: theme.textTheme.bodyMedium!,
                weekendTextStyle: theme.textTheme.bodyMedium!,
                outsideTextStyle: theme.textTheme.bodyMedium!.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.28),
                ),
                selectedTextStyle: theme.textTheme.bodyMedium!.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
                selectedDecoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                todayTextStyle: theme.textTheme.bodyMedium!.copyWith(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
                todayDecoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                markerDecoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                markersAlignment: Alignment.bottomCenter,
                markerMargin: const EdgeInsets.only(top: 1),
                markerSize: 4,
              ),
            ),
            const Divider(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                _LegendItem(
                  marker: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  label: l10n.calendarHasDiary,
                ),
                _LegendItem(
                  marker: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  label: l10n.calendarToday,
                ),
              ],
            ),
            const Divider(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.calendarMonthlyProgress,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  key: const Key('calendar-progress-percent'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              key: const Key('calendar-progress'),
              value: progress,
              minHeight: 7,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: colors.primary == Colors.black
                  ? (theme.brightness == Brightness.dark
                        ? const Color(0xFF555555)
                        : const Color(0xFFD7D7D7))
                  : colors.surfaceContainerHighest,
              color: colors.primary,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.calendarWrittenDays(writtenDays, daysInMonth),
              key: const Key('calendar-written-days'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + offset, 1);
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = DateUtils.dateOnly(day);
      _focusedDay = _selectedDay;
    });
  }

  Future<void> _showMonthYearPicker() async {
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => _MonthYearWheelDialog(initialDate: _focusedDay),
    );
    if (selected != null && mounted) {
      _selectDay(selected);
    }
  }

  bool _hasDiary(DateTime day) => _diaryDayKeys.contains(_dayKey(day));

  int _writtenDaysInMonth(DateTime month) {
    return _diaryDayKeys.where((key) {
      final year = key ~/ 10000;
      final monthNumber = (key % 10000) ~/ 100;
      return year == month.year && monthNumber == month.month;
    }).length;
  }

  static Set<int> _toDayKeys(Iterable<DateTime> dates) {
    return dates.map(_dayKey).toSet();
  }

  static int _dayKey(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  static int _daysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  static DateTime _sameDayLastMonth(DateTime date) {
    final previousMonth = DateTime(date.year, date.month - 1);
    final day = date.day.clamp(1, _daysInMonth(previousMonth));
    return DateTime(previousMonth.year, previousMonth.month, day);
  }
}

class _MonthYearWheelDialog extends StatefulWidget {
  const _MonthYearWheelDialog({required this.initialDate});

  static const firstYear = 1970;
  static const lastYear = 2100;

  final DateTime initialDate;

  @override
  State<_MonthYearWheelDialog> createState() => _MonthYearWheelDialogState();
}

class _MonthYearWheelDialogState extends State<_MonthYearWheelDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year;
    _month = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final selectedStyle = theme.textTheme.titleMedium?.copyWith(
      color: colors.primary,
      fontWeight: FontWeight.w800,
    );
    final unselectedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return Dialog(
      key: const Key('calendar-month-year-picker'),
      backgroundColor: colors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.calendarSelectMonth,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _WheelSliderField(
                      key: const Key('calendar-year-wheel-field'),
                      label: l10n.calendarYear,
                      child: WheelSlider.number(
                        key: const Key('calendar-year-wheel'),
                        totalCount: _MonthYearWheelDialog.lastYear,
                        initValue: _year,
                        currentIndex: _year,
                        onValueChanged: (value) {
                          final nextYear = (value as num).round();
                          if (nextYear < _MonthYearWheelDialog.firstYear ||
                              nextYear > _MonthYearWheelDialog.lastYear) {
                            return;
                          }
                          setState(() => _year = nextYear);
                        },
                        horizontal: false,
                        verticalListHeight: 220,
                        verticalListWidth: double.infinity,
                        listWidth: 112,
                        itemSize: 48,
                        perspective: 0.003,
                        squeeze: 0.9,
                        isInfinite: false,
                        isVibrate: false,
                        enableAnimation: false,
                        scrollPhysics: const FixedExtentScrollPhysics(),
                        selectedNumberStyle: selectedStyle,
                        unSelectedNumberStyle: unselectedStyle,
                        showPointer: true,
                        customPointer: _WheelSelectionIndicator(
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _WheelSliderField(
                      key: const Key('calendar-month-wheel-field'),
                      label: l10n.calendarMonth,
                      // WheelSlider.number always starts at zero. Custom
                      // numbered children keep the valid month range at 1–12.
                      child: WheelSlider.customWidget(
                        key: const Key('calendar-month-wheel'),
                        totalCount: 12,
                        initValue: _month - 1,
                        onValueChanged: (value) {
                          final nextMonth = (value as num).round() + 1;
                          setState(() => _month = nextMonth);
                        },
                        horizontal: false,
                        verticalListHeight: 220,
                        verticalListWidth: double.infinity,
                        listWidth: 112,
                        itemSize: 48,
                        perspective: 0.003,
                        squeeze: 0.9,
                        isInfinite: false,
                        isVibrate: false,
                        enableAnimation: false,
                        scrollPhysics: const FixedExtentScrollPhysics(),
                        showPointer: true,
                        customPointer: _WheelSelectionIndicator(
                          color: colors.primary,
                        ),
                        children: [
                          for (var month = 1; month <= 12; month++)
                            Center(
                              child: Text(
                                month.toString(),
                                style: month == _month
                                    ? selectedStyle
                                    : unselectedStyle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                  FilledButton(
                    key: const Key('calendar-month-picker-confirm'),
                    onPressed: () {
                      final lastDay = DateTime(_year, _month + 1, 0).day;
                      Navigator.pop(
                        context,
                        DateTime(
                          _year,
                          _month,
                          widget.initialDate.day.clamp(1, lastDay),
                        ),
                      );
                    },
                    child: Text(
                      MaterialLocalizations.of(context).okButtonLabel,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelSliderField extends StatelessWidget {
  const _WheelSliderField({
    required this.label,
    required this.child,
    super.key,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

class _WheelSelectionIndicator extends StatelessWidget {
  const _WheelSelectionIndicator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.monthLabel,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onChooseMonth,
  });

  final String monthLabel;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onChooseMonth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton(
          key: const Key('calendar-previous-month'),
          onPressed: onPreviousMonth,
          tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Center(
            child: TextButton.icon(
              key: const Key('calendar-month-picker'),
              onPressed: onChooseMonth,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
              label: Text(
                monthLabel,
                key: const Key('calendar-month-label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: const Key('calendar-next-month'),
          onPressed: onNextMonth,
          tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final backgroundColor = theme.brightness == Brightness.dark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFF0F0F0);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: colors.onSurface,
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.marker, required this.label});

  final Widget marker;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 18, height: 18, child: Center(child: marker)),
        const SizedBox(width: AppSpacing.xs),
        Text(label),
      ],
    );
  }
}
