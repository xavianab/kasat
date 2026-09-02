import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contact channel used only for accountability. Never shown on Vent Here,
/// never attached to a report, never listed in the operator triage UI.
enum IdentityChannel { phone, email }

class IdentityRecord {
  const IdentityRecord({
    required this.displayName,
    required this.channel,
    required this.handle,
  });

  final String displayName;
  final IdentityChannel channel;

  /// Phone or email. Callers outside this store must treat it as secret.
  final String handle;
}

/// Encrypted-at-rest identity, stored under keys that do not appear in the
/// incident or vent JSON.
///
/// SECURITY_TODO: the AES key currently lives in the same prefs file as the
/// ciphertext. Before production this must move to the platform keychain,
/// with access logging and a written retention policy. See SECURITY_TODO.md.
class IdentityStore {
  static const _blobKey = 'kasat.identity.blob.v1';
  static const _keyKey = 'kasat.identity.device_key.v1';

  // Isolated from kasat.incidents.* and kasat.vent.* on purpose.
  // Do not add a foreign key from this store to a report or a vent post.

  late SharedPreferences _prefs;
  final _random = Random.secure();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get hasIdentity => _prefs.getString(_blobKey) != null;

  Future<void> save(IdentityRecord record) async {
    final payload = jsonEncode({
      'displayName': record.displayName.trim(),
      'channel': record.channel.name,
      'handle': record.handle.trim(),
    });
    final key = _deviceKey();
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(payload, iv: iv);
    await _prefs.setString(
      _blobKey,
      jsonEncode({'iv': iv.base64, 'data': encrypted.base64}),
    );
  }

  IdentityRecord? read() {
    final raw = _prefs.getString(_blobKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final iv = IV.fromBase64(map['iv'] as String);
      final encrypter = Encrypter(AES(_deviceKey()));
      final plain = encrypter.decrypt64(map['data'] as String, iv: iv);
      final decoded = jsonDecode(plain) as Map<String, dynamic>;
      return IdentityRecord(
        displayName: decoded['displayName'] as String,
        channel: IdentityChannel.values.byName(decoded['channel'] as String),
        handle: decoded['handle'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  /// Public-facing name only. Never the phone or email.
  String? get displayName => read()?.displayName;

  Future<void> clear() async {
    await _prefs.remove(_blobKey);
  }

  Key _deviceKey() {
    final existing = _prefs.getString(_keyKey);
    if (existing != null) return Key.fromBase64(existing);
    final bytes = Uint8List.fromList(List<int>.generate(32, (_) => _random.nextInt(256)));
    final key = Key(bytes);
    _prefs.setString(_keyKey, key.base64);
    return key;
  }
}
