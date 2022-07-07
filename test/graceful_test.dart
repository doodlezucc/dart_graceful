import 'dart:io';

import 'package:graceful/src/bootstrapper.dart';
import 'package:test/test.dart';

void main() {
  test('List equality', () {
    expect(listsEqual([], []), true);
    expect(listsEqual([1], []), false);
    expect(listsEqual([1], [1]), true);
    expect(listsEqual([1], [2]), false);
    expect(listsEqual(['test'], ['test']), true);
    expect(listsEqual(['test'], ['rest']), false);
  });

  test('isProcessRunning (starting/killing a new process)', () async {
    var process = await Process.start(
      Platform.executable,
      ['example/graceful_example.dart'],
    );
    var pid = process.pid;

    expect(await isProcessRunning(pid), true);
    expect(process.kill(), true);
    expect(await isProcessRunning(pid), false);
  });
}
