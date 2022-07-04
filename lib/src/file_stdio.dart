import 'dart:convert';
import 'dart:io';

Future<void> debugPrint(Object line) {
  return Future.sync(
      () => File('debug').writeAsStringSync('$line\n', mode: FileMode.append));
}

class MySink implements IOSink {
  @override
  Encoding encoding;

  final IOSink next;

  MySink(this.next) : encoding = next.encoding;

  @override
  void add(List<int> data) {
    debugPrint('ADD $data');
    next.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    debugPrint('ADD ERROR $error');
    next.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    debugPrint('ADD STREAM');
    return next.addStream(stream);
  }

  @override
  Future close() {
    debugPrint('CLOSE');
    return next.close();
  }

  @override
  Future get done => next.done;

  @override
  Future flush() {
    debugPrint('FLUSH');
    return next.flush();
  }

  @override
  void write(Object? object) {
    debugPrint('WRITE $object');
    next.write(object);
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    debugPrint('WRITE ALL');
    next.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    debugPrint('WRITE CHAR CHODE $charCode');
    next.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = ""]) {
    debugPrint('WRITE LN $object');
    next.writeln(object);
  }
}

class FileStdout implements Stdout {
  final IOSink output;
  final Stdout parent;

  @override
  Encoding encoding;

  FileStdout(this.output, this.parent) : encoding = parent.encoding;

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
    parent.writeln(object);
    output.writeln(object);
  }
}

class FileIOOverrides extends IOOverrides {
  final File outFile;
  final File errFile;
  late final FileStdout _stdout;
  late final FileStdout _stderr;

  FileIOOverrides(this.outFile, this.errFile) {
    outFile.createSync(recursive: true);
    errFile.createSync(recursive: true);
    _stdout = FileStdout(outFile.openWrite(), super.stdout);
    _stderr = FileStdout(errFile.openWrite(), super.stderr);
  }

  @override
  Stdout get stdout => _stdout;
  @override
  Stdout get stderr => _stderr;
}
