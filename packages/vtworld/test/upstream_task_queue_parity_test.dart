import 'package:test/test.dart';
import 'package:vtworld/src/core/task_queue.dart';

void main() {
  test('task queue flush preserves order and repeats truthy tasks', () {
    final calls = <String>[];
    var attempts = 0;
    final queue = PriorityTaskQueue()
      ..enqueue(() {
        calls.add('first');
        return null;
      })
      ..enqueue(() {
        calls.add('repeat${++attempts}');
        return attempts < 2;
      })
      ..enqueue(() {
        calls.add('last');
        return false;
      })
      ..flush();
    expect(calls, <String>['first', 'repeat1', 'repeat2', 'last']);
    queue.clear();
  });

  test('debounced idle task retains only the latest task', () {
    final calls = <String>[];
    final task = DebouncedIdleTask()
      ..set(() {
        calls.add('old');
        return null;
      })
      ..set(() {
        calls.add('new');
        return null;
      })
      ..flush();
    expect(calls, <String>['new']);
    task.dispose();
  });
}
