import 'package:flutter_flight_recorder/src/recorder/rolling_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RollingBuffer', () {
    test('rejects a non-positive capacity', () {
      expect(() => RollingBuffer<int>(0), throwsA(isA<AssertionError>()));
      expect(() => RollingBuffer<int>(-1), throwsA(isA<AssertionError>()));
    });

    test('keeps items in insertion order while under capacity', () {
      final buffer = RollingBuffer<int>(5)
        ..add(1)
        ..add(2)
        ..add(3);

      expect(buffer.toList(), [1, 2, 3]);
      expect(buffer.length, 3);
    });

    test('evicts the oldest item once at capacity', () {
      final buffer = RollingBuffer<int>(3)
        ..add(1)
        ..add(2)
        ..add(3)
        ..add(4);

      expect(buffer.toList(), [2, 3, 4]);
      expect(buffer.length, 3);
    });

    test('handles rapid insertion well past capacity', () {
      final buffer = RollingBuffer<int>(10);
      for (var i = 0; i < 1000; i++) {
        buffer.add(i);
      }

      expect(buffer.length, 10);
      expect(buffer.toList(), List.generate(10, (i) => 990 + i));
    });

    test('clear empties the buffer', () {
      final buffer = RollingBuffer<int>(3)
        ..add(1)
        ..add(2)
        ..clear();

      expect(buffer.toList(), isEmpty);
      expect(buffer.length, 0);
    });

    test('toList is a snapshot, not a live view', () {
      final buffer = RollingBuffer<int>(3)..add(1);
      final snapshot = buffer.toList();
      buffer.add(2);

      expect(snapshot, [1]);
      expect(buffer.toList(), [1, 2]);
    });
  });
}
