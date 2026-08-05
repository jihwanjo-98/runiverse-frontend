import 'dart:async';

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
import 'package:runiverse/features/session/domain/location_repository.dart';
import 'package:runiverse/features/session/domain/run_session_state.dart';
import 'package:runiverse/features/session/presentation/run_session_provider.dart';

/// 출발 준비 — GPS 첫 신호를 기다린다.
///
/// 정본 S11(출발 대기실)의 컴포넌트 리스트가 **"GPS 인디케이터: 최우선(러닝 실패 예방)"**
/// 이라고 정했다. 신호를 잡기 전에 출발하면 초반 거리가 통째로 빠지고,
/// 사용자는 기록이 짧게 나온 이유를 알 수 없다.
///
/// 그래서 신호를 받기 전에는 시작 버튼을 잠그고 **잠긴 이유를 글로** 보여준다.
/// 점 색깔만으로 알리지 않는다(§3-5).
class RunPreparePage extends ConsumerStatefulWidget {
  const RunPreparePage({super.key});

  @override
  ConsumerState<RunPreparePage> createState() => _RunPreparePageState();
}

class _RunPreparePageState extends ConsumerState<RunPreparePage> {
  /// 위치를 쓸 수 있는가. `null`이면 아직 확인 중이다.
  LocationAccess? _access;

  /// 3 · 2 · 1. `null`이면 카운트다운 전이다.
  int? _countdown;

  Timer? _ticker;

  @override
  void initState() {
    super.initState();

    // 프레임이 끝난 뒤에 부른다. [initState]에서 바로 부르면 위젯 트리를 그리는
    // 도중에 provider를 바꾸게 되어 Riverpod이 막는다 — 디버그에서 앱이 죽는다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    final access = await ref
        .read(runSessionControllerProvider.notifier)
        .prepare();
    if (mounted) setState(() => _access = access);
  }

  /// 3초를 센 뒤 출발한다. **세는 도중에는 되돌아갈 수 없다**(정본 S11).
  void _beginCountdown() {
    setState(() => _countdown = 3);

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = (_countdown ?? 1) - 1;
      if (next > 0) {
        setState(() => _countdown = next);
        return;
      }

      timer.cancel();
      ref.read(runSessionControllerProvider.notifier).start();
      if (mounted) context.go(AppRoutes.runSession);
    });
  }

  void _quit() {
    ref.read(runSessionControllerProvider.notifier).reset();
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final countdown = _countdown;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: countdown != null
              ? _Countdown(countdown)
              : _prepareBody(context),
        ),
      ),
    );
  }

  Widget _prepareBody(BuildContext context) {
    final access = _access;

    return switch (access) {
      null => const Center(child: CircularProgressIndicator()),
      LocationAccess.granted => _ReadyView(onStart: _beginCountdown),
      _ => _BlockedView(access: access, onQuit: _quit),
    };
  }
}

/// 신호를 기다리는 화면. 잡히면 시작 버튼이 열린다.
class _ReadyView extends ConsumerWidget {
  const _ReadyView({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    // 필요한 값 하나만 본다. 상태 전체를 watch하면 좌표마다 화면이 다시 그려진다.
    final hasFix = ref.watch(
      runSessionControllerProvider.select(
        (state) => state is RunPreparing && state.hasFix,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.runPrepareTitle,
          style: AppTypography.h2.copyWith(color: colors.textPrimary),
        ),
        const Spacer(),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: AppSpacing.space3,
              height: AppSpacing.space3,
              decoration: BoxDecoration(
                color: hasFix ? colors.success : colors.textTertiary,
                borderRadius: AppRadius.full,
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            Text(
              hasFix ? AppStrings.runGpsReady : AppStrings.runGpsSearching,
              style: AppTypography.body.copyWith(color: colors.textPrimary),
            ),
          ],
        ),

        if (!hasFix) ...[
          const SizedBox(height: AppSpacing.space2),
          Text(
            AppStrings.runGpsWhy,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: colors.textTertiary),
          ),
        ],

        const Spacer(),

        // 신호가 없으면 null을 넘겨 잠근다.
        AppButton(
          label: AppStrings.runStartCta,
          onPressed: hasFix ? onStart : null,
        ),
      ],
    );
  }
}

/// 위치를 쓸 수 없을 때. 이유마다 할 수 있는 일이 다르다.
class _BlockedView extends ConsumerWidget {
  const _BlockedView({required this.access, required this.onQuit});

  final LocationAccess access;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    final message = switch (access) {
      LocationAccess.denied => AppStrings.runAccessDenied,
      LocationAccess.deniedForever => AppStrings.runAccessDeniedForever,
      LocationAccess.serviceDisabled => AppStrings.runServiceDisabled,
      LocationAccess.granted => '',
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.space6),

        // 다시 물을 수 없는 두 경우에만 설정으로 보낸다.
        // '이번에 거절'은 앱이 다시 물을 수 있으므로 설정까지 갈 필요가 없다.
        if (access != LocationAccess.denied)
          AppButton(
            label: AppStrings.runOpenSettings,
            onPressed: () =>
                ref.read(locationRepositoryProvider).openSettings(),
          ),
        const SizedBox(height: AppSpacing.space2),

        AppButton(
          label: AppStrings.runQuit,
          onPressed: onQuit,
          variant: AppButtonVariant.ghost,
        ),
      ],
    );
  }
}

/// 3 · 2 · 1. 다른 것은 전부 감추고 숫자만 남긴다(정본 S11).
class _Countdown extends StatelessWidget {
  const _Countdown(this.value);

  final int value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$value',
        style: AppTypography.metricHero.copyWith(
          fontSize: 160,
          color: context.appColors.textPrimary,
        ),
      ),
    );
  }
}
