import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef Logger = String Function(String line);

String logPassthrough(String line) => line;

String logTimestamp(String line) {
  var n = DateTime.now();
  var time = n.toIso8601String().substring(0, 19);
  return '$time $line';
}

class FileStdout implements Stdout {
  final IOSink output;
  final Stdout parent;
  final Logger fileLogger;
  final Logger stdLogger;

  @override
  Encoding encoding;

  FileStdout(
    this.output,
    this.parent, {
    required this.fileLogger,
    required this.stdLogger,
  }) : encoding = parent.encoding;

  @override
  void add(List<int> data) {
    parent.add(data);
    output.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    parent.addError(error, stackTrace);
    output.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) =>
      Future.wait([parent.addStream(stream), output.addStream(stream)]);

  @override
  Future close() => Future.wait([parent.close(), output.close()]);

  @override
  Future get done => Future.wait([parent.done, output.done]);

  @override
  Future flush() => Future.wait([parent.flush(), output.flush()]);

  @override
  bool get hasTerminal => parent.hasTerminal;

  @override
  IOSink get nonBlocking => parent.nonBlocking;

  @override
  bool get supportsAnsiEscapes => parent.supportsAnsiEscapes;

  @override
  int get terminalColumns => parent.terminalColumns;

  @override
  int get terminalLines => parent.terminalLines;

  @override
  void write(Object? object) {
    parent.write(object);
    output.write(object);
  }

  @override
  void writeAll(Iterable objects, [String sep = ""]) {
    parent.writeAll(objects, sep);
    output.writeAll(objects, sep);
  }

  @override
  void writeCharCode(int charCode) {
    parent.writeCharCode(charCode);
    output.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = ""]) {
    var out = _modifyLines(object, stdLogger);
    parent.writeln(out);

    if (fileLogger != stdLogger) {
      out = _modifyLines(object, fileLogger);
    }
    output.writeln(out);
  }

  String _modifyLines(Object? object, Logger logger) =>
      '$object'.split('\n').map((line) => logger(line)).join('\n');
}

class BroadcastStdin implements Stdin {
  final Stdin parent;
  final Stream<List<int>> broadcast;

  @override
  bool get echoMode => parent.echoMode;
  @override
  set echoMode(v) => parent.echoMode = v;

  @override
  bool get lineMode => parent.lineMode;
  @override
  set lineMode(v) => parent.lineMode = v;

  @override
  bool get hasTerminal => parent.hasTerminal;

  @override
  bool get supportsAnsiEscapes => parent.supportsAnsiEscapes;

  BroadcastStdin(this.parent) : broadcast = parent.asBroadcastStream();

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      broadcast.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  int readByteSync() => parent.readByteSync();

  @override
  String? readLineSync(
          {Encoding encoding = systemEncoding, bool retainNewlines = false}) =>
      parent.readLineSync(encoding: encoding, retainNewlines: retainNewlines);

  @override
  Future<bool> any(bool Function(List<int> element) test) =>
      broadcast.any(test);

  @override
  Stream<List<int>> asBroadcastStream(
          {void Function(StreamSubscription<List<int>> subscription)? onListen,
          void Function(StreamSubscription<List<int>> subscription)?
              onCancel}) =>
      broadcast.asBroadcastStream(onListen: onListen, onCancel: onCancel);

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(List<int> event) convert) =>
      broadcast.asyncExpand<E>(convert);

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(List<int> event) convert) =>
      broadcast.asyncMap<E>(convert);

  @override
  Stream<R> cast<R>() => broadcast.cast<R>();

  @override
  Future<bool> contains(Object? needle) => broadcast.contains(needle);

  @override
  Stream<List<int>> distinct(
          [bool Function(List<int> previous, List<int> next)? equals]) =>
      broadcast.distinct(equals);

  @override
  Future<E> drain<E>([E? futureValue]) => broadcast.drain<E>(futureValue);

  @override
  Future<List<int>> elementAt(int index) => broadcast.elementAt(index);

  @override
  Future<bool> every(bool Function(List<int> element) test) =>
      broadcast.every(test);

  @override
  Stream<S> expand<S>(Iterable<S> Function(List<int> element) convert) =>
      broadcast.expand<S>(convert);

  @override
  Future<List<int>> get first => broadcast.first;

  @override
  Future<List<int>> firstWhere(bool Function(List<int> element) test,
          {List<int> Function()? orElse}) =>
      broadcast.firstWhere(test, orElse: orElse);

  @override
  Future<S> fold<S>(
          S initialValue, S Function(S previous, List<int> element) combine) =>
      broadcast.fold<S>(initialValue, combine);

  @override
  Future forEach(void Function(List<int> element) action) =>
      broadcast.forEach(action);

  @override
  Stream<List<int>> handleError(Function onError,
          {bool Function(dynamic error)? test}) =>
      broadcast.handleError(onError);

  @override
  bool get isBroadcast => broadcast.isBroadcast;

  @override
  Future<bool> get isEmpty => broadcast.isEmpty;

  @override
  Future<String> join([String separator = ""]) => broadcast.join(separator);

  @override
  Future<List<int>> get last => broadcast.last;

  @override
  Future<List<int>> lastWhere(bool Function(List<int> element) test,
          {List<int> Function()? orElse}) =>
      broadcast.lastWhere(test, orElse: orElse);

  @override
  Future<int> get length => broadcast.length;

  @override
  Stream<S> map<S>(S Function(List<int> event) convert) =>
      broadcast.map(convert);

  @override
  Future pipe(StreamConsumer<List<int>> streamConsumer) =>
      broadcast.pipe(streamConsumer);

  @override
  Future<List<int>> reduce(
          List<int> Function(List<int> previous, List<int> element) combine) =>
      broadcast.reduce(combine);

  @override
  Future<List<int>> get single => broadcast.single;

  @override
  Future<List<int>> singleWhere(bool Function(List<int> element) test,
          {List<int> Function()? orElse}) =>
      broadcast.singleWhere(test, orElse: orElse);

  @override
  Stream<List<int>> skip(int count) => broadcast.skip(count);

  @override
  Stream<List<int>> skipWhile(bool Function(List<int> element) test) =>
      broadcast.skipWhile(test);

  @override
  Stream<List<int>> take(int count) => broadcast.take(count);

  @override
  Stream<List<int>> takeWhile(bool Function(List<int> element) test) =>
      broadcast.takeWhile(test);

  @override
  Stream<List<int>> timeout(Duration timeLimit,
          {void Function(EventSink<List<int>> sink)? onTimeout}) =>
      broadcast.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<List<List<int>>> toList() => broadcast.toList();

  @override
  Future<Set<List<int>>> toSet() => broadcast.toSet();

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) =>
      broadcast.transform(streamTransformer);

  @override
  Stream<List<int>> where(bool Function(List<int> event) test) =>
      broadcast.where(test);
}

class FileIOOverrides extends IOOverrides {
  final File outFile;
  final File errFile;
  late final FileStdout _stdout;
  late final FileStdout _stderr;
  late final BroadcastStdin _stdin;

  FileIOOverrides(
    this.outFile,
    this.errFile, {
    Logger stdLogger = logPassthrough,
    Logger fileLogger = logTimestamp,
  }) {
    outFile.createSync(recursive: true);
    errFile.createSync(recursive: true);
    _stdout = FileStdout(
      outFile.openWrite(),
      super.stdout,
      fileLogger: fileLogger,
      stdLogger: stdLogger,
    );
    _stderr = FileStdout(
      errFile.openWrite(),
      super.stderr,
      fileLogger: fileLogger,
      stdLogger: stdLogger,
    );
    _stdin = BroadcastStdin(super.stdin);
  }

  @override
  Stdout get stdout => _stdout;
  @override
  Stdout get stderr => _stderr;
  @override
  Stdin get stdin => _stdin;
}
