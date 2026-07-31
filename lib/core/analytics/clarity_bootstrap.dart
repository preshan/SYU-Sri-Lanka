import 'package:flutter/widgets.dart';

import 'clarity_bootstrap_stub.dart'
    if (dart.library.io) 'clarity_bootstrap_io.dart' as impl;

/// Wraps [app] with Microsoft Clarity on Android/iOS.
/// Web uses the JS tag in `web/index.html` instead.
Widget wrapWithClarity(Widget app) => impl.wrapWithClarity(app);
