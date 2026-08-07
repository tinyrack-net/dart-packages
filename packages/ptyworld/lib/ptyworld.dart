/// Cross-platform pseudo-terminal processes for Dart.
library;

import 'package:ptyworld/src/native_bindings.dart';

export 'src/pty_exception.dart';
export 'src/pty_process.dart';

/// Package API version, used to verify that the native asset is linked.
String get ptyworldVersion => nativePtyBindingsVersion();
