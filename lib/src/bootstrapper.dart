import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';

import 'future_queue.dart';

const argUnlock = 'unlock-boot';
bool isRunning = true;

typedef Print = void Function(Object obj);
typedef CleanExit = FutureOr<int> Function(Print print);

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
  List<String> args,
  CleanExit cleanExit, {
  String out = 'logs/out.log',
  String err = 'logs/err.log',
  Iterable<ProcessSignal> signals = allSignals,
}) async {
  if (Platform.environment.containsKey(argUnlock)) {
    _watchForParentExit(cleanExit, out);
    return;
  }

  Future<RandomAccessFile> open(String path) async {
    var dir = dirname(path);
    await Directory(dir).create(recursive: true);
    return await File(path).open(mode: FileMode.writeOnly);
  }

  var script = Platform.script.toFilePath();
  print(script);

  var process = await Process.start(
    'dart',
    [script, ...args],
    mode: ProcessStartMode.detachedWithStdio,
    environment: {argUnlock: '$pid'},
  );

  print('child process pid: ${process.pid}');

  var completer = Completer();

  var outFile = await open(out);
  var errFile = await open(err);
  var outSeq = FutureQueue();
  var errSeq = FutureQueue();

  process.stdout.listen((data) {
    stdout.add(data);
    outSeq.add(() => outFile.writeFrom(data));
  }, onDone: () => completer.complete());

  process.stderr.listen((data) {
    stderr.add(data);
    errSeq.add(() => errFile.writeFrom(data));
  });

  var watchable = signals.where((sig) => isSignalWatchable(sig));

  await Future.any([
    completer.future,
    ...watchable.map((sig) => sig.watch().first),
  ]);

  outSeq.add(() => outFile.close());
  errSeq.add(() => errFile.close());
  await Future.wait([outSeq.whenDrained, errSeq.whenDrained]);

  exit(0);
}

void _specialPrint(Object obj, String out) {
  print(obj);
  File(out).writeAsStringSync('$obj\n', mode: FileMode.append);
}

void _watchForParentExit(CleanExit cleanup, String out) async {
  var parent = int.parse(Platform.environment[argUnlock]!);
  print('parent pid: $parent');
  while (isRunning) {
    await Future.delayed(Duration(seconds: 3));

    var isAlive = await _isProcessRunning(parent);

    if (!isAlive) {
      var exitCode = await cleanup((obj) => _specialPrint(obj, out));
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
