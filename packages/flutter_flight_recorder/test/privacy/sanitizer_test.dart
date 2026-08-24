import 'package:flutter_flight_recorder/src/privacy/sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sanitizer', () {
    test('masks default sensitive keys', () {
      final sanitizer = Sanitizer();
      final result = sanitizer.sanitizeMetadata({
        'password': 'hunter2',
        'token': 'abc123',
        'authorization': 'Bearer xyz',
        'access_token': 'abc',
        'refresh_token': 'def',
        'cookie': 'session=abc',
        'session': 'sess-1',
        'username': 'jane',
      });

      expect(result['password'], '***');
      expect(result['token'], '***');
      expect(result['authorization'], '***');
      expect(result['access_token'], '***');
      expect(result['refresh_token'], '***');
      expect(result['cookie'], '***');
      expect(result['session'], '***');
      expect(result['username'], 'jane');
    });

    test('matches sensitive keys case-insensitively', () {
      final sanitizer = Sanitizer();
      final result = sanitizer.sanitizeMetadata({'Password': 'secret'});

      expect(result['Password'], '***');
    });

    test('masks sensitive keys at any nesting depth', () {
      final sanitizer = Sanitizer();
      final result = sanitizer.sanitizeMetadata({
        'user': {'email': 'user@example.com', 'password': 'secret'},
      });

      expect(result['user'], {'email': 'user@example.com', 'password': '***'});
    });

    test('masks sensitive keys inside lists of maps', () {
      final sanitizer = Sanitizer();
      final result = sanitizer.sanitizeMetadata({
        'users': [
          {'email': 'a@example.com', 'token': 'abc'},
          {'email': 'b@example.com', 'token': 'def'},
        ],
      });

      expect(result['users'], [
        {'email': 'a@example.com', 'token': '***'},
        {'email': 'b@example.com', 'token': '***'},
      ]);
    });

    test('honors a custom sensitive key set', () {
      final sanitizer = Sanitizer(sensitiveKeys: {'pwd'});
      final result = sanitizer.sanitizeMetadata({
        'pwd': 'secret',
        'password': 'not-masked-by-this-config',
      });

      expect(result['pwd'], '***');
      expect(result['password'], 'not-masked-by-this-config');
    });

    test('applies a custom sanitizer before default masking', () {
      final sanitizer = Sanitizer(
        customSanitizer: (key, value) {
          if (key == 'email') return '<redacted-email>';
          return value;
        },
      );
      final result = sanitizer.sanitizeMetadata({
        'email': 'user@example.com',
        'password': 'secret',
      });

      expect(result['email'], '<redacted-email>');
      expect(result['password'], '***');
    });

    test('normalizes non-JSON-safe values instead of throwing', () {
      final sanitizer = Sanitizer();
      final result = sanitizer.sanitizeMetadata({'value': _NotSerializable()});

      expect(result['value'], isA<String>());
      expect(result['value'], contains('NotSerializable'));
    });

    test('normalizes DateTime to an ISO 8601 string', () {
      final sanitizer = Sanitizer();
      final timestamp = DateTime.utc(2026, 1, 1);
      final result = sanitizer.sanitizeMetadata({'when': timestamp});

      expect(result['when'], timestamp.toIso8601String());
    });

    test('truncates very large string values', () {
      final sanitizer = Sanitizer();
      final huge = 'x' * (Sanitizer.maxStringLength + 500);
      final result = sanitizer.sanitizeMetadata({'blob': huge});

      final value = result['blob'] as String;
      expect(value.length, lessThan(huge.length));
      expect(value, startsWith('x' * 10));
      expect(value, endsWith('[truncated]'));
    });

    test('leaves values at or under the length limit untouched', () {
      final sanitizer = Sanitizer();
      final value = 'x' * Sanitizer.maxStringLength;
      final result = sanitizer.sanitizeMetadata({'blob': value});

      expect(result['blob'], value);
    });

    test('returns an unmodifiable map', () {
      final sanitizer = Sanitizer();
      final result = sanitizer.sanitizeMetadata({'a': 1});

      expect(() => result['a'] = 2, throwsUnsupportedError);
    });

    test('handles an empty metadata map', () {
      final sanitizer = Sanitizer();
      expect(sanitizer.sanitizeMetadata(const {}), isEmpty);
    });
  });
}

class _NotSerializable {
  @override
  String toString() => 'NotSerializable instance';
}
