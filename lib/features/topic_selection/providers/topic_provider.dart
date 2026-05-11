import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/topic.dart';
import '../../../core/constants/topics.dart';

final selectedTopicProvider = StateProvider<Topic?>((ref) => null);

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final filteredTopicsProvider = Provider<List<Topic>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  if (category == null) return AppTopics.all;
  return AppTopics.all.where((t) => t.category == category).toList();
});

Topic randomTopic() {
  final rng = Random();
  return AppTopics.all[rng.nextInt(AppTopics.all.length)];
}
