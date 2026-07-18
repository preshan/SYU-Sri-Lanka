import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Intercepts Android/iOS system back so nested UI steps don't minimize the app.
///
/// Call order when back is pressed:
/// 1. [onBack] — return `true` if a local step was closed / undone
/// 2. Navigator pop — if [BuildContext.canPop]
/// 3. [fallbackLocation] — e.g. `/home` or `/login`
/// 4. If [allowExit] — leave the app (root screens only)
class SyuBackScope extends StatelessWidget {
  const SyuBackScope({
    super.key,
    required this.child,
    this.onBack,
    this.fallbackLocation,
    this.allowExit = false,
  });

  final Widget child;

  /// Return `true` if back was handled locally (wizard step, open thread, …).
  final bool Function()? onBack;

  /// Used when local handling and navigator pop are unavailable.
  final String? fallbackLocation;

  /// Root screens (login / home) may set this so the last back leaves the app.
  final bool allowExit;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // When allowExit, we still intercept first so [onBack] can run; exit is
      // performed manually below only if nothing else handled the event.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (onBack != null && onBack!()) return;
        if (context.canPop()) {
          context.pop();
          return;
        }
        if (fallbackLocation != null) {
          context.go(fallbackLocation!);
          return;
        }
        if (allowExit) {
          SystemNavigator.pop();
        }
      },
      child: child,
    );
  }
}
