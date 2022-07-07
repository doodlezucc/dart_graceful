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
  if (sig != ProcessSignal.sigint && sig != ProcessSignal.sighup) {
    if (Platform.isWindows) return false;

    return sig == ProcessSignal.sigterm ||
        sig == ProcessSignal.sigusr1 ||
        sig == ProcessSignal.sigusr2 ||
        sig == ProcessSignal.sigwinch;
  }
  return true;
}

bool get isDebugMode =>
    Platform.executableArguments.contains('--enable-asserts');

const bool? ifNotDebugging = null;

/// Allows running this program with a custom exiting function
/// and optional file logging.
///
/// This bootstrapper normally starts a new child process to make sure your
/// program doesn't exit unexpectedly.
/// Child process spawning is **disabled in debug mode**, as breakpoints are not
/// properly triggered. Pass `enableChildProcess: true` to enable it anyway.
///
/// Log files are **disabled in debug mode** by default and can be enabled with
/// `enableLogFiles: true`.
///
/// It's recommended to return `bootstrap()` directly from your `main` function.
///
/// ```
/// // Dart entry
/// void main(List<String> args) {
///   return bootstrap(run, args: args, onExit: onExit);
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
  ExitFunc? onExit,
  Iterable<ProcessSignal> signals = allSignals,
  bool? enableChildProcess = ifNotDebugging,
  bool? enableLogFiles = ifNotDebugging,
  String fileOut = 'logs/out.log',
  String fileErr = 'logs/err.log',
  Logger formatterStd = logPassthrough,
  Logger formatterFile = logTimestamp,
}) async {
  var bootstrapper = Bootstrapper(
    body: body,
    args: args,
    signals: signals,
  );

  enableChildProcess ??= !isDebugMode;
  enableLogFiles ??= !isDebugMode;

  if (!enableChildProcess || Platform.environment.containsKey(argUnlock)) {
    bootstrapper.runAsWorker(
      enableLogFiles: enableLogFiles,
      outLog: fileOut,
      errLog: fileErr,
      loggerStd: formatterStd,
      loggerFile: formatterFile,
      isChildProcess: enableChildProcess,
      onExit: onExit,
    );
  } else {
    bootstrapper.runAsWrapper();
  }
}

class Bootstrapper {
  static bool _isRunning = true;
  static bool get isRunning => _isRunning;
  static bool _isExiting = false;

  final BodyFunc body;
  final List<String> args;
  final Iterable<ProcessSignal> signals;

  static final _exitController = StreamController(sync: true);

  Bootstrapper({
    required this.body,
    required this.args,
    required this.signals,
  });

  void runAsWorker({
    required bool enableLogFiles,
    required String outLog,
    required String errLog,
    required Logger loggerStd,
    required Logger loggerFile,
    required bool isChildProcess,
    required ExitFunc? onExit,
  }) {
    if (enableLogFiles) {
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
    }

    void workerProgram() {
      void customExit() async {
        if (_isExiting) return;

        _isExiting = true;
        _isRunning = false;
        var exitCode = onExit != null ? await onExit() : 0;
        exit(exitCode);
      }

      Future.any([
        Bootstrapper._exitController.stream.first,
        ..._awaitSignals(signals)
      ]).then((_) => customExit());

      if (isChildProcess && onExit != null) {
        _watchForParentExit(customExit);
      }

      body(args);
    }

    void onError(e, s) {
      stderr.writeln(e);
      stderr.writeln(s);
      Bootstrapper.exitGracefully();
    }

    var printToStdout = ZoneSpecification(
      print: (_, __, ___, line) => stdout.writeln(line),
    );

    if (!isChildProcess) {
      return runZoned(workerProgram, zoneSpecification: printToStdout);
    }

    // Run program with custom print function
    return runZonedGuarded(
      workerProgram,
      onError,
      zoneSpecification: printToStdout,
    );
  }

  static void exitGracefully() {
    _exitController.add(null);
  }

  void runAsWrapper() async {
    var script = Platform.script.toFilePath();
    var isCompiled = !script.endsWith('.dart');

    var process = await Process.start(
      Platform.executable,
      isCompiled ? args : [script, ...args],
      mode: ProcessStartMode.detachedWithStdio,
      environment: {...Platform.environment, argUnlock: '$pid'},
    );

    var childExit = Completer();

    process.stdout.listen(stdout.add, onDone: () => childExit.complete());
    process.stderr.listen(stderr.add);
    stdin.listen(process.stdin.add);

    await Future.any([childExit.future, ..._awaitSignals(signals)]);

    _sendExitToChild(process);
    await childExit.future;

    exit(0);
  }
}

Iterable<Future> _awaitSignals(Iterable<ProcessSignal> signals) {
  var watchable = signals.where((sig) => isSignalWatchable(sig));
  return watchable.map((sig) => sig.watch().first);
}

bool listsEqual(List a, List b) {
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }

  return true;
}

void _watchForParentExit(void Function() cleanup) async {
  var parent = int.parse(Platform.environment[argUnlock]!);

  stdin.listen((data) {
    if (listsEqual(data, _exitCommandBytes)) cleanup();
  });

  await Future.delayed(Duration(seconds: 3));

  while (Bootstrapper.isRunning) {
    var isAlive = await isProcessRunning(parent);

    if (!isAlive) {
      break;
    }

    await Future.delayed(Duration(seconds: 3));
  }

  cleanup();
}

void _sendExitToChild(Process process) {
  process.stdin.add(_exitCommandBytes);
}

Future<bool> isProcessRunning(int pid) async {
  if (Platform.isWindows) {
    var result = await Process.run(
      'powershell',
      ['ps', '-Id', '$pid'],
      runInShell: true,
    );
    return result.exitCode == 0;
  } else if (Platform.isLinux || Platform.isMacOS) {
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
