import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../core/crisis_detection.dart';
import '../../core/kasat_config.dart';
import '../../core/tracking_id.dart';
import '../../models/approx_location.dart';
import '../../models/attachment.dart';
import '../../models/incident.dart';
import '../../models/incident_category.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/k_field.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_badge.dart';
import '../crisis/quiet_support_banner.dart';
import 'receipt_view.dart';
import 'widgets/category_sheet.dart';
import 'widgets/crisis_banner.dart';
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
  final _landmark = TextEditingController();
  final _picker = ImagePicker();

  IncidentCategory? _category;
  String? _selectedSubCity;
  ApproxLocation? _location;
  List<Attachment> _attachments = [];
  bool _pickingMedia = false;
  bool _submitting = false;
  KasatScope? _registeredScope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = KasatScope.of(context);
    if (_registeredScope != scope) {
      _registeredScope?.unregisterWipeCallback(_wipeFormState);
      _registeredScope = scope;
      scope.registerWipeCallback(_wipeFormState);
    }
  }

  @override
  void dispose() {
    _registeredScope?.unregisterWipeCallback(_wipeFormState);
    _description.dispose();
    _landmark.dispose();
    super.dispose();
  }

  void _wipeFormState() {
    _description.clear();
    _landmark.clear();
    if (mounted) {
      setState(() {
        _category = null;
        _selectedSubCity = null;
        _location = null;
        _attachments = [];
      });
    }
  }

  int get _charCount => _description.text.characters.length;
  bool get _descriptionOk =>
      _description.text.trim().length >= KasatConfig.descriptionMinLength;
  bool get _canSubmit => _category != null && _descriptionOk && !_submitting;

  /// Runs on every keystroke, entirely on this device, against text that has
  /// not been sent anywhere.
  CrisisSignal get _crisis => CrisisDetection.evaluate(
        category: _category,
        description: _description.text,
      );

  void _recomputeLocation() {
    setState(() {
      _location = ApproxLocation.fromSubCityAndLandmark(
        subCity: _selectedSubCity,
        landmark: _landmark.text,
      );
    });
  }

  Future<void> _pickMedia() async {
    final store = KasatScope.of(context).attachments;
    setState(() => _pickingMedia = true);
    try {
      final picked =
          await _picker.pickMultiImage(limit: KasatConfig.maxAttachments);
      if (picked.isEmpty) return;

      final room = KasatConfig.maxAttachments - _attachments.length;
      final added = <Attachment>[];

      for (final file in picked.take(room)) {
        final bytes = await file.readAsBytes();
        added.add(
          await store.persistImage(
            bytes,
            index: _attachments.length + added.length,
          ),
        );
      }

      if (!mounted) return;
      setState(() => _attachments = [..._attachments, ...added]);
    } catch (_) {
      if (!mounted) return;
      _toast('That photo could not be added. Nothing was saved.', error: true);
    } finally {
      if (mounted) setState(() => _pickingMedia = false);
    }
  }

  Future<void> _removeAttachment(Attachment attachment) async {
    await KasatScope.of(context).attachments.delete(attachment);
    if (!mounted) return;
    setState(
      () => _attachments =
          _attachments.where((a) => a.id != attachment.id).toList(),
    );
  }

  Future<void> _submit() async {
    final category = _category;
    if (category == null || !_descriptionOk) return;

    final scope = KasatScope.of(context);
    final countryCode = scope.settings.effectiveCountryCode;

    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);

    // Minted here, on the handset. The backend receives a code it had no part
    // in choosing and cannot map back to a person.
    // Issue 3 safety rule: Show the tracking code on a screen that insists she
    // write it down BEFORE any PIN is set.
    final trackingId = TrackingId.generate();
    final offline = !await scope.network.isOnline();
    if (!mounted) return;

    final draft = IncidentDraft(
      category: category,
      description: _description.text,
      priority: category.defaultPriority,
      countryCode: countryCode,
      location: _location,
      attachments: _attachments,
    );

    final incident = await runTransmit(
      context,
      scope.repository.submit(draft, trackingId: trackingId, offline: offline),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (incident == null) {
      _toast('That did not send. Nothing has been submitted.', error: true);
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
      _selectedSubCity = null;
      _landmark.clear();
      _location = null;
      _attachments = [];
    });
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? KC.urgent : KC.text,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(KSpace.lg),
        shape: const RoundedRectangleBorder(borderRadius: KRadius.rMd),
        content: Text(
          message,
          style: KType.sans(size: 14, color: Colors.white, height: 1.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    final countryCode = KasatScope.of(context).settings.effectiveCountryCode;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              KSpace.lg,
              KSpace.xs,
              KSpace.lg,
              KSpace.xxl,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text(
                'Take your time. You can leave anything out.',
                style: KType.sans(size: 14, color: KC.muted, height: 1.5),
              ),
              const SizedBox(height: KSpace.lg),
              KPanel(
                step: 1,
                title: 'What kind of thing happened?',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KSelectField(
                      value: category?.label,
                      placeholder: 'Choose one',
                      onTap: () async {
                        final picked =
                            await showCategorySheet(context, current: category);
                        if (picked != null) setState(() => _category = picked);
                      },
                    ),
                    if (category != null) ...[
                      const SizedBox(height: KSpace.md),
                      Row(
                        children: [
                          SoftBadge(
                            '${category.defaultPriority.label} priority',
                            color: category.defaultPriority.color,
                            dense: true,
                            size: 12,
                          ),
                          const SizedBox(width: KSpace.sm),
                          Expanded(
                            child: Text(
                              'Set from what you chose',
                              style: KType.sans(size: 12.5, color: KC.faint),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: KSpace.md),
              KPanel(
                step: 2,
                title: 'What happened?',
                trailing: _Counter(count: _charCount, ok: _descriptionOk),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KTextField(
                      controller: _description,
                      hint: 'You can write as much or as little as you want. '
                          'Leave out anything that would point back to you '
                          'unless it matters to the case.',
                      minLines: 6,
                      maxLines: 12,
                      maxLength: KasatConfig.descriptionMaxLength,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: KSpace.sm),
                    Text(
                      'At least ${KasatConfig.descriptionMinLength} characters. '
                      'Nobody reads this until an officer opens your case.',
                      style: KType.sans(
                        size: 12.5,
                        color: KC.faint,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (_crisis.triggered) ...[
                const SizedBox(height: KSpace.md),
                const QuietSupportBanner(visible: true),
                CrisisBanner(signal: _crisis, countryCode: countryCode),
              ],
              const SizedBox(height: KSpace.md),
              KPanel(
                step: 3,
                title: 'Anything to show?',
                subtitle:
                    'Photos are optional. Metadata is stripped and a SHA-256 integrity hash is recorded.',
                trailing: _attachments.isEmpty
                    ? null
                    : SoftBadge(
                        '${_attachments.length} of ${KasatConfig.maxAttachments}',
                        color: KC.primary,
                        dense: true,
                        size: 11.5,
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
                step: 4,
                title: 'Where did it happen?',
                subtitle: 'Sub-city and landmark are both optional. You can skip both.',
                child: LocationPicker(
                  selectedSubCity: _selectedSubCity,
                  onSubCityChanged: (sub) {
                    setState(() => _selectedSubCity = sub);
                    _recomputeLocation();
                  },
                  landmarkController: _landmark,
                  resolved: _location,
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

class _Counter extends StatelessWidget {
  const _Counter({required this.count, required this.ok});

  final int count;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final over = count > KasatConfig.descriptionMaxLength;
    final color = over ? KC.urgent : (ok ? KC.calm : KC.faint);
    return Text(
      '$count',
      style: KType.sans(size: 13, weight: FontWeight.w600, color: color),
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

  String get _hint {
    if (category == null) return 'Choose what kind of thing happened to continue';
    if (!descriptionOk) {
      return 'A little more detail — at least '
          '${KasatConfig.descriptionMinLength} characters';
    }
    return 'Ready. Your private code is created when you save.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(KSpace.lg, KSpace.md, KSpace.lg, KSpace.sm),
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
                enabled
                    ? Icons.lock_outline_rounded
                    : Icons.info_outline_rounded,
                size: 15,
                color: enabled ? KC.calm : KC.faint,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _hint,
                  style: KType.sans(
                    size: 12.5,
                    color: enabled ? KC.muted : KC.faint,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpace.md),
          KButton(
            label: 'Save report',
            icon: Icons.save_outlined,
            busy: busy,
            onPressed: enabled ? onSubmit : null,
          ),
        ],
      ),
    );
  }
}
