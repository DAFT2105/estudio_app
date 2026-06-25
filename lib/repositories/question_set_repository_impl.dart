// lib/repositories/question_set_repository_impl.dart

import '../models/question.dart';
import '../models/question_set.dart';
import '../services/question_set_service.dart';
import 'question_set_repository.dart';

class QuestionSetRepositoryImpl implements QuestionSetRepository {
  final QuestionSetService _service;

  QuestionSetRepositoryImpl({QuestionSetService? service})
      : _service = service ?? QuestionSetService();

  @override
  Future<QuestionSet> createQuestionSet({
    required String subjectId,
    required String createdBy,
    required String title,
    String? description,
    required QuestionPurpose purpose,
    required List<String> questionIds,
  }) async {
    try {
      if (title.trim().isEmpty) {
        throw const QuestionSetException('El título es requerido');
      }
      if (title.length > 80) {
        throw const QuestionSetException(
            'El título no puede exceder 80 caracteres');
      }
      if (questionIds.isEmpty) {
        throw const QuestionSetException(
            'Debes seleccionar al menos una pregunta');
      }

      return await _service.createQuestionSet(
        subjectId: subjectId,
        createdBy: createdBy,
        title: title.trim(),
        description: description?.trim(),
        purpose: purpose,
        questionIds: questionIds,
      );
    } on QuestionSetException {
      rethrow;
    } catch (e) {
      throw QuestionSetException('Error al crear el grupo de preguntas: $e');
    }
  }

  @override
  Future<List<QuestionSet>> getQuestionSetsBySubject(
    String subjectId, {
    QuestionPurpose? purpose,
  }) async {
    try {
      return await _service.getQuestionSetsBySubject(subjectId,
          purpose: purpose);
    } catch (e) {
      throw QuestionSetException('Error al obtener grupos de preguntas: $e');
    }
  }

  @override
  Future<List<QuestionSet>> getQuestionSetsByCreator(String creatorId) async {
    try {
      return await _service.getQuestionSetsByCreator(creatorId);
    } catch (e) {
      throw QuestionSetException('Error al obtener tus grupos de preguntas: $e');
    }
  }

  @override
  Future<QuestionSet?> getQuestionSetById(String id) async {
    try {
      return await _service.getQuestionSetById(id);
    } catch (e) {
      throw QuestionSetException('Error al obtener el grupo de preguntas: $e');
    }
  }

  @override
  Future<QuestionSet> updateQuestionSet(QuestionSet set) async {
    try {
      if (set.title.trim().isEmpty) {
        throw const QuestionSetException('El título es requerido');
      }
      if (set.questionIds.isEmpty) {
        throw const QuestionSetException(
            'Debe tener al menos una pregunta seleccionada');
      }
      return await _service.updateQuestionSet(set);
    } on QuestionSetException {
      rethrow;
    } catch (e) {
      throw QuestionSetException('Error al actualizar el grupo de preguntas: $e');
    }
  }

  @override
  Future<bool> deleteQuestionSet(String id) async {
    try {
      return await _service.deleteQuestionSet(id);
    } catch (e) {
      throw QuestionSetException('Error al eliminar el grupo de preguntas: $e');
    }
  }

  @override
  bool canEditQuestionSet(QuestionSet set, String userId, String userRole) {
    return set.canEdit(userId, userRole);
  }
}