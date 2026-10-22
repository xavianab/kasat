import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../core/media_scrubber.dart';
import '../models/attachment.dart';

/// Writes scrubbed media into the app sandbox under a random name.
///
/// The original filename is never reused: `IMG_20240517_ravi.jpg` names a
/// date and a person, and that is exactly the kind of metadata Kasat promises
/// not to keep.
class AttachmentStore {
  static final _random = Random.secure();

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/attachments');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Attachment> persistImage(Uint8List raw, {required int index}) async {
    final scrubbed = await MediaScrubber.scrubImage(raw);
    final id = _token();
    final dir = await _dir();
    final file = File('${dir.path}/$id.png');
    await file.writeAsBytes(scrubbed.bytes, flush: true);

    return Attachment(
      id: id,
      label: 'EVIDENCE-${(index + 1).toString().padLeft(2, '0')}',
      mimeType: scrubbed.mimeType,
      byteSize: scrubbed.bytes.length,
      storagePath: file.path,
      strippedMetadata: scrubbed.strippedMetadata,
      width: scrubbed.width,
      height: scrubbed.height,
      sha256: scrubbed.sha256,
    );
  }

  Future<void> delete(Attachment attachment) async {
    final file = File(attachment.storagePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  static String _token() {
    const chars = 'abcdef0123456789';
    return List.generate(16, (_) => chars[_random.nextInt(chars.length)]).join();
  }
}
