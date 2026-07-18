import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opens an admin tool. Uses [go] (not push) so Home is replaced, not stacked.
void openAdminOverlay(BuildContext context, String tabName) {
  context.go('/admin?tab=$tabName');
}

void closeAdminOverlay(BuildContext context) {
  context.go('/home');
}
