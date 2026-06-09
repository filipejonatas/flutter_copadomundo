import 'package:flutter/foundation.dart';

const _localApiBaseUrl = 'http://127.0.0.1:3000';

Uri resolveApiBaseUri(String configuredValue) {
  final value = configuredValue.trim();
  final effectiveValue = value.isEmpty && !kReleaseMode
      ? _localApiBaseUrl
      : value;

  if (effectiveValue.isEmpty) {
    throw StateError(
      'API_BASE_URL precisa ser configurada para builds de release.',
    );
  }

  final uri = Uri.tryParse(effectiveValue);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw StateError('API_BASE_URL invalida: $effectiveValue');
  }

  if (kReleaseMode && uri.scheme != 'https') {
    throw StateError('API_BASE_URL precisa usar HTTPS em release.');
  }

  return uri;
}
