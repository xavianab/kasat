/// A file the survivor attached, after the scrubber has run over it.
class Attachment {
  const Attachment({
    required this.id,
    required this.label,
    required this.mimeType,
    required this.byteSize,
    required this.storagePath,
    required this.strippedMetadata,
    this.width,
    this.height,
    this.sha256,
    this.remoteObjectKey,
  });

  final String id;

  /// Kasat renames every file. The survivor's original filename can carry a
  /// device name, a date, or a username, so it is dropped at pick time.
  final String label;

  final String mimeType;
  final int byteSize;

  /// Absolute path inside the app sandbox.
  final String storagePath;

  /// True when the file was re-encoded and its EXIF/GPS block discarded.
  final bool strippedMetadata;

  final int? width;
  final int? height;

  /// SHA-256 hex digest computed over the scrubbed image bytes immediately
  /// after EXIF stripping. Stored with the server-side `created_at` UTC
  /// timestamp to preserve chain of custody without retaining device metadata.
  final String? sha256;

  /// Populated once the scrubbed file has been uploaded to Supabase Storage.
  final String? remoteObjectKey;

  Attachment copyWith({
    String? sha256,
    String? remoteObjectKey,
  }) {
    return Attachment(
      id: id,
      label: label,
      mimeType: mimeType,
      byteSize: byteSize,
      storagePath: storagePath,
      strippedMetadata: strippedMetadata,
      width: width,
      height: height,
      sha256: sha256 ?? this.sha256,
      remoteObjectKey: remoteObjectKey ?? this.remoteObjectKey,
    );
  }

  bool get isImage => mimeType.startsWith('image/');

  String get sizeLabel {
    if (byteSize < 1024) return '$byteSize B';
    if (byteSize < 1024 * 1024) return '${(byteSize / 1024).toStringAsFixed(0)} KB';
    return '${(byteSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get dimensionLabel => (width == null || height == null) ? '—' : '$width×$height';

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'mimeType': mimeType,
        'byteSize': byteSize,
        'storagePath': storagePath,
        'strippedMetadata': strippedMetadata,
        'width': width,
        'height': height,
        'sha256': sha256,
        'remoteObjectKey': remoteObjectKey,
      };

  static Attachment fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String,
      label: json['label'] as String,
      mimeType: json['mimeType'] as String,
      byteSize: json['byteSize'] as int,
      storagePath: json['storagePath'] as String,
      strippedMetadata: json['strippedMetadata'] as bool,
      width: json['width'] as int?,
      height: json['height'] as int?,
      sha256: json['sha256'] as String?,
      remoteObjectKey: json['remoteObjectKey'] as String?,
    );
  }
}
