// lib/repositories/question_set_repository.dart

import '../models/question.dart';
import '../models/question_set.dart';

abstract class QuestionSetRepository {
  Future<QuestionSet> createQuestionSet({
    required String subjectId,
    required String createdBy,
    required String title,
    String? description,
    required QuestionPurpose purpose,
    required List<String> questionIds,
  });

  Future<List<QuestionSet>> getQuestionSetsBySubject(
    String subjectId, {
    QuestionPurpose? purpose,
  });

  Future<List<QuestionSet>> getQuestionSetsByCreator(String creatorId);

  Future<QuestionSet?> getQuestionSetById(String id);

  Future<QuestionSet> updateQuestionSet(QuestionSet set);

  Future<bool> deleteQuestionSet(String id);

  bool canEditQuestionSet(QuestionSet set, String userId, String userRole);
}