import 'dart:collection';

/// A fixed-capacity FIFO buffer: adding past [maxLength] evicts the oldest
/// item first. Backed by [ListQueue] so both add and evict are O(1).
class RollingBuffer<T> {
  RollingBuffer(this.maxLength)
      : assert(maxLength > 0, 'maxLength must be greater than 0'),
        _items = ListQueue<T>(maxLength);

  final int maxLength;
  final ListQueue<T> _items;

  int get length => _items.length;

  void add(T item) {
    if (_items.length >= maxLength) {
      _items.removeFirst();
    }
    _items.addLast(item);
  }

  List<T> toList() => List.unmodifiable(_items);

  void clear() => _items.clear();
}
