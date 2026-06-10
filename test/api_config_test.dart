import 'package:copa_palpite/services/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveApiBaseUri', () {
    test(
      'should use local API base URL when configured value is empty in debug',
      () {
        // Arrange
        const configuredValue = '';

        // Act
        final uri = resolveApiBaseUri(configuredValue);

        // Assert
        expect(uri.toString(), 'http://127.0.0.1:3000');
      },
    );

    test('should trim and return a valid configured URL', () {
      // Arrange
      const configuredValue = '  https://api.example.test  ';

      // Act
      final uri = resolveApiBaseUri(configuredValue);

      // Assert
      expect(uri.scheme, 'https');
      expect(uri.host, 'api.example.test');
    });

    test('should throw StateError for malformed URL', () {
      // Arrange
      const configuredValue = 'not-a-url';

      // Act / Assert
      expect(
        () => resolveApiBaseUri(configuredValue),
        throwsA(isA<StateError>()),
      );
    });
  });
}
