import 'package:flutter/material.dart';

/// Asks for one piece of text in a dialog and returns it, or null on Cancel.
/// The dialog owns its text field, so nothing is disposed while it closes.
Future<String?> askText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String confirm = 'OK',
  bool obscure = false,
  int maxLines = 1,
  int? maxLength,
  bool sentences = false,
  bool border = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPrompt(
      title: title,
      initial: initial,
      hint: hint,
      confirm: confirm,
      obscure: obscure,
      maxLines: maxLines,
      maxLength: maxLength,
      sentences: sentences,
      border: border,
    ),
  );
}

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.initial,
    required this.hint,
    required this.confirm,
    required this.obscure,
    required this.maxLines,
    required this.maxLength,
    required this.sentences,
    required this.border,
  });

  final String title;
  final String initial;
  final String? hint;
  final String confirm;
  final bool obscure;
  final int maxLines;
  final int? maxLength;
  final bool sentences;
  final bool border;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: widget.obscure,
        maxLines: widget.obscure ? 1 : widget.maxLines,
        maxLength: widget.maxLength,
        textCapitalization:
            widget.sentences ? TextCapitalization.sentences : TextCapitalization.none,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: widget.border ? const OutlineInputBorder() : null,
        ),
        onSubmitted: widget.maxLines == 1 ? (v) => Navigator.pop(context, v) : null,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
