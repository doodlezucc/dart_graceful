class FutureQueue {
  final List<Future Function()> _calls = [];
  Future whenDrained = Future.value();

  void add(Future Function() futureBuilder) {
    _calls.add(futureBuilder);
    if (_calls.length == 1) {
      whenDrained = _drain();
    }
  }

  Future<void> _drain() async {
    while (_calls.isNotEmpty) {
      var waitForFuture = _calls.first;
      await waitForFuture();
      _calls.removeAt(0);
    }
  }
}
