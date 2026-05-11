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
      appBar: AppBar(title: const Text('Choose a Topic')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SurpriseMeButton(onTap: () {
            final topic = randomTopic();
            _navigateToPrepare(context, ref, topic);
          }),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _CategoryChip(
                    label: 'All',
                    selected: selectedCategory == null,
                    onTap: () => ref.read(selectedCategoryProvider.notifier).state = null,
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
          const SizedBox(height: 12),
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
                onTap: () => _navigateToPrepare(context, ref, topics[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPrepare(BuildContext context, WidgetRef ref, Topic topic) {
    ref.read(selectedTopicProvider.notifier).state = topic;
    context.push(AppRoutes.prepare, extra: topic);
  }
}

class _SurpriseMeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SurpriseMeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shuffle_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'Surprise Me!',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? chipColor : chipColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : chipColor,
          ),
        ),
      ),
    );
  }
}
