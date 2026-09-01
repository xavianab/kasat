import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/kasat_config.dart';
import '../../../models/attachment.dart';
import '../../../theme/kasat_theme.dart';
import '../../../widgets/dashed_border.dart';
import '../../../widgets/mono_badge.dart';

class MediaDropzone extends StatelessWidget {
  const MediaDropzone({
    super.key,
    required this.attachments,
    required this.onAdd,
    required this.onRemove,
    required this.busy,
  });

  final List<Attachment> attachments;
  final VoidCallback onAdd;
  final ValueChanged<Attachment> onRemove;
  final bool busy;

  bool get _full => attachments.length >= KasatConfig.maxAttachments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Opacity(
          opacity: _full ? 0.4 : 1,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: (_full || busy) ? null : onAdd,
            child: DashedBorder(
              color: busy ? KC.accent : KC.borderHi,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: KSpace.md),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 1.6, color: KC.accent),
                      )
                    else
                      const Icon(Icons.add_photo_alternate_outlined, size: 20, color: KC.muted),
                    const SizedBox(height: KSpace.sm),
                    Text(
                      busy ? 'SCRUBBING METADATA…' : 'TAP TO ATTACH EVIDENCE',
                      style: KType.mono(
                        size: 10.5,
                        weight: FontWeight.w700,
                        color: busy ? KC.accent : KC.text,
                        tracking: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Images are decoded and re-encoded on this device.\n'
                      'EXIF, GPS and camera serials never leave it.',
                      textAlign: TextAlign.center,
                      style: KType.sans(size: 11, color: KC.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: KSpace.md),
          for (final attachment in attachments)
            _AttachmentRow(
              attachment: attachment,
              onRemove: () => onRemove(attachment),
            ),
        ],
      ],
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment, required this.onRemove});

  final Attachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: KSpace.sm),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: KC.canvas,
        border: Border.all(color: KC.border),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              width: 38,
              height: 38,
              child: attachment.isImage
                  ? Image.file(File(attachment.storagePath), fit: BoxFit.cover)
                  : Container(
                      color: KC.surfaceHi,
                      child: const Icon(Icons.description_outlined, size: 16),
                    ),
            ),
          ),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.label,
                  style: KType.mono(size: 11, weight: FontWeight.w700, tracking: 0.6),
                ),
                const SizedBox(height: 3),
                Text(
                  '${attachment.sizeLabel} · ${attachment.dimensionLabel} · PNG',
                  style: KType.mono(size: 9.5, color: KC.faint),
                ),
              ],
            ),
          ),
          if (attachment.strippedMetadata)
            const MonoBadge('SCRUBBED', color: KC.accent, filled: true, size: 9, dense: true),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 15),
            color: KC.faint,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          ),
        ],
      ),
    );
  }
}
