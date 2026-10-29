import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

/// Encrypted-at-rest identity. AES-256-GCM. The wrapping key lives in the
/// platform keychain (or an in-memory fallback in tests), never next to the
/// ciphertext in SharedPreferences.
class IdentityStore {
  static const _blobKey = 'kasat.identity.blob.v2';
  static const _legacyBlobKey = 'kasat.identity.blob.v1';
  static const _legacyKeyKey = 'kasat.identity.device_key.v1';
  static const _secureKey = 'kasat.identity.device_key.v2';

  late SharedPreferences _prefs;
  final _random = Random.secure();
  Key? _cachedKey;
  FlutterSecureStorage? _secure;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      if (Platform.environment['FLUTTER_TEST'] == 'true') {
        _secure = null;
      } else {
        _secure = const FlutterSecureStorage();
      }
    } catch (_) {
      _secure = null;
    }
    _cachedKey = await _loadKey();
  }

  bool get hasIdentity =>
      _prefs.getString(_blobKey) != null || _prefs.getString(_legacyBlobKey) != null;

  Future<void> save(IdentityRecord record) async {
    final payload = jsonEncode({
      'displayName': record.displayName.trim(),
      'channel': record.channel.name,
      'handle': record.handle.trim(),
    });
    final key = _cachedKey ?? await _loadKey();
    _cachedKey = key;
    final iv = IV.fromSecureRandom(12);
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(payload, iv: iv);
    await _prefs.setString(
      _blobKey,
      jsonEncode({'v': 'gcm', 'iv': iv.base64, 'data': encrypted.base64}),
    );
    await _prefs.remove(_legacyBlobKey);
    await _prefs.remove(_legacyKeyKey);
  }

  IdentityRecord? read() {
    final key = _cachedKey;
    if (key == null) return null;
    final raw = _prefs.getString(_blobKey) ?? _prefs.getString(_legacyBlobKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final iv = IV.fromBase64(map['iv'] as String);
      final mode = map['v'] == 'gcm' ? AESMode.gcm : AESMode.sic;
      final encrypter = Encrypter(AES(key, mode: mode));
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
    await _prefs.remove(_legacyBlobKey);
  }

  Future<Key> _loadKey() async {
    try {
      final stored = await _secure
          ?.read(key: _secureKey)
          .timeout(const Duration(milliseconds: 300));
      if (stored != null && stored.isNotEmpty) {
        return Key.fromBase64(stored);
      }
    } catch (_) {}
    final legacy = _prefs.getString(_legacyKeyKey);
    if (legacy != null && legacy.isNotEmpty) {
      final key = Key.fromBase64(legacy);
      try {
        await _secure
            ?.write(key: _secureKey, value: legacy)
            .timeout(const Duration(milliseconds: 300));
        await _prefs.remove(_legacyKeyKey);
      } catch (_) {}
      return key;
    }
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => _random.nextInt(256)),
    );
    final key = Key(bytes);
    try {
      await _secure
          ?.write(key: _secureKey, value: key.base64)
          .timeout(const Duration(milliseconds: 300));
    } catch (_) {}
    return key;
  }
}
