import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/kasat_theme.dart';
import 'kasat_mark.dart';

/// Flower mark fades and scales in, then the home underneath is shown.
/// The safety bar sits above this widget, so it stays visible and tappable.
class OpeningBloom extends StatefulWidget {
  const OpeningBloom({super.key, required this.child});

  final Widget child;

  @override
  State<OpeningBloom> createState() => _OpeningBloomState();
}

class _OpeningBloomState extends State<OpeningBloom>
    with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('app.kasat/privacy');

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  bool _show = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _show = false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final danger = await _openedFromDanger();
    if (!mounted || reduce || danger) return;
    setState(() => _show = true);
    await _controller.forward();
  }

  Future<bool> _openedFromDanger() async {
    try {
      return await _channel.invokeMethod<bool>('launchIsDanger') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_show)
          Positioned.fill(
            child: ColoredBox(
              color: KC.canvas,
              child: Center(
                child: FadeTransition(
                  opacity: _controller,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1).animate(
                      CurvedAnimation(
                        parent: _controller,
                        curve: Curves.easeOut,
                      ),
                    ),
                    child: const KasatMark(size: 72),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
