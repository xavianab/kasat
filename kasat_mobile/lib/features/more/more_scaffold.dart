import 'package:flutter/material.dart';

import '../../theme/kasat_theme.dart';
import '../../widgets/soft_backdrop.dart';

/// Shared chrome for optional screens opened from More.
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
              Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpace.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: KC.canvas,
                  border: Border(bottom: BorderSide(color: KC.border)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back_rounded),
                      color: KC.muted,
                    ),
                    Expanded(child: Text(title, style: KType.serif(size: 18))),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(KSpace.lg),
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
