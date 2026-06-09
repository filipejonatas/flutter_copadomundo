import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const _webRecaptchaSiteKey = String.fromEnvironment(
  'APP_CHECK_WEB_RECAPTCHA_SITE_KEY',
);

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
    providerAndroid: kReleaseMode
        ? const AndroidPlayIntegrityProvider()
        : const AndroidDebugProvider(),
    providerApple: kReleaseMode
        ? const AppleAppAttestProvider()
        : const AppleDebugProvider(),
  );
}
