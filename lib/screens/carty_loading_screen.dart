import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/carty_design.dart';
import '../design/shopping_header.dart';

class CartyLoadingScreen extends StatefulWidget {
  const CartyLoadingScreen({
    super.key,
    this.message = 'Getting your shop ready…',
  });
  final String message;

  @override
  State<CartyLoadingScreen> createState() => _CartyLoadingScreenState();
}

class _CartyLoadingScreenState extends State<CartyLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _still = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_still) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final design = CartyDesign.of(context);
    return Semantics(
      key: const Key('carty-loading'),
      label: 'Carty. ${widget.message}',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Scaffold(
          backgroundColor: design.backgroundColor,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxHeight < 550 ||
                    MediaQuery.textScalerOf(context).scale(1) >= 1.6;
                final artSize = math.min(
                  compact ? 154.0 : 224.0,
                  constraints.maxWidth - 64,
                );
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: design.primaryColor,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  Icons.shopping_cart_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Flexible(
                                child: Text(
                                  'Carty',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RepaintBoundary(
                                  child: AnimatedBuilder(
                                    animation: _motion,
                                    builder: (context, _) => SizedBox(
                                      width: artSize,
                                      height: artSize * 1.15,
                                      child: GroceryIllustration(
                                        phase: _still
                                            ? null
                                            : _motion.value * math.pi * 2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Your shop.\nYour rules.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(fontSize: compact ? 32 : 40),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  widget.message,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: design.textSecondary),
                                ),
                                const SizedBox(height: 22),
                                RepaintBoundary(
                                  child: AnimatedBuilder(
                                    animation: _motion,
                                    builder: (context, _) => Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(3, (index) {
                                        final lift = _still
                                            ? 0.0
                                            : math.sin(
                                                _motion.value * math.pi * 2 -
                                                    index * .8,
                                              );
                                        return Transform.translate(
                                          offset: Offset(0, lift * 3),
                                          child: Container(
                                            width: index == 1 ? 26 : 9,
                                            height: 9,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: index == 1
                                                  ? design.heroAccent
                                                  : design.primaryColor,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'A little planning. A better shop.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
