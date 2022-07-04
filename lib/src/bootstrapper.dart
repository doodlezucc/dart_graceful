import 'dart:async';
import 'dart:io';

import 'file_stdio.dart';

const argUnlock = 'unlock-boot';
bool isRunning = true;

typedef BodyFunc = FutureOr Function(List<String> args);
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

bool isDebugMode() {
  return Platform.executableArguments.contains('--enable-asserts');
}

/// Runs this program in a detached child process.
///
/// Graceful exiting is **disabled in debug mode**, as breakpoints are not
/// properly triggered.
/// Pass `enableGracefulExit: true` to enable it anyway.
///
/// It's recommended to return `bootstrap()` directly from your `main` function.
///
/// ```
/// // Dart entry
/// void main(List<String> args) {
///   return bootstrap(run, args, onExit: onExit);
/// }
///
/// void run(List<String> args) {
///   // Your program...
/// }
///
/// Future<int> onExit() async {
///   // Perform cleanup...
///   return 0;
/// }
/// ```
void bootstrap(
  BodyFunc body, {
  List<String> args = const [],
  bool enableLogFiles = true,
  String outLog = 'logs/out.log',
  String errLog = 'logs/err.log',
  bool? enableGracefulExit,
  ExitFunc? onExit,
  Iterable<ProcessSignal> signals = allSignals,
}) async {
  var bootstrapper = Bootstrapper(
    body: body,
    args: args,
  );

  enableGracefulExit ??= !isDebugMode();

  if (!enableGracefulExit || Platform.environment.containsKey(argUnlock)) {
    bootstrapper.runAsWorker(
      outLog: outLog,
      errLog: errLog,
      enableLogFiles: enableLogFiles,
      onExit: onExit,
      enableGracefulExit: enableGracefulExit,
    );
  } else {
    bootstrapper.runAsWrapper(signals: signals);
  }
}

class Bootstrapper {
  final BodyFunc body;
  final List<String> args;

  Bootstrapper({
    required this.body,
    required this.args,
  });

  void runAsWorker({
    required ExitFunc? onExit,
    required bool enableLogFiles,
    required String outLog,
    required String errLog,
    required bool enableGracefulExit,
  }) {
    // Override stdout and stderr with custom
    // file writer implementations
    IOOverrides.global = FileIOOverrides(File(outLog), File(errLog));

    // For some reason, the child quits abruptly
    // if [stdout.done] is not listened to
    stdout.done.then((_) {});

    void workerProgram() {
      if (enableGracefulExit && onExit != null) {
        _watchForParentExit(onExit, outLog);
      }

      body(args);
    }

    void onError(e, s) {
      stdout.writeln('Error haha');
      stderr.writeln(e);
      stderr.writeln(s);
    }

    // Run program with custom print function
    return runZonedGuarded(
      workerProgram,
      onError,
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, line) => stdout.writeln(line),
      ),
    );
  }

  void runAsWrapper({required Iterable<ProcessSignal> signals}) async {
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
  } else if (Platform.isLinux) {
    var result = await Process.run(
      'ps',
      ['$pid'],
      runInShell: true,
    );
    return result.exitCode == 0;
  }

  throw UnsupportedError(
      'Not able to find parent process on ${Platform.operatingSystem}');
}
