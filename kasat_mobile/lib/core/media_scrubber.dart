import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';

import 'kasat_config.dart';

class ScrubbedMedia {
  const ScrubbedMedia({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.strippedMetadata,
    required this.sha256,
  });

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;
  final bool strippedMetadata;

  /// Hex-encoded SHA-256 digest of the scrubbed pixel-only PNG file.
  /// Stored with the server-side UTC `created_at` timestamp to preserve
  /// chain-of-custody without retaining EXIF device or GPS metadata.
  final String sha256;
}

/// Strips identifying metadata out of picked media before it touches storage.
///
/// A photo straight out of a camera roll carries GPS coordinates, a capture
/// timestamp, a device serial, and often the owner's name. Decoding the image
/// to raw pixels and re-encoding it discards every one of those blocks: only
/// the pixels survive. Downscaling on the way through also blunts
/// sensor-noise fingerprinting.
abstract final class MediaScrubber {
  static Future<ScrubbedMedia> scrubImage(Uint8List input) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(input);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);

    final longestEdge = math.max(descriptor.width, descriptor.height);
    final scale = longestEdge > KasatConfig.attachmentMaxEdge
        ? KasatConfig.attachmentMaxEdge / longestEdge
        : 1.0;
    final targetWidth = math.max(1, (descriptor.width * scale).round());
    final targetHeight = math.max(1, (descriptor.height * scale).round());

    final codec = await descriptor.instantiateCodec(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;

    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Attachment could not be re-encoded.');
      }
      final outBytes = data.buffer.asUint8List();
      final digest = sha256.convert(outBytes).toString();
      return ScrubbedMedia(
        // dart:ui only ships a PNG encoder, so scrubbed stills are larger than
        // the JPEG that went in. Acceptable for the MVP; a server-side
        // re-encode is the follow-up.
        bytes: outBytes,
        mimeType: 'image/png',
        width: image.width,
        height: image.height,
        strippedMetadata: true,
        sha256: digest,
      );
    } finally {
      image.dispose();
      codec.dispose();
      descriptor.dispose();
    }
  }
}
