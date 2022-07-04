import 'package:graceful/graceful.dart';

const exampleLogs = 'example/logs';

void main(List<String> args) {
  return bootstrap(
    run,
    args: args,
    outLog: '$exampleLogs/out.log',
    errLog: '$exampleLogs/err.log',
    onExit: onExit,
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
  print('Exiting');

  return 0;
}
