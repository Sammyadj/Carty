import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../base/res/styles/app_styles.dart';
import '../core/retail_barcode.dart';

/// Supplies a camera preview without requiring a camera in widget tests.
typedef BarcodeCameraBuilder = Widget Function(
  BuildContext context,
  ValueChanged<String> onBarcode,
);

/// Returns one validated retail barcode, or null when the shopper goes back.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key, this.cameraBuilder});

  final BarcodeCameraBuilder? cameraBuilder;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _completed = false;
  bool _manualOpen = false;
  String? _scanMessage;

  void _onBarcode(String rawValue) {
    if (!mounted || _completed || _manualOpen) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final barcode = RetailBarcode.normalize(rawValue);
    if (barcode == null) {
      if (_scanMessage == null) {
        setState(() {
          _scanMessage = 'Try a product barcode, or enter its digits below.';
        });
      }
      return;
    }
    _finish(barcode);
  }

  void _finish(String barcode) {
    if (!mounted || _completed) return;
    setState(() => _completed = true);
    Navigator.of(context).pop<String>(barcode);
  }

  Future<void> _enterManually() async {
    if (_completed || _manualOpen) return;
    setState(() => _manualOpen = true);
    final barcode = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualBarcodeDialog(),
    );
    if (!mounted || _completed) return;
    setState(() => _manualOpen = false);
    if (barcode != null) _finish(barcode);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<String>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !_completed && mounted) {
          setState(() => _completed = true);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          foregroundColor: AppColors.textPrimary,
          title: const Text(
            'Scan a barcode',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'A little scan.\nA smarter shop.',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Point your camera at the barcode on the packaging.',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Barcodes are sent to Open Food Facts for product '
                      'details. Camera images stay on your device. '
                      'You confirm the shelf price.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: AspectRatio(
                        aspectRatio: 1.08,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            widget.cameraBuilder?.call(context, _onBarcode) ??
                                _BarcodeCamera(
                                  active: !_manualOpen && !_completed,
                                  onBarcode: _onBarcode,
                                ),
                            const IgnorePointer(
                              child: CustomPaint(painter: _ScanFramePainter()),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.center_focus_strong_rounded,
                            color: AppColors.primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _scanMessage ??
                                  'Keep the bars inside the frame and hold '
                                      'steady. We’ll read the number for you.',
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      key: const ValueKey('barcode-manual'),
                      onPressed: _completed ? null : _enterManually,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryColor,
                        side: const BorderSide(color: AppColors.borderColor),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.keyboard_rounded),
                      label: const Text(
                        'Enter barcode manually',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Works with retail product barcodes. QR codes aren’t '
                      'supported.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualBarcodeDialog extends StatefulWidget {
  const _ManualBarcodeDialog();

  @override
  State<_ManualBarcodeDialog> createState() => _ManualBarcodeDialogState();
}

class _ManualBarcodeDialogState extends State<_ManualBarcodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

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
      title: const Text('Enter barcode'),
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
              ? 'Enter a valid product barcode with 8, 12, 13 or '
                    '14 digits.'
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

class _BarcodeCamera extends StatefulWidget {
  const _BarcodeCamera({required this.active, required this.onBarcode});

  final bool active;
  final ValueChanged<String> onBarcode;

  @override
  State<_BarcodeCamera> createState() => _BarcodeCameraState();
}

class _BarcodeCameraState extends State<_BarcodeCamera>
    with WidgetsBindingObserver {
  static const _formats = [
    BarcodeFormat.ean8,
    BarcodeFormat.ean13,
    BarcodeFormat.upcA,
    BarcodeFormat.itf,
  ];

  final _controller = MobileScannerController(
    autoStart: false,
    formats: _formats,
  );
  Future<void> _operations = Future<void>.value();
  bool _foreground = true;
  bool _disposed = false;
  bool _torchBusy = false;
  String? _operationError;

  bool get _shouldRun => widget.active && _foreground && !_disposed;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateCamera());
  }

  @override
  void didUpdateWidget(covariant _BarcodeCamera oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) _updateCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateCamera();
  }

  // Serialize camera work: permission prompts can trigger lifecycle changes
  // while start is still in flight. Every operation reads the latest intent.
  void _updateCamera() {
    if (_disposed) return;
    _operations = _operations.then((_) async {
      if (_disposed) return;
      try {
        if (_shouldRun) {
          await _controller.start();
        } else {
          await _controller.stop();
        }
      } catch (_) {
        if (mounted && !_disposed) {
          setState(() {
            _operationError =
                'Camera unavailable. Enter the barcode below '
                'to keep going.';
          });
        }
      }
    });
  }

  Future<void> _toggleTorch() async {
    if (_torchBusy || !_shouldRun) return;
    setState(() => _torchBusy = true);
    try {
      await _controller.toggleTorch();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The flashlight is unavailable.')),
        );
      }
    } finally {
      if (mounted) setState(() => _torchBusy = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_shouldRun) return;
    for (final barcode in capture.barcodes) {
      if (!_formats.contains(barcode.format)) continue;
      final value = barcode.rawValue;
      if (value != null) widget.onBarcode(value);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    // Let pending permission/start work settle before releasing the camera.
    unawaited(
      _operations.then((_) async {
        try {
          await _controller.stop();
        } catch (_) {
          // Disposal still needs to release the platform after a stop failure.
        }
        try {
          await _controller.dispose();
        } catch (_) {
          // The route is already gone; cleanup failures cannot be shown here.
        }
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          useAppLifecycleState: false,
          onDetect: _onDetect,
          errorBuilder: (context, error) => _CameraMessage(
            message: switch (error.errorCode) {
              MobileScannerErrorCode.permissionDenied =>
                'Camera access is off. Allow it in your device settings, '
                    'or enter the barcode below.',
              MobileScannerErrorCode.unsupported =>
                'Camera scanning isn’t available on this device. '
                    'Enter the barcode below.',
              _ =>
                'The camera couldn’t start. Enter the barcode below '
                    'to keep going.',
            },
          ),
          placeholderBuilder: (_) =>
              const ColoredBox(color: AppColors.primaryDark),
        ),
        if (_operationError case final message?)
          _CameraMessage(message: message),
        Positioned(
          top: 12,
          right: 12,
          child: ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, child) {
              if (!state.isRunning ||
                  state.torchState == TorchState.unavailable ||
                  _operationError != null) {
                return const SizedBox.shrink();
              }
              final isOn = state.torchState == TorchState.on;
              return IconButton.filledTonal(
                key: const ValueKey('barcode-torch'),
                tooltip: isOn ? 'Turn flashlight off' : 'Turn flashlight on',
                onPressed: _torchBusy ? null : _toggleTorch,
                icon: Icon(
                  isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primaryDark,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromLTWH(18, 18, size.width - 36, size.height - 36);
    final paint = Paint()
      ..color = AppColors.mint
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const length = 24.0;
    for (final corner in [
      frame.topLeft,
      frame.topRight,
      frame.bottomLeft,
      frame.bottomRight,
    ]) {
      final horizontal = corner.dx == frame.left ? length : -length;
      final vertical = corner.dy == frame.top ? length : -length;
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + horizontal, corner.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy + vertical),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) => false;
}
