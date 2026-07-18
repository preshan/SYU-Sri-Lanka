import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opens an admin tool on top of Home so system back returns to the dashboard.
void openAdminOverlay(BuildContext context, String tabName) {
  context.push('/admin?tab=$tabName');
}

void closeAdminOverlay(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}
