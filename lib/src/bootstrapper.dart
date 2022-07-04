import 'dart:async';
import 'dart:io';

import 'file_stdio.dart';

const argUnlock = 'unlock-boot';
bool isRunning = true;

typedef Print = void Function(Object obj);
typedef ExitFunc = FutureOr<int> Function();

const allSignals = [
  ProcessSignal.sigint,
  ProcessSignal.sighup,
  ProcessSignal.sigterm,
];

bool isSignalWatchable(ProcessSignal sig) {
  if (Platform.isWindows) {
    return sig == ProcessSignal.sigint || sig == ProcessSignal.sighup;
  }
  return true;
}

Future<void> bootstrap(
  FutureOr Function(List<String> args) body, {
  List<String> args = const [],
  String outLog = 'logs/out.log',
  String errLog = 'logs/err.log',
  ExitFunc? onExit,
  Iterable<ProcessSignal> signals = allSignals,
}) async {
  if (Platform.environment.containsKey(argUnlock)) {
    // Override stdout and stderr with custom
    // file writer implementations
    IOOverrides.global = FileIOOverrides(File(outLog), File(errLog));

    // For some reason, the child quits abruptly
    // if [stdout.done] is not listened to
    stdout.done.then((_) {});

    // Run program with custom print function
    return runZoned(
      () {
        if (onExit != null) {
          _watchForParentExit(onExit, outLog);
        }

        return body(args);
      },
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, line) => stdout.writeln(line),
      ),
    );
  }

  var script = Platform.script.toFilePath();
  var isCompiled = !script.endsWith('.dart');

  var process = await Process.start(
    Platform.executable,
    isCompiled ? args : [script, ...args],
    mode: ProcessStartMode.detachedWithStdio,
    environment: {...Platform.environment, argUnlock: '$pid'},
  );

  print('child process pid: ${process.pid}');

  var childExit = Completer();

  process.stdout.listen(stdout.add, onDone: () => childExit.complete());
  process.stderr.listen(stderr.add);

  var watchable = signals.where((sig) => isSignalWatchable(sig));

  await Future.any([
    childExit.future,
    ...watchable.map((sig) => sig.watch().first),
  ]);

  print('Parent exits');

  exit(0);
}

void _watchForParentExit(ExitFunc cleanup, String out) async {
  var parent = int.parse(Platform.environment[argUnlock]!);
  print('parent pid: $parent');
  while (isRunning) {
    await Future.delayed(Duration(seconds: 3));

    var isAlive = await _isProcessRunning(parent);

    if (!isAlive) {
      var exitCode = await cleanup();
      exit(exitCode);
    }
  }
}

Future<bool> _isProcessRunning(int pid) async {
  if (Platform.isWindows) {
    var result = await Process.run(
      'powershell',
      ['ps', '-Id', '$pid'],
      runInShell: true,
    );
    return result.exitCode == 0;
  }
  throw UnsupportedError(
      'Bootstrapper not yet supported for ${Platform.operatingSystem}');
}
