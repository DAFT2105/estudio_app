// lib/repositories/result_repository_impl.dart

import '../models/practice_result.dart';
import '../services/result_service.dart';
import 'result_repository.dart';

class ResultRepositoryImpl implements ResultRepository {
  final ResultService _resultService;

  ResultRepositoryImpl({required ResultService resultService})
      : _resultService = resultService;

  @override
  Future<void> saveResult(PracticeResult result, {String? parentId}) async {
    try {
      await _resultService.saveResult(result, parentId: parentId);
    } catch (e) {
      throw ResultException('Error al guardar resultado: $e');
    }
  }

  @override
  Future<List<PracticeResult>> getResultsByStudent(String studentId) async {
    try {
      return await _resultService.getResultsByStudent(studentId);
    } catch (e) {
      throw ResultException('Error al obtener resultados: $e');
    }
  }

  @override
  Future<List<PracticeResult>> getResultsByStudentAndSubject(
      String studentId, String subjectId) async {
    try {
      return await _resultService.getResultsByStudentAndSubject(
          studentId, subjectId);
    } catch (e) {
      throw ResultException('Error al obtener resultados por materia: $e');
    }
  }

  @override
  Future<void> deleteResult(String resultId) async {
    try {
      await _resultService.deleteResult(resultId);
    } catch (e) {
      throw ResultException('Error al eliminar resultado: $e');
    }
  }

  @override
  Future<void> deleteResultsByStudent(String studentId) async {
    try {
      await _resultService.deleteResultsByStudent(studentId);
    } catch (e) {
      throw ResultException('Error al eliminar resultados: $e');
    }
  }

  @override
  Future<PracticeStats> getStudentStats(String studentId) async {
    try {
      return await _resultService.getStudentStats(studentId);
    } catch (e) {
      throw ResultException('Error al calcular estadísticas: $e');
    }
  }
}