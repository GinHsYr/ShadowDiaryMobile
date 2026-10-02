import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/app/diary_container_transform.dart';
import 'package:shadow_diary_mobile/features/home/home_page.dart';

void main() {
  testWidgets('expands and reverses the diary container without stretching', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const sourceRect = Rect.fromLTWH(36, 104, 52, 38);
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: DiaryContainerTransform.openDuration,
      reverseDuration: DiaryContainerTransform.closeDuration,
    );
    addTearDown(controller.dispose);

    Widget buildSubject() {
      return MaterialApp(
        home: Scaffold(
          body: DiaryContainerTransform(
            animation: controller,
            selection: HomeCalendarDateSelection(
              date: DateTime(2026, 7, 15),
              rect: sourceRect,
              borderRadius: 10,
            ),
            child: const ColoredBox(
              key: Key('fixed-editor-layout'),
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildSubject());
    final panel = find.byKey(const Key('diary-container-panel'));
    final content = find.byKey(const Key('diary-container-content'));
    expect(tester.getRect(panel), sourceRect);
    expect(
      tester.getSize(find.byKey(const Key('fixed-editor-layout'))),
      const Size(400, 800),
    );
    expect(tester.widget<Opacity>(content).opacity, 0);
    expect(find.byKey(const Key('diary-container-scrim')), findsNothing);
    expect(
      tester.widget<ClipRRect>(panel).borderRadius,
      BorderRadius.circular(10),
    );

    controller.forward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final openingRect = tester.getRect(panel);
    expect(openingRect.width, greaterThan(sourceRect.width));
    expect(openingRect.width, lessThan(400));
    expect(openingRect.height, greaterThan(sourceRect.height));
    expect(tester.widget<Opacity>(content).opacity, lessThan(1));

    await tester.pump(const Duration(milliseconds: 280));
    await tester.pumpAndSettle();
    expect(tester.getRect(panel), const Rect.fromLTWH(0, 0, 400, 800));
    expect(tester.widget<Opacity>(content).opacity, closeTo(1, 0.00001));
    expect(tester.widget<ClipRRect>(panel).borderRadius, BorderRadius.zero);

    controller.reverse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 190));
    final closingRect = tester.getRect(panel);
    expect(closingRect.width, lessThan(400));
    expect(closingRect.width, greaterThan(sourceRect.width));

    await tester.pump(const Duration(milliseconds: 190));
    await tester.pumpAndSettle();
    expect(tester.getRect(panel), sourceRect);
    expect(tester.widget<Opacity>(content).opacity, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the full child immediately when animations are disabled', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: DiaryContainerTransform.openDuration,
      reverseDuration: DiaryContainerTransform.closeDuration,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: DiaryContainerTransform(
            animation: controller,
            selection: HomeCalendarDateSelection(
              date: DateTime(2026, 7, 15),
              rect: const Rect.fromLTWH(36, 104, 52, 38),
              borderRadius: 10,
            ),
            child: const ColoredBox(
              key: Key('reduced-motion-editor'),
              color: Colors.white,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('diary-container-panel')), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('reduced-motion-editor'))),
      tester.view.physicalSize / tester.view.devicePixelRatio,
    );
    expect(tester.takeException(), isNull);
  });
}
