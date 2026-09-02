import 'package:flutter/material.dart';

import '../../theme/kasat_theme.dart';
import '../../widgets/soft_backdrop.dart';

/// Shared chrome for optional screens opened from More. Same back row as
/// Settings so those pages feel like the rest of Kasat.
class MoreScaffold extends StatelessWidget {
  const MoreScaffold({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KC.canvas,
      body: SoftBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KSpace.sm,
                  KSpace.sm,
                  KSpace.xl,
                  0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: KC.muted,
                    ),
                    Expanded(child: Text(title, style: KType.serif(size: 22))),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(KSpace.xl),
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
