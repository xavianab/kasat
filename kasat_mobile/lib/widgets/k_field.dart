import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/kasat_theme.dart';

/// Small uppercase caption that sits above every input.
class KFieldLabel extends StatelessWidget {
  const KFieldLabel(this.text, {super.key, this.required = false, this.trailing});

  final String text;
  final bool required;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(text.toUpperCase(), style: KType.label(size: 9.5)),
          if (required) ...[
            const SizedBox(width: 4),
            Text('*', style: KType.mono(size: 10, color: KC.accent, weight: FontWeight.w700)),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Bordered text input. Wraps [TextField] so every field on the client shares
/// one border radius, one focus colour, and one text style.
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
    this.mono = false,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool mono;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
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
    final style = widget.mono
        ? KType.mono(size: 13, weight: FontWeight.w600, height: 1.4)
        : KType.sans(size: 13.5, height: 1.45);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: KC.canvas,
        border: Border.all(color: _focus.hasFocus ? KC.accent : KC.border),
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
        textAlign: widget.textAlign,
        textCapitalization: widget.textCapitalization,
        cursorWidth: 1.5,
        cursorRadius: Radius.zero,
        style: style,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: widget.hint,
          hintStyle: widget.mono
              ? KType.mono(size: 13, color: KC.faint)
              : KType.sans(size: 13.5, color: KC.faint),
          counterText: '',
        ),
      ),
    );
  }
}

/// Dropdown-style trigger: reads like a field, opens a sheet on tap.
class KSelectField extends StatelessWidget {
  const KSelectField({
    super.key,
    required this.value,
    required this.onTap,
    this.leading,
    this.placeholder = 'Select…',
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: KC.canvas,
          border: Border.all(color: empty ? KC.border : KC.borderHi),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: KSpace.sm)],
            Expanded(
              child: Text(
                value ?? placeholder,
                style: KType.sans(
                  size: 13.5,
                  weight: FontWeight.w600,
                  color: empty ? KC.faint : KC.text,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 18, color: KC.muted),
          ],
        ),
      ),
    );
  }
}

/// Compact segmented control for small, mutually exclusive option sets.
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
        color: KC.canvas,
        border: Border.all(color: KC.border),
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.all(2),
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
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: option == value
                        ? KC.accent.withValues(alpha: 0.14)
                        : Colors.transparent,
                    border: Border.all(
                      color: option == value ? KC.accent : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    labelOf(option).toUpperCase(),
                    style: KType.mono(
                      size: 9.5,
                      weight: FontWeight.w700,
                      color: option == value ? KC.accent : KC.muted,
                      tracking: 0.8,
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
