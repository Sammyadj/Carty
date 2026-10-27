import 'dart:async';

import 'package:carty_app/base/res/styles/app_theme.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/screens/barcode_scanner_screen.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class _ScannerHarness {
  final result = Completer<String?>();
  final navigator = GlobalKey<NavigatorState>();
  late ValueChanged<String> detect;

  Future<void> open(WidgetTester tester, {bool realCamera = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        navigatorKey: navigator,
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    final barcode = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder:
                            (_) => BarcodeScannerScreen(
                              cameraBuilder:
                                  realCamera
                                      ? null
                                      : (context, onBarcode) {
                                        detect = onBarcode;
                                        return const ColoredBox(
                                          key: ValueKey('fake-camera'),
                                          color: Colors.black,
                                        );
                                      },
                            ),
                      ),
                    );
                    result.complete(barcode);
                  },
                  child: const Text('Open scanner'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Open scanner'));
    await tester.pumpAndSettle();
  }
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final control = find.byKey(ValueKey(key));
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

class _FakeScannerPlatform extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  final torch = StreamController<TorchState>.broadcast();
  final zoom = StreamController<double>.broadcast();
  final events = <String>[];
  StartOptions? options;
  Object? startError;
  bool failStop = false;
  bool failDispose = false;

  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;

  @override
  Stream<TorchState> get torchStateStream => torch.stream;

  @override
  Stream<double> get zoomScaleStateStream => zoom.stream;

  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    events.add('start');
    options = startOptions;
    if (startError case final error?) throw error;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {
    events.add('stop');
    if (failStop) throw StateError('Camera disconnected');
  }

  @override
  Future<void> toggleTorch() async {
    events.add('torch');
    torch.add(TorchState.on);
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> dispose() async {
    events.add('dispose');
    if (failDispose) throw StateError('Camera disconnected');
  }

  Future<void> close() async {
    await captures.close();
    await torch.close();
    await zoom.close();
  }
}

void main() {
  testWidgets('a valid camera barcode returns the normalized number', (
    tester,
  ) async {
    final harness = _ScannerHarness();
    await harness.open(tester);
    expect(find.byKey(const ValueKey('fake-camera')), findsOneWidget);
    expect(find.byType(MobileScanner), findsNothing);

    harness.detect('  4006381333931  ');
    await tester.pumpAndSettle();

    expect(await harness.result.future, '4006381333931');
    expect(find.text('Open scanner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid checksums and QR contents leave the scanner open', (
    tester,
  ) async {
    final harness = _ScannerHarness();
    await harness.open(tester);

    for (final value in [
      '4006381333932',
      'https://example.com/4006381333931',
      '12345',
      'not a product',
    ]) {
      harness.detect(value);
    }
    await tester.pumpAndSettle();

    expect(harness.result.isCompleted, isFalse);
    expect(find.byType(BarcodeScannerScreen), findsOneWidget);
    harness.detect('96385074');
    await tester.pumpAndSettle();
    expect(await harness.result.future, '96385074');
  });

  testWidgets('repeated frames pop only the scanner route', (tester) async {
    final harness = _ScannerHarness();
    await harness.open(tester);
    final detect = harness.detect;

    detect('4006381333931');
    detect('012345678905');
    detect('4006381333931');
    await tester.pumpAndSettle();
    detect('012345678905');
    await tester.pumpAndSettle();

    expect(await harness.result.future, '4006381333931');
    expect(harness.navigator.currentState!.canPop(), isFalse);
    expect(find.text('Open scanner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'manual entry validates before returning a leading-zero barcode',
    (tester) async {
      final harness = _ScannerHarness();
      await harness.open(tester);
      await _tapKey(tester, 'barcode-manual');

      await tester.enterText(
        find.byKey(const ValueKey('barcode-input')),
        '4006381333932',
      );
      await _tapKey(tester, 'barcode-submit');
      expect(harness.result.isCompleted, isFalse);
      expect(
        find.textContaining('Enter a valid product barcode'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('barcode-input')),
        ' 012345678905 ',
      );
      await _tapKey(tester, 'barcode-submit');
      expect(await harness.result.future, '012345678905');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('manual cancellation and scanner back leave the cart untouched', (
    tester,
  ) async {
    final cart = CartStore(storage: InMemoryCartStorage());
    addTearDown(cart.dispose);
    await cart.load();
    await cart.addItem(name: 'Milk', unitPricePence: 125, quantity: 2);
    await cart.setBudget(1000);
    final original = cart.items.single;
    final harness = _ScannerHarness();
    await harness.open(tester);

    await _tapKey(tester, 'barcode-manual');
    harness.detect('4006381333931');
    await tester.pumpAndSettle();
    expect(harness.result.isCompleted, isFalse);
    await _tapKey(tester, 'barcode-manual-cancel');
    expect(find.byType(BarcodeScannerScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(await harness.result.future, isNull);
    expect(cart.items.single, same(original));
    expect(cart.totalPence, 250);
    expect(cart.budgetPence, 1000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scanner and manual form fit a narrow phone with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 680);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = _ScannerHarness();
    await harness.open(tester);
    expect(tester.takeException(), isNull);

    await _tapKey(tester, 'barcode-manual');
    await _tapKey(tester, 'barcode-submit');
    expect(
      find.textContaining('Enter a valid product barcode'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _tapKey(tester, 'barcode-manual-cancel');
    expect(tester.takeException(), isNull);
  });

  group('camera platform', () {
    late MobileScannerPlatform previous;
    late _FakeScannerPlatform platform;

    setUp(() {
      previous = MobileScannerPlatform.instance;
      platform = _FakeScannerPlatform();
      MobileScannerPlatform.instance = platform;
    });

    tearDown(() async {
      await platform.close();
      MobileScannerPlatform.instance = previous;
    });

    for (final error in [
      MobileScannerErrorCode.permissionDenied,
      MobileScannerErrorCode.unsupported,
    ]) {
      testWidgets('$error offers manual entry without crashing', (
        tester,
      ) async {
        platform.startError = MobileScannerException(errorCode: error);
        final harness = _ScannerHarness();
        await harness.open(tester, realCamera: true);

        expect(
          find.textContaining(
            error == MobileScannerErrorCode.permissionDenied
                ? 'Camera access is off'
                : 'Camera scanning isn’t available',
          ),
          findsOneWidget,
        );
        await _tapKey(tester, 'barcode-manual');
        await tester.enterText(
          find.byKey(const ValueKey('barcode-input')),
          '4006381333931',
        );
        await _tapKey(tester, 'barcode-submit');

        expect(await harness.result.future, '4006381333931');
        expect(platform.events, contains('dispose'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('camera permits only retail formats and ignores numeric QR', (
      tester,
    ) async {
      final harness = _ScannerHarness();
      await harness.open(tester, realCamera: true);
      expect(platform.options!.formats, [
        BarcodeFormat.ean8,
        BarcodeFormat.ean13,
        BarcodeFormat.upcA,
        BarcodeFormat.itf,
      ]);
      platform.captures.add(
        const BarcodeCapture(
          barcodes: [
            Barcode(format: BarcodeFormat.qrCode, rawValue: '4006381333931'),
            Barcode(format: BarcodeFormat.ean13, rawValue: '4006381333932'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(harness.result.isCompleted, isFalse);
      platform.captures.add(
        const BarcodeCapture(
          barcodes: [
            Barcode(format: BarcodeFormat.ean13, rawValue: '4006381333931'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(await harness.result.future, '4006381333931');
      expect(platform.events, containsAllInOrder(['start', 'stop', 'dispose']));
      expect(tester.takeException(), isNull);
    });

    testWidgets('camera pauses for manual entry and background, then resumes', (
      tester,
    ) async {
      final harness = _ScannerHarness();
      await harness.open(tester, realCamera: true);
      await _tapKey(tester, 'barcode-torch');
      expect(platform.events, ['start', 'torch']);
      await _tapKey(tester, 'barcode-manual');
      expect(platform.events.last, 'stop');
      await _tapKey(tester, 'barcode-manual-cancel');
      expect(platform.events.last, 'start');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(platform.events.last, 'stop');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(platform.events.last, 'start');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(await harness.result.future, isNull);
      expect(platform.events, containsAllInOrder(['stop', 'dispose']));
      expect(tester.takeException(), isNull);
    });

    testWidgets('unexpected camera and cleanup errors stay contained', (
      tester,
    ) async {
      platform.startError = StateError('Camera disconnected');
      platform.failDispose = true;
      final harness = _ScannerHarness();
      await harness.open(tester, realCamera: true);
      expect(find.textContaining('Camera unavailable'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(await harness.result.future, isNull);
      expect(platform.events, contains('dispose'));
      expect(tester.takeException(), isNull);
    });
  });
}
