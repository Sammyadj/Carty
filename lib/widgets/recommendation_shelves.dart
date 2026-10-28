import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../base/utils/cart_dialogs.dart';
import '../core/money.dart';
import '../data/item_suggestions.dart';
import '../data/shopping_recommendations.dart';
import '../design/carty_design.dart';
import '../models/grocery_category.dart';
import '../state/cart_store.dart';
import 'product_avatar.dart';
import 'section_heading.dart';
import 'grocery_category_filter.dart';

class ShoppingRecommendationsSection extends StatefulWidget {
  const ShoppingRecommendationsSection({super.key, required this.store});
  final CartStore store;

  @override
  State<ShoppingRecommendationsSection> createState() =>
      _ShoppingRecommendationsSectionState();
}

class _ShoppingRecommendationsSectionState
    extends State<ShoppingRecommendationsSection> {
  GroceryCategory? _category;
  CartStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final groups = ShoppingRecommendations.groupsForWorkspace(
      items: store.items,
      savedLists: store.savedLists,
      history: store.history,
      remainingPence: store.remainingPence,
    );
    if (groups.isEmpty) return const SizedBox.shrink();
    final filtered = [
      for (final group in groups)
        ShoppingRecommendationGroup(
          reason: group.reason,
          items: [
            for (final item in group.items)
              if (_category == null || item.item.resolvedCategory == _category)
                item,
          ],
        ),
    ].where((group) => group.items.isNotEmpty).toList();
    return Padding(
      key: const Key('recommendations-section'),
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: 'You might need'),
          Text(
            'Ideas for this basket. Saved prices are estimates.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          GroceryCategoryFilter(
            categories: groups
                .expand((group) => group.items)
                .map((item) => item.item.resolvedCategory),
            selected: _category,
            onChanged: (value) => setState(() => _category = value),
            storageId: 'recommendation-categories',
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            const Text('No ideas in this category for the current basket.'),
          for (final group in filtered)
            _RecommendationShelf(
              key: ValueKey('recommendation-group-${group.reason.name}'),
              group: group,
              store: store,
            ),
        ],
      ),
    );
  }
}

String _title(RecommendationReason reason) => switch (reason) {
  RecommendationReason.pickedTogether => 'Picked together',
  RecommendationReason.frequent => 'Your regulars',
  RecommendationReason.savedList => 'From your saved lists',
  RecommendationReason.pastShop => 'Pick up again',
  RecommendationReason.pairing => 'Pairing ideas',
  RecommendationReason.starter => 'Everyday essentials',
};

Color _artColor(RecommendationReason reason) => switch (reason) {
  RecommendationReason.pickedTogether => const Color(0xFFEAF2D7),
  RecommendationReason.frequent => const Color(0xFFFFF0DF),
  RecommendationReason.savedList => const Color(0xFFFFF4D4),
  RecommendationReason.pastShop => const Color(0xFFF9E8E2),
  RecommendationReason.pairing => const Color(0xFFE8F1F8),
  RecommendationReason.starter => const Color(0xFFEDF4D3),
};

class _RecommendationShelf extends StatefulWidget {
  const _RecommendationShelf({
    super.key,
    required this.group,
    required this.store,
  });
  final ShoppingRecommendationGroup group;
  final CartStore store;

  @override
  State<_RecommendationShelf> createState() => _RecommendationShelfState();
}

class _RecommendationShelfState extends State<_RecommendationShelf> {
  final _scroll = ScrollController();
  bool _back = false;
  bool _next = false;
  double _step = 280;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateEdges);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAfterLayout();
  }

  @override
  void didUpdateWidget(covariant _RecommendationShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAfterLayout();
  }

  void _checkAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateEdges();
    });
  }

  void _updateEdges() {
    if (!_scroll.hasClients || !mounted) return;
    final back = _scroll.offset > 1;
    final next = _scroll.offset < _scroll.position.maxScrollExtent - 1;
    if (back != _back || next != _next) {
      setState(() {
        _back = back;
        _next = next;
      });
    }
  }

  Future<void> _move(int direction) async {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + direction * _step)
        .clamp(0.0, _scroll.position.maxScrollExtent)
        .toDouble();
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _scroll.jumpTo(target);
    } else {
      await _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final title = _title(group.reason);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              if (group.items.length > 1) ...[
                IconButton(
                  key: Key('recommendations-previous-${group.reason.name}'),
                  tooltip: 'Previous in $title',
                  onPressed: _back ? () => _move(-1) : null,
                  icon: const Icon(Icons.arrow_back_rounded, size: 21),
                ),
                IconButton.filledTonal(
                  key: Key('recommendations-next-${group.reason.name}'),
                  tooltip: 'Next in $title',
                  onPressed: _next ? () => _move(1) : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 21),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(
                group.items.length == 1 ? 320.0 : 280.0,
                constraints.maxWidth * (group.items.length == 1 ? 1 : .82),
              );
              _step = width + 12;
              return SingleChildScrollView(
                key: PageStorageKey(
                  'recommendation-scroll-${group.reason.name}',
                ),
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < group.items.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        SizedBox(
                          width: width,
                          child: _RecommendationCard(
                            key: ValueKey(
                              'recommendation-card-${ItemSuggestions.normalize(group.items[i].item.name)}',
                            ),
                            recommendation: group.items[i],
                            store: widget.store,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    super.key,
    required this.recommendation,
    required this.store,
  });
  final ShoppingRecommendation recommendation;
  final CartStore store;

  @override
  Widget build(BuildContext context) {
    final item = recommendation.item;
    final design = CartyDesign.of(context);
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: design.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              height: 88,
              child: ColoredBox(
                color: _artColor(recommendation.reason),
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -38,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .45),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 16,
                        child: Container(
                          width: 28,
                          height: 5,
                          decoration: BoxDecoration(
                            color: design.primaryColor.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Center(
                        child: Transform.rotate(
                          angle: -.08,
                          child: ProductAvatar(name: item.name, size: 64),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recommendation.explanation,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  const Spacer(),
                  Text(
                    item.unitPricePence == null
                        ? 'Add your price estimate'
                        : 'Saved price ${Money.format(item.unitPricePence!)}',
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    key: Key(
                      'recommendation-review-${ItemSuggestions.normalize(item.name)}',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => showItemEditor(
                      context: context,
                      store: store,
                      initialSuggestion: item,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Review & add'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
