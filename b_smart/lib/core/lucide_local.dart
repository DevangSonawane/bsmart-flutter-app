import 'package:flutter/widgets.dart';

/// Converts Lucide IconData from the package (fontPackage: lucide_icons_flutter)
/// to use the app-bundled Lucide font (no package) so icons display correctly.
/// Use: LucideIcons.heart.localLucide
extension LucideLocal on IconData {
  IconData get localLucide {
    if (fontPackage == 'lucide_icons_flutter') {
      return IconData(
        codePoint,
        fontFamily: fontFamily ?? 'Lucide',
        fontPackage: null,
        matchTextDirection: matchTextDirection,
      );
    }
    return this;
  }
}
