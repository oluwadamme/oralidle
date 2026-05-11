import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/topic.dart';
import '../../providers/topic_provider.dart';
import '../widgets/topic_card.dart';
import '../../../../core/constants/app_constants.dart';
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
                  Text('Choose a Topic',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('Pick something that excites you',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Surprise Me ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () {
                  final topic = randomTopic();
                  _navigate(context, ref, topic);
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryLight, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shuffle_rounded, color: Color(0xFF490080), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Surprise Me!',
                        style: TextStyle(
                            color: Color(0xFF490080),
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Category chips ─────────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _CategoryChip(
                      label: 'All',
                      selected: selectedCategory == null,
                      color: AppColors.primary,
                      onTap: () =>
                          ref.read(selectedCategoryProvider.notifier).state = null,
                    );
                  }
                  final cat = categories[index - 1];
                  return _CategoryChip(
                    label: cat,
                    selected: selectedCategory == cat,
                    color: cat.categoryColor,
                    onTap: () => ref.read(selectedCategoryProvider.notifier).state =
                        selectedCategory == cat ? null : cat,
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // ── Grid ───────────────────────────────────────────────────
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: topics.length,
                itemBuilder: (context, index) => TopicCard(
                  topic: topics[index],
                  onTap: () => _navigate(context, ref, topics[index]),
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.25)),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF490080) : color,
          ),
        ),
      ),
    );
  }
}
