import 'package:flutter/services.dart';

import '../data/settings_store.dart';

enum DisguiseResult {
  applied,

  /// The platform has no alternate-icon support (older iOS, or Android where
  /// it needs activity-alias work that is not done yet).
  unsupported,

  /// Supported, but the icon assets are not provisioned in this build.
  notProvisioned,

  failed,
}

/// Swaps the home screen icon.
///
/// iOS caveats that the UI has to be honest about:
///  * The *display name* cannot be changed at runtime. Only the icon swaps, so
///    a disguise hides the artwork but not the label underneath it.
///  * `setAlternateIconName` always shows a system alert confirming the change.
///    It fires once, at the moment of choosing, not on later launches.
abstract final class AppDisguiseChannel {
  static const _channel = MethodChannel('app.kasat/disguise');

  static Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<DisguiseResult> apply(AppDisguise disguise) async {
    try {
      final code = await _channel.invokeMethod<String>(
        'setIcon',
        {'name': disguise.iconName},
      );
      return switch (code) {
        'applied' => DisguiseResult.applied,
        'unsupported' => DisguiseResult.unsupported,
        'not_provisioned' => DisguiseResult.notProvisioned,
        _ => DisguiseResult.failed,
      };
    } on PlatformException {
      return DisguiseResult.failed;
    } on MissingPluginException {
      return DisguiseResult.unsupported;
    }
  }
}
