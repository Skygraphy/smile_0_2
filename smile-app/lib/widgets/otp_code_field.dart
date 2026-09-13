import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A 6-box one-time-code input. A single real (invisible) `TextField`
/// drives the value -- so paste, autofill, and the numeric keyboard all
/// just work -- while 6 separate boxes render the digits on top, per the
/// user's explicit request for individual code boxes instead of one
/// plain text field. Deliberately no borders (project_ui-redesign-concepts'
/// "no decorative flourishes" ground rule): the active box is shown via a
/// tinted fill, not an outline.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChange);
    _focusNode.addListener(_handleChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChange() {
    if (!mounted) return;
    setState(() {});
    final value = widget.controller.text;
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;
    const boxWidth = 40.0;
    const boxHeight = 52.0;
    const gap = 8.0;
    final totalWidth = widget.length * boxWidth + (widget.length - 1) * gap;

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: SizedBox(
        width: totalWidth,
        height: boxHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  _CodeBox(
                    width: boxWidth,
                    height: boxHeight,
                    char: i < value.length ? value[i] : '',
                    isActive: _focusNode.hasFocus && i == value.length,
                  ),
                ],
              ],
            ),
            Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                autofillHints: const [AutofillHints.oneTimeCode],
                showCursor: false,
                decoration: const InputDecoration(border: InputBorder.none),
                onSubmitted: widget.onSubmitted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.width,
    required this.height,
    required this.char,
    required this.isActive,
  });

  final double width;
  final double height;
  final String char;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.18)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(char, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
    );
  }
}
