import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:syu_sri_lanka/core/analytics/syu_clarity.dart';

Widget wrapWithClarity(Widget app) {
  return ClarityWidget(
    app: app,
    clarityConfig: ClarityConfig(projectId: SyuClarity.projectId),
  );
}
