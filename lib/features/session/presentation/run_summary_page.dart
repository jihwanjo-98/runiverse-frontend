import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:runiverse/app/router/app_routes.dart';
import 'package:runiverse/core/strings/app_strings.dart';
import 'package:runiverse/core/theme/extensions/app_colors.dart';
import 'package:runiverse/core/theme/tokens/app_spacing.dart';
import 'package:runiverse/core/theme/tokens/app_typography.dart';
import 'package:runiverse/core/widgets/app_button.dart';
import 'package:runiverse/features/session/domain/pace_calculator.dart';
import 'package:runiverse/features/session/domain/run_metrics.dart';
import 'package:runiverse/features/session/domain/run_session_state.dart';
import 'package:runiverse/features/session/presentation/run_session_provider.dart';

/// 러닝 요약 (S15).
///
/// 정본은 여기에 **획득 컬러**와 `자세한 기록 보기` · `피드에 공유하기`를 둔다.
/// 색 생성 규칙과 기록 저장이 아직 없어 핵심 수치와 홈으로 가는 길만 남겼다.
///
/// ## 저장되지 않는다는 것을 말한다
///
/// 기록을 남길 곳이 없다. 조용히 사라지게 두면 사용자는 앱이 고장 났다고 여긴다.
/// **없는 저장을 있는 척하지 않는다.**
class RunSummaryPage extends ConsumerWidget {
  const RunSummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final state = ref.watch(runSessionControllerProvider);

    // 요약할 것이 없으면 홈으로 돌려보낸다. 딥링크로 바로 들어온 경우다.
    if (state is! RunFinished) {
      return Scaffold(
        backgroundColor: colors.bgBase,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppButton(
                  label: AppStrings.runSummaryHome,
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final metrics = state.metrics;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              Text(
                AppStrings.runSummaryTitle,
                textAlign: TextAlign.center,
                style: AppTypography.h2.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.space7),

              Text(
                '${metrics.distanceKm.toStringAsFixed(2)} ${AppStrings.runUnitKm}',
                textAlign: TextAlign.center,
                style: AppTypography.metricHero.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),

              Text(
                _formatElapsed(metrics),
                textAlign: TextAlign.center,
                style: AppTypography.metricMd.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space5),

              Text(
                '${AppStrings.runSummaryAvgPace} '
                '${PaceCalculator.format(metrics.averagePace)}'
                '${AppStrings.runUnitPerKm}',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),

              const Spacer(),

              Text(
                AppStrings.runSummaryNotSaved,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.space3),

              AppButton(
                label: AppStrings.runSummaryHome,
                onPressed: () {
                  // 다음 러닝을 위해 비운다.
                  ref.read(runSessionControllerProvider.notifier).reset();
                  context.go(AppRoutes.home);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `27:40` 또는 `1:02:34`.
  static String _formatElapsed(RunMetrics metrics) {
    final elapsed = metrics.elapsed;
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    if (elapsed.inHours == 0) return '$minutes:$seconds';
    return '${elapsed.inHours}:$minutes:$seconds';
  }
}
