import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../core/kasat_config.dart';
import '../../core/tracking_id.dart';
import '../../models/approx_location.dart';
import '../../models/attachment.dart';
import '../../models/incident.dart';
import '../../models/incident_category.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/k_field.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/mono_badge.dart';
import '../../widgets/panel.dart';
import 'receipt_view.dart';
import 'widgets/category_sheet.dart';
import 'widgets/location_picker.dart';
import 'widgets/media_dropzone.dart';
import 'widgets/transmit_overlay.dart';

class ReportFormView extends StatefulWidget {
  const ReportFormView({super.key, required this.onTrackRequested});

  final ValueChanged<String> onTrackRequested;

  @override
  State<ReportFormView> createState() => _ReportFormViewState();
}

class _ReportFormViewState extends State<ReportFormView> {
  final _description = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _note = TextEditingController();
  final _picker = ImagePicker();

  IncidentCategory? _category;
  LocationPrecision _precision = LocationPrecision.district;
  ApproxLocation? _location;
  List<Attachment> _attachments = [];
  bool _pickingMedia = false;
  bool _submitting = false;

  @override
  void dispose() {
    _description.dispose();
    _lat.dispose();
    _lng.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _charCount => _description.text.characters.length;
  bool get _descriptionOk => _description.text.trim().length >= KasatConfig.descriptionMinLength;
  bool get _canSubmit => _category != null && _descriptionOk && !_submitting;

  void _recomputeLocation() {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());

    final valid = lat != null &&
        lng != null &&
        ApproxLocation.isValidLatitude(lat) &&
        ApproxLocation.isValidLongitude(lng);

    setState(() {
      _location = valid
          ? ApproxLocation.snapped(
              latitude: lat,
              longitude: lng,
              precision: _precision,
              note: _note.text,
            )
          : null;
    });
  }

  Future<void> _pickMedia() async {
    final store = KasatScope.of(context).attachments;
    setState(() => _pickingMedia = true);
    try {
      final picked = await _picker.pickMultiImage(limit: KasatConfig.maxAttachments);
      if (picked.isEmpty) return;

      final room = KasatConfig.maxAttachments - _attachments.length;
      final added = <Attachment>[];

      for (final file in picked.take(room)) {
        final bytes = await file.readAsBytes();
        added.add(
          await store.persistImage(bytes, index: _attachments.length + added.length),
        );
      }

      if (!mounted) return;
      setState(() => _attachments = [..._attachments, ...added]);
    } catch (_) {
      if (!mounted) return;
      _toast('Attachment could not be processed. Nothing was stored.', error: true);
    } finally {
      if (mounted) setState(() => _pickingMedia = false);
    }
  }

  Future<void> _removeAttachment(Attachment attachment) async {
    await KasatScope.of(context).attachments.delete(attachment);
    if (!mounted) return;
    setState(() => _attachments = _attachments.where((a) => a.id != attachment.id).toList());
  }

  Future<void> _submit() async {
    final category = _category;
    if (category == null || !_descriptionOk) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    // Minted here, on the handset. The backend receives an identifier it had
    // no part in choosing and cannot map back to a person.
    final trackingId = TrackingId.generate();

    final draft = IncidentDraft(
      category: category,
      description: _description.text,
      priority: category.defaultPriority,
      location: _location,
      attachments: _attachments,
    );

    final incident = await runTransmit(
      context,
      KasatScope.of(context).repository.submit(draft, trackingId: trackingId),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (incident == null) {
      _toast('Transmission failed. Your report was not sent.', error: true);
      return;
    }

    _resetForm();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReceiptView(
          incident: incident,
          onTrack: () => widget.onTrackRequested(incident.trackingId),
        ),
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _category = null;
      _description.clear();
      _lat.clear();
      _lng.clear();
      _note.clear();
      _location = null;
      _attachments = [];
      _precision = LocationPrecision.district;
    });
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: KC.surfaceHi,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: error ? KC.danger : KC.border),
        ),
        content: Text(
          message,
          style: KType.mono(size: 11, color: error ? KC.danger : KC.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.md, KSpace.md, KSpace.xl),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              const _IntakeHeader(),
              const SizedBox(height: KSpace.md),
              KPanel(
                index: '01',
                title: 'Incident classification',
                trailing: const MonoBadge('REQUIRED', color: KC.accent, size: 9, dense: true),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KSelectField(
                      value: category?.label,
                      placeholder: 'Select incident type',
                      onTap: () async {
                        final picked = await showCategorySheet(context, current: category);
                        if (picked != null) setState(() => _category = picked);
                      },
                    ),
                    if (category != null) ...[
                      const SizedBox(height: KSpace.sm),
                      Row(
                        children: [
                          MonoBadge(category.code, size: 9, dense: true),
                          const SizedBox(width: 6),
                          MonoBadge(
                            'PRIORITY ${category.defaultPriority.code}',
                            color: category.defaultPriority.color,
                            filled: true,
                            size: 9,
                            dense: true,
                          ),
                          const Spacer(),
                          Text('AUTO-DERIVED', style: KType.mono(size: 8.5, color: KC.faint)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: KSpace.md),
              KPanel(
                index: '02',
                title: 'What happened',
                trailing: _Counter(count: _charCount, ok: _descriptionOk),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KTextField(
                      controller: _description,
                      hint: 'Describe what happened, when, and who was involved. '
                          'Leave out anything that would identify you unless it '
                          'is essential to the case.',
                      minLines: 6,
                      maxLines: 12,
                      maxLength: KasatConfig.descriptionMaxLength,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Minimum ${KasatConfig.descriptionMinLength} characters. '
                      'Nothing here is analysed or indexed before an officer opens it.',
                      style: KType.sans(size: 10.5, color: KC.faint, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KSpace.md),
              KPanel(
                index: '03',
                title: 'Evidence',
                trailing: MonoBadge(
                  '${_attachments.length}/${KasatConfig.maxAttachments}',
                  color: _attachments.isEmpty ? KC.faint : KC.accent,
                  size: 9,
                  dense: true,
                ),
                child: MediaDropzone(
                  attachments: _attachments,
                  busy: _pickingMedia,
                  onAdd: _pickMedia,
                  onRemove: _removeAttachment,
                ),
              ),
              const SizedBox(height: KSpace.md),
              KPanel(
                index: '04',
                title: 'Approximate location',
                trailing: const MonoBadge('OPTIONAL', size: 9, dense: true, color: KC.faint),
                child: LocationPicker(
                  latController: _lat,
                  lngController: _lng,
                  noteController: _note,
                  precision: _precision,
                  resolved: _location,
                  onPrecisionChanged: (p) {
                    setState(() => _precision = p);
                    _recomputeLocation();
                  },
                  onChanged: _recomputeLocation,
                ),
              ),
            ],
          ),
        ),
        _SubmitBar(
          enabled: _canSubmit,
          busy: _submitting,
          category: category,
          descriptionOk: _descriptionOk,
          onSubmit: _submit,
        ),
      ],
    );
  }
}

class _IntakeHeader extends StatelessWidget {
  const _IntakeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Anonymous intake',
                style: KType.sans(size: 19, weight: FontWeight.w800, tracking: -0.4),
              ),
              const SizedBox(height: 3),
              Text(
                'Four fields. No account, no contact details, no device identifiers.',
                style: KType.sans(size: 11.5, color: KC.muted, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(width: KSpace.sm),
        const MonoBadge('E2E', color: KC.accent, filled: true, size: 9),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.count, required this.ok});

  final int count;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final over = count > KasatConfig.descriptionMaxLength;
    final color = over ? KC.danger : (ok ? KC.accent : KC.faint);
    return Text(
      '$count / ${KasatConfig.descriptionMaxLength}',
      style: KType.mono(size: 9.5, weight: FontWeight.w700, color: color, tracking: 0.5),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.enabled,
    required this.busy,
    required this.category,
    required this.descriptionOk,
    required this.onSubmit,
  });

  final bool enabled;
  final bool busy;
  final IncidentCategory? category;
  final bool descriptionOk;
  final VoidCallback onSubmit;

  String get _blocker {
    if (category == null) return 'SELECT A CLASSIFICATION TO CONTINUE';
    if (!descriptionOk) {
      return 'DESCRIPTION NEEDS ${KasatConfig.descriptionMinLength}+ CHARACTERS';
    }
    return 'PAYLOAD READY · IDENTIFIER MINTED ON SEND';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(KSpace.md, KSpace.sm, KSpace.md, KSpace.sm),
      decoration: const BoxDecoration(
        color: KC.surface,
        border: Border(top: BorderSide(color: KC.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                enabled ? Icons.lock_outline_rounded : Icons.info_outline_rounded,
                size: 12,
                color: enabled ? KC.accent : KC.faint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _blocker,
                  style: KType.mono(
                    size: 9,
                    weight: FontWeight.w700,
                    color: enabled ? KC.accent : KC.faint,
                    tracking: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpace.sm),
          KButton(
            label: 'Transmit report',
            icon: Icons.send_rounded,
            busy: busy,
            onPressed: enabled ? onSubmit : null,
          ),
        ],
      ),
    );
  }
}
