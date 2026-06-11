import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const _webRecaptchaSiteKey = String.fromEnvironment(
  'APP_CHECK_WEB_RECAPTCHA_SITE_KEY',
);
const _androidProvider = String.fromEnvironment(
  'APP_CHECK_ANDROID_PROVIDER',
  defaultValue: 'play_integrity',
);

bool get shouldRequestAppCheckToken =>
    !kIsWeb || _webRecaptchaSiteKey.isNotEmpty;

Future<void> activateAppCheck() async {
  if (kIsWeb) {
    if (_webRecaptchaSiteKey.isEmpty) {
      if (kReleaseMode) {
        throw StateError(
          'APP_CHECK_WEB_RECAPTCHA_SITE_KEY precisa ser configurada em release web.',
        );
      }
      return;
    }

    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaV3Provider(_webRecaptchaSiteKey),
    );
    return;
  }

  await FirebaseAppCheck.instance.activate(
    providerAndroid: _resolveAndroidProvider(),
    providerApple: kReleaseMode
        ? const AppleAppAttestProvider()
        : const AppleDebugProvider(),
  );
}

AndroidAppCheckProvider _resolveAndroidProvider() {
  if (!kReleaseMode) return const AndroidDebugProvider();

  return switch (_androidProvider.trim().toLowerCase()) {
    'debug' => const AndroidDebugProvider(),
    'play_integrity' ||
    'play-integrity' => const AndroidPlayIntegrityProvider(),
    _ => throw StateError(
      'APP_CHECK_ANDROID_PROVIDER invalido: $_androidProvider. '
      'Use play_integrity ou debug.',
    ),
  };
}
