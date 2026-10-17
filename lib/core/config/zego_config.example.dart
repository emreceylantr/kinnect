// Copy this file to `zego_config.dart` or pass credentials via `--dart-define`:
// flutter run --dart-define=ZEGO_APP_ID=123456 --dart-define=ZEGO_APP_SIGN=your_sign
class ZegoConfig {
  static const int appId = int.fromEnvironment(
    'ZEGO_APP_ID',
    defaultValue: 0,
  );

  static const String appSign = String.fromEnvironment(
    'ZEGO_APP_SIGN',
    defaultValue: '',
  );
}
