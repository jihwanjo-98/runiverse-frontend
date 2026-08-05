// flutter_test는 material을 재수출하지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runiverse/app/app.dart';
import 'package:runiverse/app/router/app_routes.dart';
import 'package:runiverse/core/strings/app_strings.dart';
import 'package:runiverse/core/widgets/app_button.dart';
import 'package:runiverse/core/widgets/hold_button.dart';
import 'package:runiverse/features/session/data/fake_location_repository.dart';
import 'package:runiverse/features/session/data/wakelock_screen_awake.dart';
import 'package:runiverse/features/session/domain/geo_point.dart';
import 'package:runiverse/features/session/domain/location_repository.dart';
import 'package:runiverse/features/session/presentation/run_prepare_page.dart';
import 'package:runiverse/features/session/presentation/run_session_page.dart';
import 'package:runiverse/features/session/presentation/run_session_provider.dart';
import 'package:runiverse/features/session/presentation/run_summary_page.dart';

/// 1인 러닝 — 출발 준비부터 요약까지 화면이 실제로 이어지는가.
///
/// ⚠️ **러닝 중에는 `pumpAndSettle`을 쓰지 않는다.** 컨트롤러가 1초짜리 반복 타이머를
/// 돌리고 있어서 영원히 끝나지 않는다. 끝낸 뒤에는 타이머가 멈춰 다시 쓸 수 있다.
void main() {
  final start = DateTime(2026, 8, 5, 19);
  late DateTime clock;
  late FakeLocationRepository location;
  late NoopScreenAwake screen;

  setUp(() {
    clock = start;
    location = FakeLocationRepository();
    screen = NoopScreenAwake();
  });

  Future<void> pumpRun(
    WidgetTester tester, {
    LocationAccess access = LocationAccess.granted,
  }) async {
    location = FakeLocationRepository(access: access);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationRepositoryProvider.overrideWithValue(location),
          screenAwakeProvider.overrideWithValue(screen),
          runClockProvider.overrideWithValue(() => clock),
        ],
        child: const RuniverseApp(initialLocation: AppRoutes.runPrepare),
      ),
    );
    await tester.pumpAndSettle();
  }

  GeoPoint point(double lat, double lon) =>
      GeoPoint(latitude: lat, longitude: lon, recordedAt: clock);

  /// 좌표를 흘려보내고 화면에 반영될 때까지 기다린다.
  ///
  /// **프레임이 두 번 필요하다.** 스트림 이벤트가 컨트롤러에 닿는 데 한 번,
  /// 바뀐 상태로 화면을 다시 그리는 데 한 번이다.
  Future<void> emit(WidgetTester tester, GeoPoint p) async {
    location.emit(p);
    await tester.pump();
    await tester.pump();
  }

  /// 3 · 2 · 1을 넘기고 러닝 화면이 뜰 때까지 기다린다.
  ///
  /// `pumpAndSettle`을 쓸 수 없어(1초짜리 반복 타이머) 화면 전환에 필요한 만큼만
  /// 손으로 돌린다.
  Future<void> skipCountdown(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// 출발 준비를 마치고 달리는 상태로 만든다.
  Future<void> startRunning(WidgetTester tester) async {
    await emit(tester, point(37.5, 127));
    await tester.tap(find.widgetWithText(AppButton, AppStrings.runStartCta));
    await tester.pump();
    await skipCountdown(tester);
  }

  /// 달리는 중에 테스트를 끝내면 **1초짜리 반복 타이머가 남아** flutter_test가 죽는다.
  /// 앱을 걷어내면 provider가 dispose되면서 타이머와 위치 구독이 함께 끊긴다 —
  /// 실제 앱에서도 같은 경로로 정리된다.
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  bool startEnabled(WidgetTester tester) {
    final button = tester.widget<AppButton>(
      find.widgetWithText(AppButton, AppStrings.runStartCta),
    );
    return button.onPressed != null;
  }

  group('출발 준비', () {
    testWidgets('신호를 찾는 동안에는 출발할 수 없다', (tester) async {
      await pumpRun(tester);

      expect(find.text(AppStrings.runGpsSearching), findsOneWidget);
      expect(startEnabled(tester), isFalse);

      // 왜 잠겼는지 함께 말한다. 이유 없는 잠금은 고장으로 읽힌다.
      expect(find.text(AppStrings.runGpsWhy), findsOneWidget);
    });

    testWidgets('신호가 잡히면 출발할 수 있다', (tester) async {
      await pumpRun(tester);

      await emit(tester, point(37.5, 127));

      expect(find.text(AppStrings.runGpsReady), findsOneWidget);
      expect(startEnabled(tester), isTrue);
    });

    testWidgets('권한을 거절하면 이유를 보여준다', (tester) async {
      await pumpRun(tester, access: LocationAccess.deniedForever);

      expect(find.text(AppStrings.runAccessDeniedForever), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, AppStrings.runOpenSettings),
        findsOneWidget,
      );
    });

    testWidgets('위치 기능이 꺼진 경우는 권한 거절과 문구가 다르다', (tester) async {
      await pumpRun(tester, access: LocationAccess.serviceDisabled);

      expect(find.text(AppStrings.runServiceDisabled), findsOneWidget);
      expect(find.text(AppStrings.runAccessDeniedForever), findsNothing);
    });
  });

  group('러닝 진행', () {
    testWidgets('카운트다운을 지나면 러닝 화면이 열린다', (tester) async {
      await pumpRun(tester);

      await startRunning(tester);

      expect(find.byType(RunSessionPage), findsOneWidget);
      expect(find.byType(RunPreparePage), findsNothing);

      await unmount(tester);
    });

    testWidgets('달리는 동안 화면을 켜 둔다', (tester) async {
      await pumpRun(tester);

      await startRunning(tester);

      expect(screen.enabled, isTrue);

      await unmount(tester);
    });

    testWidgets('거리가 화면에 반영된다', (tester) async {
      await pumpRun(tester);
      await startRunning(tester);

      await emit(tester, point(37.5, 127));
      await emit(tester, point(37.501, 127));

      // 위도 0.001도 = 약 111m.
      expect(find.text('0.11'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('아직 못 재는 지표는 값을 지어내지 않는다', (tester) async {
      await pumpRun(tester);
      await startRunning(tester);

      expect(find.text(AppStrings.runMetricCadence), findsOneWidget);
      expect(find.text(AppStrings.runMetricCalorie), findsOneWidget);
      expect(find.text(AppStrings.runMetricUnavailable), findsNWidgets(2));

      await unmount(tester);
    });
  });

  group('중지 시트', () {
    testWidgets('중지하면 계속과 종료를 고를 수 있다', (tester) async {
      await pumpRun(tester);
      await startRunning(tester);

      await tester.tap(find.widgetWithText(AppButton, AppStrings.runStopCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(AppStrings.runPausedTitle), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, AppStrings.runResumeCta),
        findsOneWidget,
      );
      expect(find.byType(HoldButton), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('한 번 탭으로는 끝나지 않는다', (tester) async {
      await pumpRun(tester);
      await startRunning(tester);
      await tester.tap(find.widgetWithText(AppButton, AppStrings.runStopCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 되돌릴 수 없는 액션이라 2초를 눌러야 한다.
      await tester.tap(find.byType(HoldButton));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(RunSummaryPage), findsNothing);

      await unmount(tester);
    });

    testWidgets('2초 길게 누르면 요약으로 간다', (tester) async {
      await pumpRun(tester);
      await startRunning(tester);
      await tester.tap(find.widgetWithText(AppButton, AppStrings.runStopCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldButton)),
      );
      // 한 번에 3초를 건너뛰면 애니메이션이 틱을 못 받는다. 잘게 돌린다.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byType(RunSummaryPage), findsOneWidget);
    });
  });

  group('요약', () {
    Future<void> finishRun(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(AppButton, AppStrings.runStopCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldButton)),
      );
      // 한 번에 3초를 건너뛰면 애니메이션이 틱을 못 받는다. 잘게 돌린다.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('저장되지 않는다는 것을 말한다', (tester) async {
      await pumpRun(tester);
      await startRunning(tester);
      await finishRun(tester);

      // 조용히 사라지면 사용자는 앱이 고장 났다고 여긴다.
      expect(find.text(AppStrings.runSummaryNotSaved), findsOneWidget);
    });

    testWidgets('달린 거리를 보여준다', (tester) async {
      await pumpRun(tester);
      await startRunning(tester);
      await emit(tester, point(37.5, 127));
      await emit(tester, point(37.501, 127));
      await finishRun(tester);

      expect(find.textContaining('0.11'), findsOneWidget);
    });

    testWidgets('끝내면 화면을 다시 꺼지게 둔다', (tester) async {
      await pumpRun(tester);
      await startRunning(tester);
      await finishRun(tester);

      // 안 풀면 앱을 나가도 화면이 안 꺼진다.
      expect(screen.enabled, isFalse);
    });
  });
}
