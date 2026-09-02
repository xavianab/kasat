import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrustedContact {
  const TrustedContact({required this.name, required this.phone});

  final String name;
  final String phone;
}

/// One trusted number, encrypted on this phone. Never synced.
class DuressStore {
  static const _blobKey = 'kasat.duress.contact.v1';
  static const _keyKey = 'kasat.duress.device_key.v1';

  late SharedPreferences _prefs;
  final _random = Random.secure();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get hasContact => _prefs.getString(_blobKey) != null;

  Future<void> save(TrustedContact contact) async {
    final key = _deviceKey();
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(
      jsonEncode({'name': contact.name.trim(), 'phone': contact.phone.trim()}),
      iv: iv,
    );
    await _prefs.setString(
      _blobKey,
      jsonEncode({'iv': iv.base64, 'data': encrypted.base64}),
    );
  }

  TrustedContact? read() {
    final raw = _prefs.getString(_blobKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final iv = IV.fromBase64(map['iv'] as String);
      final encrypter = Encrypter(AES(_deviceKey()));
      final plain = encrypter.decrypt64(map['data'] as String, iv: iv);
      final decoded = jsonDecode(plain) as Map<String, dynamic>;
      return TrustedContact(
        name: decoded['name'] as String,
        phone: decoded['phone'] as String,
      );
    } catch (_) {
      return null;
    }
  }

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
