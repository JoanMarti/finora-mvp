import 'package:flutter/widgets.dart';

/// Window classes the app lays itself out for.
///
/// - [compact]: phones. Bottom navigation, one column.
/// - [medium]: tablets and narrow browser windows. Navigation rail.
/// - [expanded]: laptops and desktops. Full sidebar with every section,
///   multi-column pages and master–detail views.
enum FinoraWindow {
  compact,
  medium,
  expanded;

  static const mediumMinWidth = 720.0;
  static const expandedMinWidth = 1100.0;

  static FinoraWindow forWidth(double width) => width >= expandedMinWidth
      ? expanded
      : width >= mediumMinWidth
      ? medium
      : compact;

  static FinoraWindow of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == compact;
}

/// Content wider than this gets a second column (dashboard, accounts).
const finoraWideContentWidth = 960.0;
