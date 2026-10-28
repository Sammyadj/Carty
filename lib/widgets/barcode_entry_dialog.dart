import 'package:flutter/material.dart';

import '../core/retail_barcode.dart';

/// Returns a validated barcode, preserving printed leading zeroes.
class BarcodeEntryDialog extends StatefulWidget {
  const BarcodeEntryDialog({
    super.key,
    this.initialBarcode = '',
    this.title = 'Enter barcode',
  });

  final String initialBarcode;
  final String title;

  @override
  State<BarcodeEntryDialog> createState() => _BarcodeEntryDialogState();
}

class _BarcodeEntryDialogState extends State<BarcodeEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialBarcode);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context)
        .pop<String>(RetailBarcode.normalize(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const ValueKey('barcode-input'),
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Barcode number',
            helperText: 'Use the 8, 12, 13 or 14 digits below the bars.',
            helperMaxLines: 3,
            errorMaxLines: 3,
          ),
          validator: (value) => RetailBarcode.normalize(value ?? '') == null
              ? 'Enter a valid product barcode with 8, 12, 13 or 14 digits.'
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('barcode-manual-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('barcode-submit'),
          onPressed: _submit,
          child: const Text('Use barcode'),
        ),
      ],
    );
  }
}
