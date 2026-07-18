import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opens an admin tool on top of Home so system back returns to the dashboard.
void openAdminOverlay(
  BuildContext context,
  String tabName, {
  String? list,
}) {
  final params = <String, String>{'tab': tabName};
  if (list != null && list.isNotEmpty) params['list'] = list;
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  context.push('/admin?$query');
}

void closeAdminOverlay(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}
