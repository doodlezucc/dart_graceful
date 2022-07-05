import 'dart:async';
import 'dart:io';

import 'file_stdio.dart';

const argUnlock = 'unlock-boot';
const exitCommand = 'EXIT_GRACEFUL';
final _exitCommandBytes = exitCommand.codeUnits + [10];

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
  Logger loggerStd = logPassthrough,
  Logger loggerFile = logTimestamp,
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
      enableLogFiles: enableLogFiles,
      outLog: outLog,
      errLog: errLog,
      loggerStd: loggerStd,
      loggerFile: loggerFile,
      enableGracefulExit: enableGracefulExit,
      onExit: onExit,
    );
  } else {
    bootstrapper.runAsWrapper(signals: signals);
  }
}

class Bootstrapper {
  static bool _isRunning = true;
  static bool get isRunning => _isRunning;

  final BodyFunc body;
  final List<String> args;

  Bootstrapper({
    required this.body,
    required this.args,
  });

  void runAsWorker({
    required bool enableLogFiles,
    required String outLog,
    required String errLog,
    required Logger loggerStd,
    required Logger loggerFile,
    required bool enableGracefulExit,
    required ExitFunc? onExit,
  }) {
    // Override stdout and stderr with custom
    // file writer implementations
    IOOverrides.global = FileIOOverrides(
      File(outLog),
      File(errLog),
      stdLogger: loggerStd,
      fileLogger: loggerFile,
    );

    // For some reason, the child quits abruptly
    // if [stdout.done] is not listened to
    stdout.done.then((_) {});

    void workerProgram() {
      void customExit() async {
        _isRunning = false;
        var exitCode = await onExit!();
        exit(exitCode);
      }

      if (enableGracefulExit && onExit != null) {
        _watchForParentExit(customExit, outLog);
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

    print('child pid: ${process.pid}');

    var childExit = Completer();

    process.stdout.listen(stdout.add, onDone: () => childExit.complete());
    process.stderr.listen(stderr.add);
    stdin.listen(process.stdin.add);

    var watchable = signals.where((sig) => isSignalWatchable(sig));

    await Future.any([
      childExit.future,
      ...watchable.map((sig) => sig.watch().first),
    ]);

    print('Parent exits...');

    _sendExitToChild(process);
    await childExit.future;

    exit(0);
  }
}

bool _listsEqual(List a, List b) {
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }

  return true;
}

void _watchForParentExit(void Function() cleanup, String out) async {
  var parent = int.parse(Platform.environment[argUnlock]!);
  print('parent pid: $parent');

  stdin.listen((data) {
    if (_listsEqual(data, _exitCommandBytes)) cleanup();
  });

  await Future.delayed(Duration(seconds: 3));

  while (Bootstrapper.isRunning) {
    var isAlive = await _isProcessRunning(parent);

    if (!isAlive) {
      cleanup();
      break;
    }

    await Future.delayed(Duration(seconds: 3));
  }
}

void _sendExitToChild(Process process) {
  process.stdin.add(_exitCommandBytes);
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
