import 'package:flutter/material.dart';
import 'package:runiverse/core/theme/extensions/app_colors.dart';
import 'package:runiverse/core/theme/tokens/app_radius.dart';
import 'package:runiverse/core/theme/tokens/app_sizes.dart';
import 'package:runiverse/core/theme/tokens/app_spacing.dart';
import 'package:runiverse/core/theme/tokens/app_typography.dart';

/// 2초 길게 눌러야 걸리는 버튼.
///
/// **되돌릴 수 없는 액션은 탭으로 받지 않는다**(`docs/implementation-notes.md` §4).
/// 달리는 중에는 화면을 제대로 보지 않고 누르게 되고, 그때 한 번의 오탭으로
/// 러닝이 끝나면 복구할 방법이 없다.
///
/// 누르고 있는 동안 배경이 차오른다. **얼마나 더 눌러야 하는지가 보여야**
/// 사용자가 손을 떼지 않는다.
///
/// 손을 떼면 즉시 처음으로 돌아간다. 눌린 만큼 남겨두면 두 번 나눠 눌러
/// 실행되는 일이 생긴다.
class HoldButton extends StatefulWidget {
  const HoldButton({
    required this.label,
    required this.onHold,
    this.duration = const Duration(seconds: 2),
    super.key,
  });

  final String label;

  /// [duration]만큼 눌리고 있으면 불린다.
  final VoidCallback onHold;

  final Duration duration;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_onStatus);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _controller.value = 0;
      widget.onHold();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),

        // 손을 떼거나 손가락이 버튼 밖으로 나가면 처음으로.
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),

        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              height: AppSizes.touchRunning,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: AppRadius.full,
                border: Border.all(color: colors.borderStrong),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 왼쪽에서 오른쪽으로 차오른다.
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _controller.value,
                      child: ColoredBox(color: colors.error),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space5,
                    ),
                    child: child,
                  ),
                ],
              ),
            );
          },
          child: Text(
            widget.label,
            style: AppTypography.body.copyWith(color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}
