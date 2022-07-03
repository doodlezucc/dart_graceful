/// Support for log files and process termination handling.
///
/// Enable graceful exiting by calling `await bootstrap(...)` at the start
/// of `main` and by defining a custom shutdown function.
///
/// ```
/// import 'package:graceful/graceful.dart';
///
/// void main(List<String> args) async {
///   await bootstrap(args, cleanExit); // Register bootstrapper
///
///   // Your code...
/// }
///
/// Future<int> cleanExit(Print print) async {
///   // Perform cleanup...
///
///   print('Exited gracefully');
///   return 0; // Exit code 0
/// }
/// ```
library graceful;

export 'src/bootstrapper.dart' show bootstrap, Print, allSignals;
