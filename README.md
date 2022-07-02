Allows piping `print` to log files and enables graceful exits.

By registering a small bootstrapper at the start of your Dart application, your program gets run as a detached child process.
This prevents abrupt exiting (e.g. pressing <kbd>Control</kbd>+<kbd>C</kbd> or closing the window) and allows you to listen to `stdout` and `stderr`.

If you're on Windows, make sure you have [Dart SDK v2.17.0 or higher](https://github.com/dart-lang/sdk/commit/b6c5e52af6771762aa593b333fd1185f66674658) installed.

## Usage

Enable graceful exiting by calling `await bootstrap(...)` at the start of `main` and by defining a custom shutdown function.

```dart
import 'package:graceful/graceful.dart';

void main(List<String> args) async {
  await bootstrap(args, cleanExit); // Register bootstrapper

  // Your code...
}

Future<int> cleanExit(Print print) async {
  // Perform cleanup...

  print('Exited gracefully');
  return 0; // Exit code 0
}
```

Use `print` as you would anywhere else in your code.
At shutdown, regular `stdout` messages aren't automatically piped into log files. Because of this, you're provided with a special print function.

## How it works

When running your Dart program, two processes are started behind the scenes - parent and child.

As soon as an instance runs into `await bootstrap(...)`, it either continues or blocks execution. The abscence of a specific environment variable causes the initial process to act as parent/wrapper. Instead of running your code, it starts another instance of itself that should take the role of child/worker process.

This worker process keeps running even if the parent is terminated. As per the [API Docs](https://api.dart.dev/stable/dart-io/Process/start.html):

> If `mode` is [`ProcessStartMode.detachedWithStdio`](https://api.dart.dev/stable/dart-io/ProcessStartMode/detachedWithStdio-constant.html) a detached process will be created where the stdin, stdout and stderr are connected. The creator can communicate with the child through these. The detached process will keep running even if these communication channels are closed.

Both parent and child know of each other's process identifier (or PID). Periodically, the child/worker process checks if a program with this PID is still running. If not, the parent was shut down and the child is commanded to clean up and exit.