/// Support for log files and process termination handling.
///
/// ```
/// void main(List<String> args) async {
///   await bootstrap(args, cleanup);
///
///   // Your code here
///
///   cleanup();
/// }
///
/// int cleanup(print) {
///   print('Cleaning up...');
///   Future.delayed(Duration(seconds: 1));
///   print('Done!');
///
///   return 0;
/// }
///```
library graceful;

export 'src/bootstrapper.dart' show bootstrap, Print;
