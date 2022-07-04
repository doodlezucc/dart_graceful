import 'package:graceful/graceful.dart';

void main(List<String> args) async {
  var dir = 'example/logs';
  await bootstrap(
    run,
    args: args,
    outLog: '$dir/out.log',
    errLog: '$dir/err.log',
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
