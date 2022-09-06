## 1.2.0

- Constrained SDK minimum to `2.16.0` (introduction of Stdio overrides).
- Fixed compile time error due to new `Stdin.echoNewlineMode` property in `dart:io`.

## 1.1.0

- Renamed `bootstrap` arguments to be more self explanatory.
- Allow bypassing the spawn of a child process with `enableChildProcess: false`.
- Listen to process signals from inside the worker instead of only the wrapper.

## 1.0.0

- Initial release.
