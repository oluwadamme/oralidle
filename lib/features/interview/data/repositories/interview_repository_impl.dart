import 'dart:convert';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/interview_models.dart';
import 'interview_repository.dart';

class InterviewRepositoryImpl implements InterviewRepository {
  Box<String> get _box => Hive.box<String>(AppConstants.hiveInterviewsBox);

  @override
  Future<void> save(CompletedInterview interview) async {
    await _box.put(interview.id, jsonEncode(interview.toJson()));
  }

  @override
  List<CompletedInterview> getAll() {
    return _box.values
        .map(
          (raw) => CompletedInterview.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          ),
        )
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
