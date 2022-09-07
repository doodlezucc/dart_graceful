import 'package:graceful/graceful.dart';

// You can use a single file for both `out` and `err` messages.
const exampleLogFile = 'example/logs/out.log';

void main(List<String> args) {
  return bootstrap(
    run,
    args: args,
    onExit: onExit,
    fileOut: exampleLogFile,
    fileErr: exampleLogFile,

    // Set this to false if your `run` method starts an indefinite process,
    // for example a server socket listening to incoming events.
    exitAfterBody: true,
  );
}

void run(List<String> args) async {
  print('Program start');
  print('Waiting for 5 seconds...');
  await Future.delayed(Duration(seconds: 5));

  print('Done.');

  while (true) {
    await Future.delayed(Duration(seconds: 1));
    print('bump');
  }
}

Future<int> onExit() async {
  print('Cleaning up...');
  await Future.delayed(Duration(seconds: 1));
  print('Program exit');

  return 0; // Exit code
}
