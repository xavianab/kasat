import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/kasat_config.dart';
import '../../../models/attachment.dart';
import '../../../theme/kasat_theme.dart';
import '../../../widgets/soft_backdrop.dart';
import '../../../widgets/soft_badge.dart';

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
          opacity: _full ? 0.45 : 1,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: (_full || busy) ? null : onAdd,
            child: DashedBorder(
              color: busy ? KC.primary : KC.borderStrong,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: KSpace.xl, horizontal: KSpace.lg),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: KC.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: KC.primary),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined,
                              size: 22, color: KC.primary),
                    ),
                    const SizedBox(height: KSpace.md),
                    Text(
                      busy ? 'Cleaning your photos…' : 'Add a photo',
                      style: KType.sans(
                        size: 15,
                        weight: FontWeight.w600,
                        color: busy ? KC.primary : KC.text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Where the photo was taken, and which camera took it, '
                      'are removed on this phone before it is saved.',
                      textAlign: TextAlign.center,
                      style: KType.sans(size: 12.5, color: KC.muted, height: 1.45),
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
      padding: const EdgeInsets.all(KSpace.sm),
      decoration: BoxDecoration(
        color: KC.surfaceAlt,
        borderRadius: KRadius.rMd,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: KRadius.rSm,
            child: SizedBox(
              width: 46,
              height: 46,
              child: attachment.isImage
                  ? Image.file(File(attachment.storagePath), fit: BoxFit.cover)
                  : Container(
                      color: KC.border,
                      child: const Icon(Icons.description_outlined, size: 18),
                    ),
            ),
          ),
          const SizedBox(width: KSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Photo ${attachment.label.split('-').last}',
                  style: KType.sans(size: 14, weight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  attachment.sizeLabel,
                  style: KType.sans(size: 12.5, color: KC.muted),
                ),
              ],
            ),
          ),
          if (attachment.strippedMetadata)
            const SoftBadge('Cleaned', color: KC.calm, dense: true, size: 11.5),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: KC.faint,
          ),
        ],
      ),
    );
  }
}
