import 'package:graceful/graceful.dart';

void main(List<String> args) async {
  var dir = 'example/logs';
  await bootstrap(
    args,
    cleanExit,
    out: '$dir/out.log',
    err: '$dir/err.log',
  );

  print('Program start');
  print('Waiting for 5 seconds...');
  await Future.delayed(Duration(seconds: 5));

  print('Done.');

  while (true) {
    await Future.delayed(Duration(seconds: 1));
    print('bump');
  }
}

Future<int> cleanExit(Print print) async {
  print('Cleaning up...');
  await Future.delayed(Duration(seconds: 1));
  print('Exiting');

  return 0;
}
