import 'package:flutter/material.dart';

import '../../theme/kasat_theme.dart';
import '../../widgets/kasat_button.dart';
import '../../widgets/kasat_mark.dart';

class FirstLaunchIntro extends StatefulWidget {
  const FirstLaunchIntro({
    super.key,
    required this.onComplete,
  });

  static const skipButtonKey = Key('intro-skip-button');
  static const nextButtonKey = Key('intro-next-button');

  final VoidCallback onComplete;

  static const cards = <(IconData, String, String)>[
    (
      Icons.shield_outlined,
      'You stay anonymous',
      'No name, phone number, or account is needed to send a report.',
    ),
    (
      Icons.lock_outline_rounded,
      'You choose who sees it',
      'Save a draft on your phone, or send it to the station when you are ready.',
    ),
    (
      Icons.chat_bubble_outline_rounded,
      'Someone answers',
      'Check your case status and read replies using your private code.',
    ),
  ];

  @override
  State<FirstLaunchIntro> createState() => _FirstLaunchIntroState();
}

class _FirstLaunchIntroState extends State<FirstLaunchIntro> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < FirstLaunchIntro.cards.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == FirstLaunchIntro.cards.length - 1;

    return Scaffold(
      backgroundColor: KC.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpace.lg,
            vertical: KSpace.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const KasatMark(size: 24),
                  const SizedBox(width: KSpace.sm),
                  Expanded(
                    child: Text(
                      'Kasat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KType.sans(size: 16, weight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    key: FirstLaunchIntro.skipButtonKey,
                    onPressed: widget.onComplete,
                    child: Text(
                      'Skip',
                      style: KType.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: KC.muted,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: FirstLaunchIntro.cards.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final (icon, title, body) = FirstLaunchIntro.cards[i];
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: KSpace.lg),
                        child: Container(
                          padding: const EdgeInsets.all(KSpace.xl),
                          decoration: BoxDecoration(
                            color: KC.surface,
                            borderRadius: KRadius.rMd,
                            border: Border.all(color: KC.border),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, size: 28, color: KC.primary),
                              const SizedBox(height: KSpace.lg),
                              Text(
                                title,
                                style: KType.serif(
                                  size: 20,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: KSpace.sm),
                              Text(
                                body,
                                style: KType.sans(
                                  size: 14.5,
                                  color: KC.muted,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < FirstLaunchIntro.cards.length; i++)
                    Container(
                      width: i == _index ? 18 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _index ? KC.primary : KC.border,
                        borderRadius: KRadius.rPill,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: KSpace.lg),
              KButton(
                key: FirstLaunchIntro.nextButtonKey,
                label: last ? 'Continue' : 'Next',
                compact: true,
                onPressed: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
