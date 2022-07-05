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

class FileIOOverrides extends IOOverrides {
  final File outFile;
  final File errFile;
  late final FileStdout _stdout;
  late final FileStdout _stderr;

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
  }

  @override
  Stdout get stdout => _stdout;
  @override
  Stdout get stderr => _stderr;
}
