import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/kasat_theme.dart';

/// Caption above an input.
class KFieldLabel extends StatelessWidget {
  const KFieldLabel(this.text, {super.key, this.optional = false, this.trailing});

  final String text;
  final bool optional;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.sm),
      child: Row(
        children: [
          Text(text, style: KType.label()),
          if (optional) ...[
            const SizedBox(width: 6),
            Text('optional', style: KType.sans(size: 11.5, color: KC.faint)),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Rounded text input on a warm inset well.
class KTextField extends StatefulWidget {
  const KTextField({
    super.key,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.code = false,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.obscureText = false,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  /// Renders the value in the tracking-code face.
  final bool code;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  @override
  State<KTextField> createState() => _KTextFieldState();
}

class _KTextFieldState extends State<KTextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.code
        ? KType.code(size: 16, weight: FontWeight.w600)
        : KType.sans(size: 15, height: 1.5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _focus.hasFocus ? KC.surface : KC.surfaceAlt,
        border: Border.all(color: _focus.hasFocus ? KC.primary : KC.border, width: 1.4),
        borderRadius: KRadius.rSm,
      ),
      padding: const EdgeInsets.symmetric(horizontal: KSpace.md, vertical: KSpace.md),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        maxLines: widget.obscureText ? 1 : widget.maxLines,
        minLines: widget.minLines,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
        textAlign: widget.textAlign,
        obscureText: widget.obscureText,
        autofocus: widget.autofocus,
        textCapitalization: widget.textCapitalization,
        cursorWidth: 2,
        cursorRadius: const Radius.circular(2),
        style: style,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: widget.hint,
          hintStyle: widget.code
              ? KType.code(size: 16, color: KC.faint)
              : KType.sans(size: 15, color: KC.faint),
          counterText: '',
        ),
      ),
    );
  }
}

/// Reads like a field, opens a sheet on tap.
class KSelectField extends StatelessWidget {
  const KSelectField({
    super.key,
    required this.value,
    required this.onTap,
    this.leading,
    this.placeholder = 'Choose…',
  });

  final String? value;
  final VoidCallback onTap;
  final Widget? leading;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final empty = value == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: KSpace.md, vertical: 15),
        decoration: BoxDecoration(
          color: KC.surfaceAlt,
          border: Border.all(color: empty ? KC.border : KC.borderStrong, width: 1.4),
          borderRadius: KRadius.rSm,
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: KSpace.md)],
            Expanded(
              child: Text(
                value ?? placeholder,
                style: KType.sans(
                  size: 15,
                  weight: empty ? FontWeight.w400 : FontWeight.w600,
                  color: empty ? KC.faint : KC.text,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 22, color: KC.muted),
          ],
        ),
      ),
    );
  }
}

/// Soft segmented control.
class KSegmented<T> extends StatelessWidget {
  const KSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> options;
  final T value;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KC.surfaceAlt,
        border: Border.all(color: KC.border, width: 1.4),
        borderRadius: KRadius.rMd,
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(option);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: option == value ? KC.primary : Colors.transparent,
                    borderRadius: KRadius.rSm,
                  ),
                  child: Text(
                    labelOf(option),
                    style: KType.sans(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: option == value ? Colors.white : KC.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
