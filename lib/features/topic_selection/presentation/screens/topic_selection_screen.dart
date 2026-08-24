import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/models/topic.dart';
import '../../providers/topic_provider.dart';
import '../widgets/topic_card.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/category_badge.dart';
import '../../data/models/topic_category.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/constants/topics.dart';

class TopicSelectionScreen extends ConsumerWidget {
  const TopicSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final topics = ref.watch(filteredTopicsProvider);
    final categories = AppTopics.categories;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose a Topic',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick something that excites you',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xl),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppButton.secondary(
                  label: 'Surprise me',
                  icon: LucideIcons.shuffle,
                  onPressed: () => _navigate(context, ref, randomTopic()),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Category chips ─────────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: context.responsive(compact: 20, medium: 28),
                ),
                itemCount: categories.length + 1,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return CategoryBadge(
                      label: 'All',
                      icon: TopicCategory.fromLabel('All').icon,
                      selected: selectedCategory == null,
                      onTap: () =>
                          ref.read(selectedCategoryProvider.notifier).state =
                              null,
                    );
                  }
                  final cat = categories[index - 1];
                  return CategoryBadge(
                    label: cat,
                    icon: TopicCategory.fromLabel(cat).icon,
                    selected: selectedCategory == cat,
                    onTap: () =>
                        ref.read(selectedCategoryProvider.notifier).state =
                            selectedCategory == cat ? null : cat,
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // ── Grid ───────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Breakpoints.wideContentMaxWidth,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = responsiveColumns(constraints.maxWidth);
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: Space.md,
                          crossAxisSpacing: Space.md,
                          // Measured: the card's natural height is 206 at
                          // normal text size and 272 at 1.5x, so this is the
                          // content's height plus a little headroom rather
                          // than a guess.
                          mainAxisExtent: MediaQuery.textScalerOf(
                            context,
                          ).scale(212),
                        ),
                        itemCount: topics.length,
                        itemBuilder: (context, index) => TopicCard(
                          topic: topics[index],
                          onTap: () => _navigate(context, ref, topics[index]),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, WidgetRef ref, Topic topic) {
    ref.read(selectedTopicProvider.notifier).state = topic;
    context.push(AppRoutes.prepare, extra: topic);
  }
}
