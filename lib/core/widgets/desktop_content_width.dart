import 'package:flutter/widgets.dart';

import '../platform.dart';

/// Caps a screen's content at a readable width on desktop, where the window
/// is often far wider than a phone. Goes inside each Scaffold body, under
/// the gradient, so backgrounds and dialog scrims stay full-bleed (a cap in
/// MaterialApp.builder would shrink those too).
class DesktopContentWidth extends StatelessWidget {
  const DesktopContentWidth({super.key, required this.child});

  static const maxWidth = 900.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
