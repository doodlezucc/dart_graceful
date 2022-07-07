/// Support for log files and process termination handling.
///
/// Enable graceful exiting by returning `bootstrap(...)` directly from your
/// `main` and by defining a custom shutdown function.
///
/// ```
/// import 'package:graceful/graceful.dart';
///
/// void main(List<String> args) => bootstrap(run, args, onExit: onExit);
///
/// void run(List<String> args) {
///   // Your code...
/// }
///
/// Future<int> onExit() async {
///   // Perform cleanup...
///
///   print('Exited gracefully');
///   return 0; // Exit code 0
/// }
/// ```
library graceful;

export 'src/bootstrapper.dart'
    show allSignals, bootstrap, isDebugMode, Bootstrapper;
export 'src/file_stdio.dart'
    show
        BroadcastStdin,
        FileIOOverrides,
        FileStdout,
        logPassthrough,
        logTimestamp,
        Logger;
