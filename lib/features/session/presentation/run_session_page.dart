import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:runiverse/app/router/app_routes.dart';
import 'package:runiverse/core/strings/app_strings.dart';
import 'package:runiverse/core/theme/extensions/app_colors.dart';
import 'package:runiverse/core/theme/tokens/app_radius.dart';
import 'package:runiverse/core/theme/tokens/app_spacing.dart';
import 'package:runiverse/core/theme/tokens/app_typography.dart';
import 'package:runiverse/core/widgets/app_button.dart';
import 'package:runiverse/core/widgets/hold_button.dart';
import 'package:runiverse/features/session/domain/pace_calculator.dart';
import 'package:runiverse/features/session/domain/run_metrics.dart';
import 'package:runiverse/features/session/domain/run_session_state.dart';
import 'package:runiverse/features/session/domain/screen_awake.dart';
import 'package:runiverse/features/session/presentation/run_session_provider.dart';

/// 러닝 진행 — 정본 S13의 페이지 2(실시간 기록)에 해당한다.
///
/// 정본은 3페이지 스와이프(지도 · 실시간 기록 · 파티원 비교)지만
/// 1인 러닝에는 파티원이 없고 지도는 이번 범위 밖이라 한 장만 만든다.
///
/// ## 화면에서 지켜야 하는 것
///
/// - 터치 타깃 **56px** (그 외 화면은 44px)
/// - 종료는 탭이 아니라 **2초 길게 누르기** — 되돌릴 수 없다
/// - 뒤로가기로 벗어날 수 없다. 실수로 나가면 기록이 끊긴다
/// - 수치는 `tabularFigures` — 자릿수가 바뀌어도 숫자가 흔들리지 않는다
class RunSessionPage extends ConsumerStatefulWidget {
  const RunSessionPage({super.key});

  @override
  ConsumerState<RunSessionPage> createState() => _RunSessionPageState();
}

class _RunSessionPageState extends ConsumerState<RunSessionPage> {
  /// [dispose]에서 쓰려고 붙잡아 둔다.
  ///
  /// `dispose()` 안에서 `ref.read`를 부르면 안 된다 — 그 시점의 `BuildContext`는
  /// 이미 트리에서 떨어져 있어 Riverpod이 막는다.
  late final ScreenAwake _screen = ref.read(screenAwakeProvider);

  @override
  void initState() {
    super.initState();
    // 화면이 꺼지면 추적도 멈춘다(포그라운드 전용).
    _screen.enable();
  }

  @override
  void dispose() {
    // 안 풀면 앱을 나가도 화면이 안 꺼진다.
    _screen.disable();
    super.dispose();
  }

  Future<void> _openStopSheet() async {
    ref.read(runSessionControllerProvider.notifier).pause();

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: context.appColors.bgElevated,
      builder: (sheetContext) => _StopSheet(
        onResume: () => Navigator.of(sheetContext).pop(),
        onFinish: () {
          ref.read(runSessionControllerProvider.notifier).finish();
          Navigator.of(sheetContext).pop();
          context.go(AppRoutes.runSummary);
        },
      ),
    );

    // 시트를 닫고 돌아왔는데 아직 멈춰 있으면 다시 달린다.
    // 종료했다면 상태가 RunPaused가 아니므로 resume은 아무것도 하지 않는다.
    ref.read(runSessionControllerProvider.notifier).resume();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return PopScope(
      // 뒤로가기로 러닝을 벗어나지 못하게 한다. 종료는 중지 시트에서만.
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.bgBase,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const _PaceHero(),
                const SizedBox(height: AppSpacing.space9),

                // 정본 S13의 2×2 그리드.
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: AppStrings.runMetricTime,
                        unit: '',
                        read: _formatElapsed,
                      ),
                    ),
                    Expanded(
                      child: _MetricTile(
                        label: AppStrings.runMetricDistance,
                        unit: AppStrings.runUnitKm,
                        read: (m) => m.distanceKm.toStringAsFixed(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space6),

                const Row(
                  children: [
                    // 아직 잴 수 없는 둘. 자리는 두되 값을 지어내지 않는다.
                    Expanded(
                      child: _UnavailableTile(
                        label: AppStrings.runMetricCadence,
                        unit: AppStrings.runUnitSpm,
                      ),
                    ),
                    Expanded(
                      child: _UnavailableTile(
                        label: AppStrings.runMetricCalorie,
                        unit: AppStrings.runUnitKcal,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                AppButton(
                  label: AppStrings.runStopCta,
                  onPressed: _openStopSheet,
                  variant: AppButtonVariant.secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `12:34` 또는 `1:02:34`. 한 시간을 넘기 전에는 시를 적지 않는다.
String _formatElapsed(RunMetrics metrics) {
  final elapsed = metrics.elapsed;
  final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

  if (elapsed.inHours == 0) return '$minutes:$seconds';
  return '${elapsed.inHours}:$minutes:$seconds';
}

/// 진행 중인 수치를 꺼낸다. 진행 중이 아니면 `null`.
RunMetrics? _metricsOf(RunSessionState state) => switch (state) {
  RunRunning(:final metrics) || RunPaused(:final metrics) => metrics,
  _ => null,
};

/// 가장 크게 보는 값. 정본이 ≥48pt로 정했다.
class _PaceHero extends ConsumerWidget {
  const _PaceHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    // **문자열로 좁혀서 watch한다.** 좌표가 들어와도 표시가 그대로면 다시 그리지 않는다.
    final pace = ref.watch(
      runSessionControllerProvider.select(
        (state) => PaceCalculator.format(_metricsOf(state)?.currentPace),
      ),
    );

    return Column(
      children: [
        Text(
          AppStrings.runMetricPace,
          style: AppTypography.caption.copyWith(color: colors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.space1),
        Text(
          pace,
          style: AppTypography.metricHero.copyWith(color: colors.textPrimary),
        ),
        Text(
          AppStrings.runUnitPerKm,
          style: AppTypography.caption.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// 2×2 그리드의 한 칸.
class _MetricTile extends ConsumerWidget {
  const _MetricTile({
    required this.label,
    required this.unit,
    required this.read,
  });

  final String label;
  final String unit;

  /// 수치에서 화면에 적을 문자열을 꺼낸다.
  final String Function(RunMetrics) read;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(
      runSessionControllerProvider.select((state) {
        final metrics = _metricsOf(state);
        return metrics == null
            ? AppStrings.runMetricUnavailable
            : read(metrics);
      }),
    );

    return _TileFrame(label: label, value: value, unit: unit);
  }
}

/// 아직 잴 수 없는 지표. 값이 바뀌지 않으므로 watch하지 않는다.
class _UnavailableTile extends StatelessWidget {
  const _UnavailableTile({required this.label, required this.unit});

  final String label;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return _TileFrame(
      label: label,
      value: AppStrings.runMetricUnavailable,
      unit: unit,
      dimmed: true,
    );
  }
}

class _TileFrame extends StatelessWidget {
  const _TileFrame({
    required this.label,
    required this.value,
    required this.unit,
    this.dimmed = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(color: colors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.space1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppTypography.metricLg.copyWith(
                color: dimmed ? colors.textDisabled : colors.textPrimary,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.space1),
              Text(
                unit,
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// 중지 시트 — 계속 달리거나, 길게 눌러 끝낸다.
class _StopSheet extends ConsumerWidget {
  const _StopSheet({required this.onResume, required this.onFinish});

  final VoidCallback onResume;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final metrics = ref.watch(runSessionControllerProvider.select(_metricsOf));

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.runPausedTitle,
            textAlign: TextAlign.center,
            style: AppTypography.h3.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.space4),

          if (metrics != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.space4),
              decoration: BoxDecoration(
                color: colors.bgSurface,
                borderRadius: AppRadius.lg,
              ),
              child: Text(
                '${metrics.distanceKm.toStringAsFixed(2)} ${AppStrings.runUnitKm}'
                '  ·  ${_formatElapsed(metrics)}'
                '  ·  ${PaceCalculator.format(metrics.averagePace)}',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: colors.textPrimary),
              ),
            ),
          const SizedBox(height: AppSpacing.space6),

          AppButton(label: AppStrings.runResumeCta, onPressed: onResume),
          const SizedBox(height: AppSpacing.space3),

          HoldButton(label: AppStrings.runFinishHold, onHold: onFinish),
        ],
      ),
    );
  }
}
