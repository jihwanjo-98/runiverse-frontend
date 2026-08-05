import 'package:runiverse/features/session/domain/screen_awake.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 실제로 화면을 켜 두는 구현.
///
/// **이 파일이 wakelock_plus를 아는 유일한 곳이다.**
class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

/// 아무것도 하지 않는 구현 — 테스트용.
class NoopScreenAwake implements ScreenAwake {
  NoopScreenAwake();

  /// 지금 켜져 있는가. 테스트가 해제까지 확인한다.
  bool enabled = false;

  @override
  Future<void> enable() async => enabled = true;

  @override
  Future<void> disable() async => enabled = false;
}
