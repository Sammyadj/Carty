import 'package:flutter/material.dart';

import 'carty_design.dart';

Future<void> showDesignPicker(BuildContext context) async {
  final scope = DesignPreviewScope.maybeOf(context);
  if (scope == null) return;
  final choice = await showModalBottomSheet<DesignVariant>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find your Carty.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Three looks. The same shopping list.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            for (final variant in DesignVariant.values) ...[
              _DesignOption(
                design: CartyDesign.forVariant(variant),
                selected: scope.variant == variant,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    ),
  );
  if (choice != null) scope.onChanged(choice);
}

class _DesignOption extends StatelessWidget {
  const _DesignOption({required this.design, required this.selected});
  final CartyDesign design;
  final bool selected;
  @override
  Widget build(BuildContext context) => Material(
    color: design.backgroundColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: selected ? design.primaryColor : design.borderColor,
        width: selected ? 2 : 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('design-${design.variant.name}'),
      onTap: () => Navigator.pop(context, design.variant),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 68,
              decoration: BoxDecoration(
                color: design.heroColor,
                borderRadius: BorderRadius.circular(design.radius / 2),
              ),
              child: Center(
                child: Text(
                  'Cc',
                  style: TextStyle(
                    fontFamily: design.fontFamily,
                    color: design.heroInk,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    design.name,
                    style: TextStyle(
                      fontFamily: design.fontFamily,
                      fontSize: 20,
                      color: design.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    design.description,
                    style: TextStyle(
                      fontFamily: design.fontFamily,
                      fontSize: 12,
                      height: 1.5,
                      color: design.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_rounded,
              color: design.primaryColor,
              size: 22,
            ),
          ],
        ),
      ),
    ),
  );
}
