import 'package:flutter/material.dart';

import '../base/utils/cart_dialogs.dart';
import '../core/money.dart';
import '../data/item_suggestions.dart';
import '../data/shopping_recommendations.dart';
import '../design/carty_design.dart';
import '../state/cart_store.dart';
import 'product_avatar.dart';
import 'section_heading.dart';

class ShoppingRecommendationsSection extends StatelessWidget {
  const ShoppingRecommendationsSection({super.key, required this.store});
  final CartStore store;

  @override
  Widget build(BuildContext context) {
    final recommendations = ShoppingRecommendations.forWorkspace(
      items: store.items,
      savedLists: store.savedLists,
      history: store.history,
      remainingPence: store.remainingPence,
    );
    if (recommendations.isEmpty) return const SizedBox.shrink();
    final design = CartyDesign.of(context);
    return Padding(
      key: const Key('recommendations-section'),
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: 'You might need'),
          Text(
            'Ideas for this basket. Saved prices are estimates.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          for (final recommendation in recommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(design.radius),
                  side: BorderSide(color: design.borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ProductAvatar(
                            name: recommendation.item.name,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              recommendation.item.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        recommendation.explanation,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            recommendation.item.unitPricePence == null
                                ? 'Add your price estimate'
                                : 'Saved price ${Money.format(recommendation.item.unitPricePence!)}',
                          ),
                          OutlinedButton.icon(
                            key: Key(
                              'recommendation-review-${ItemSuggestions.normalize(recommendation.item.name)}',
                            ),
                            onPressed: () => showItemEditor(
                              context: context,
                              store: store,
                              initialSuggestion: recommendation.item,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Review & add'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
