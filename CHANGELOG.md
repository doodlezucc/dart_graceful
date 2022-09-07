## 1.2.0

- Fixed compile time error due to new `Stdin.echoNewlineMode` property in `dart:io`.
- Constrained SDK minimum to `2.16.0` (introduction of Stdio overrides).
- Bootstrapped programs now immediately exit after running the passed `body`. This behavior can be changed by passing `exitAfterBody: false`.

## 1.1.0

- Renamed `bootstrap` arguments to be more self explanatory.
- Allow bypassing the spawn of a child process with `enableChildProcess: false`.
- Listen to process signals from inside the worker instead of only the wrapper.

## 1.0.0

- Initial release.
