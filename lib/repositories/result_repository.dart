// lib/repositories/result_repository.dart

import '../models/practice_result.dart';
import '../services/result_service.dart';

abstract class ResultRepository {
  Future<void> saveResult(PracticeResult result, {String? parentId});
  Future<List<PracticeResult>> getResultsByStudent(String studentId);
  Future<List<PracticeResult>> getResultsByStudentAndSubject(
      String studentId, String subjectId);
  Future<void> deleteResult(String resultId);
  Future<void> deleteResultsByStudent(String studentId);
  Future<PracticeStats> getStudentStats(String studentId);
}