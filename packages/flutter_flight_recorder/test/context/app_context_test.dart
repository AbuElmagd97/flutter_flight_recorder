import 'package:flutter_flight_recorder/src/context/app_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppContext', () {
    test('captures platform and locale without app-supplied input', () {
      final context = AppContext();
      final snapshot = context.snapshot();

      expect(snapshot.containsKey('platform'), isTrue);
      expect(snapshot.containsKey('locale'), isTrue);
    });

    test('set() adds custom context to the snapshot', () {
      final context = AppContext()..set('environment', 'uat');

      expect(context.snapshot()['environment'], 'uat');
    });

    test('set() overwrites a previously set value', () {
      final context = AppContext()
        ..set('environment', 'uat')
        ..set('environment', 'production');

      expect(context.snapshot()['environment'], 'production');
    });

    test('snapshot is unmodifiable', () {
      final context = AppContext();
      expect(
        () => context.snapshot()['new_key'] = 'value',
        throwsUnsupportedError,
      );
    });

    test('custom context can override a fixed key', () {
      final context = AppContext()..set('platform', 'custom-override');

      expect(context.snapshot()['platform'], 'custom-override');
    });
  });
}
