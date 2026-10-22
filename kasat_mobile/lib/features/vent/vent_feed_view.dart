import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/crisis_detection.dart';
import '../../core/kasat_config.dart';
import '../../theme/kasat_theme.dart';
import '../../widgets/k_field.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/panel.dart';
import '../../widgets/soft_backdrop.dart';
import '../../widgets/soft_badge.dart';
import '../crisis/quiet_support_banner.dart';
import 'vent_companion.dart';
import 'vent_models.dart';

class VentFeedView extends StatefulWidget {
  const VentFeedView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<VentFeedView> createState() => _VentFeedViewState();
}

class _VentFeedViewState extends State<VentFeedView> {
  StreamSubscription<void>? _sub;
  List<VentPost> _posts = const [];

  String get _token => KasatScope.of(context).settings.posterToken();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bind());
  }

  void _bind() {
    final vents = KasatScope.of(context).vents;
    _sub = vents.watch().listen((_) => _reload());
    _reload();
  }

  Future<void> _reload() async {
    final posts = await KasatScope.of(context).vents.liveFeed();
    if (mounted) setState(() => _posts = posts);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _expiry(VentPost post) {
    final i18n = KasatScope.of(context).i18n;
    final left = post.remaining;
    if (left.inDays >= 2) {
      return i18n.t('vent.expires', {'days': '${left.inDays}'});
    }
    if (left.inDays >= 1) return i18n.t('vent.expiresOne');
    final hours = left.inHours.clamp(1, 23);
    return i18n.t('vent.expiresHours', {'hours': '$hours'});
  }

  @override
  Widget build(BuildContext context) {
    final i18n = KasatScope.of(context).i18n;
    final list = ListView(
      padding: EdgeInsets.fromLTRB(
        KSpace.xl,
        widget.embedded ? KSpace.xs : KSpace.xl,
        KSpace.xl,
        KSpace.xl,
      ),
      children: [
        Text(
          i18n.t('vent.blurb'),
          style: KType.sans(size: 14.5, color: KC.muted, height: 1.55),
        ),
        const SizedBox(height: KSpace.lg),
        KButton(
          label: i18n.t('vent.compose'),
          icon: Icons.edit_outlined,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const _ComposeVent()),
          ),
        ),
        const SizedBox(height: KSpace.xl),
        if (_posts.isEmpty)
          Text(i18n.t('vent.empty'), style: KType.sans(color: KC.muted))
        else
          for (final post in _posts) ...[
            _PostCard(
              post: post,
              mine: post.authorToken == _token,
              expiry: _expiry(post),
              onOpen: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _VentDetail(postId: post.id),
                ),
              ),
            ),
            const SizedBox(height: KSpace.md),
          ],
      ],
    );

    if (widget.embedded) return list;

    return Scaffold(
      backgroundColor: KC.canvas,
      body: SoftBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(KSpace.sm, KSpace.sm, KSpace.xl, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: KC.muted,
                    ),
                    Expanded(child: Text(i18n.t('vent.title'), style: KType.serif(size: 22))),
                  ],
                ),
              ),
              Expanded(child: list),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.mine,
    required this.expiry,
    required this.onOpen,
  });

  final VentPost post;
  final bool mine;
  final String expiry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final i18n = KasatScope.of(context).i18n;
    final preview = post.body.length > 140 ? '${post.body.substring(0, 140)}…' : post.body;
    return Material(
      color: KC.surface,
      borderRadius: KRadius.rLg,
      child: InkWell(
        borderRadius: KRadius.rLg,
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(KSpace.lg),
          decoration: BoxDecoration(
            borderRadius: KRadius.rLg,
            border: Border.all(color: KC.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(post.displayIdentity, style: KType.sans(size: 14, weight: FontWeight.w600)),
                  const Spacer(),
                  Text(expiry, style: KType.sans(size: 11.5, color: KC.faint)),
                ],
              ),
              const SizedBox(height: KSpace.sm),
              Text(preview, style: KType.sans(size: 14.5, height: 1.45)),
              const SizedBox(height: KSpace.sm),
              Wrap(
                spacing: KSpace.sm,
                runSpacing: 6,
                children: [
                  if (post.replyCount > 0)
                    SoftBadge(
                      i18n.t(
                        post.replyCount == 1 ? 'vent.repliedOne' : 'vent.replied',
                        {'count': '${post.replyCount}'},
                      ),
                      color: KC.primary,
                      dense: true,
                    ),
                  if (post.supportCount > 0)
                    SoftBadge(
                      i18n.t('vent.supported', {'count': '${post.supportCount}'}),
                      color: KC.secondary,
                      dense: true,
                    ),
                  if (mine) SoftBadge('yours', color: KC.calm, dense: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposeVent extends StatefulWidget {
  const _ComposeVent();

  @override
  State<_ComposeVent> createState() => _ComposeVentState();
}

class _ComposeVentState extends State<_ComposeVent> {
  final _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _body.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final scope = KasatScope.of(context);
    try {
      final post = await scope.vents.createPost(
        body: text,
        authorToken: scope.settings.posterToken(),
      );
      // Fire once, after a short pause. Failures are silent.
      Future<void>.delayed(KasatConfig.ventCompanionDelay, () {
        VentCompanion().maybeReply(vents: scope.vents, post: post);
      });
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = KasatScope.of(context).i18n;
    final crisis = CrisisDetection.evaluateText(_body.text);
    return Scaffold(
      backgroundColor: KC.canvas,
      body: SoftBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(KSpace.xl),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: KC.muted,
                  ),
                  Text(i18n.t('vent.compose'), style: KType.serif(size: 22)),
                ],
              ),
              const SizedBox(height: KSpace.lg),
              QuietSupportBanner(visible: crisis.triggered),
              KTextField(
                controller: _body,
                hint: i18n.t('vent.postHint'),
                maxLines: 8,
                minLines: 5,
                maxLength: KasatConfig.ventBodyMax,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: KSpace.lg),
              KButton(
                label: i18n.t('vent.post'),
                busy: _busy,
                onPressed: _body.text.trim().isEmpty ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VentDetail extends StatefulWidget {
  const _VentDetail({required this.postId});

  final String postId;

  @override
  State<_VentDetail> createState() => _VentDetailState();
}

class _VentDetailState extends State<_VentDetail> {
  final _reply = TextEditingController();
  VentPost? _post;
  List<VentReply> _private = const [];
  StreamSubscription<void>? _sub;

  String get _token => KasatScope.of(context).settings.posterToken();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sub = KasatScope.of(context).vents.watch().listen((_) => _load());
      _load();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final scope = KasatScope.of(context);
    final feed = await scope.vents.liveFeed();
    VentPost? post;
    for (final p in feed) {
      if (p.id == widget.postId) {
        post = p;
      }
    }
    final private = post == null
        ? const <VentReply>[]
        : await scope.vents.privateRepliesForPoster(
            postId: post.id,
            authorToken: _token,
          );
    if (mounted) {
      setState(() {
        _post = post;
        _private = private;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final i18n = KasatScope.of(context).i18n;
    return Scaffold(
      backgroundColor: KC.canvas,
      body: SoftBackdrop(
        child: SafeArea(
          child: post == null
              ? Center(child: Text(i18n.t('vent.empty'), style: KType.sans(color: KC.muted)))
              : ListView(
                  padding: const EdgeInsets.all(KSpace.xl),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: KC.muted,
                        ),
                        Text(post.displayIdentity, style: KType.serif(size: 22)),
                      ],
                    ),
                    const SizedBox(height: KSpace.lg),
                    QuietSupportBanner(
                      visible: CrisisDetection.evaluateText(post.body).triggered,
                    ),
                    Text(post.body, style: KType.sans(size: 16, height: 1.5)),
                    const SizedBox(height: KSpace.lg),
                    if (post.authorToken != _token) ...[
                      KButton(
                        label: i18n.t('vent.support'),
                        kind: KButtonKind.soft,
                        onPressed: () => KasatScope.of(context).vents.support(
                              postId: post.id,
                              fromAuthorToken: _token,
                            ),
                      ),
                      const SizedBox(height: KSpace.md),
                      KFieldLabel(i18n.t('vent.reply')),
                      KTextField(
                        controller: _reply,
                        hint: i18n.t('vent.replyHint'),
                        maxLines: 4,
                        minLines: 2,
                      ),
                      const SizedBox(height: KSpace.sm),
                      KButton(
                        label: i18n.t('vent.reply'),
                        kind: KButtonKind.secondary,
                        compact: true,
                        onPressed: _reply.text.trim().isEmpty
                            ? null
                            : () async {
                                await KasatScope.of(context).vents.reply(
                                      postId: post.id,
                                      fromAuthorToken: _token,
                                      body: _reply.text,
                                    );
                                _reply.clear();
                                setState(() {});
                              },
                      ),
                    ],
                    if (post.authorToken == _token) ...[
                      Text(
                        i18n.t('vent.readReplies'),
                        style: KType.serif(size: 18),
                      ),
                      const SizedBox(height: KSpace.sm),
                      if (_private.isEmpty)
                        Text(i18n.t('vent.empty'), style: KType.sans(color: KC.muted))
                      else
                        for (final reply in _private) ...[
                          KPanel(
                            title: reply.fromDisplayIdentity,
                            trailing: reply.isKasatCompanion
                                ? SoftBadge(i18n.t('vent.companionTag'), color: KC.primary, dense: true)
                                : null,
                            child: Text(reply.body, style: KType.sans(size: 14.5, height: 1.45)),
                          ),
                          const SizedBox(height: KSpace.md),
                        ],
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
