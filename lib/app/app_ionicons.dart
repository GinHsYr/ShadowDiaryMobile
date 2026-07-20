import 'package:flutter/widgets.dart';

/// Ionicons used by the application shell.
///
/// `ionicons_flutter` supplies the bundled font. Its 1.0.0 Dart wrapper still
/// subclasses [IconData], which is final in current Flutter releases, so these
/// constants instantiate [IconData] directly against the package font.
abstract final class AppIonicons {
  static const bookOutline = IconData(
    0xeaa6,
    fontFamily: 'Ionicons',
    fontPackage: 'ionicons_flutter',
  );

  static const folderOpenOutline = IconData(
    0xec20,
    fontFamily: 'Ionicons',
    fontPackage: 'ionicons_flutter',
  );

  static const imagesOutline = IconData(
    0xec8c,
    fontFamily: 'Ionicons',
    fontPackage: 'ionicons_flutter',
  );

  static const settingsOutline = IconData(
    0xee66,
    fontFamily: 'Ionicons',
    fontPackage: 'ionicons_flutter',
  );
}
