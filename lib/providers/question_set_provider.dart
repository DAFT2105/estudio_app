// lib/providers/question_set_provider.dart

import 'package:flutter/foundation.dart';
import '../models/question.dart';
import '../models/question_set.dart';
import '../repositories/question_set_repository.dart';
import '../repositories/question_set_repository_impl.dart';

enum QuestionSetStatus { initial, loading, loaded, empty, error }

class QuestionSetProvider extends ChangeNotifier {
  final QuestionSetRepository _repository;

  QuestionSetProvider({QuestionSetRepository? repository})
      : _repository = repository ?? QuestionSetRepositoryImpl();

  List<QuestionSet> _sets = [];
  QuestionSetStatus _status = QuestionSetStatus.initial;
  String? _errorMessage;

  List<QuestionSet> get sets => _sets;
  QuestionSetStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == QuestionSetStatus.loading;

  void _setStatus(QuestionSetStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = QuestionSetStatus.error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Cargar los sets de una materia, opcionalmente filtrados por modo
  Future<void> loadSetsBySubject(String subjectId, {QuestionPurpose? purpose}) async {
    try {
      _setStatus(QuestionSetStatus.loading);
      _clearError();

      final loaded = await _repository.getQuestionSetsBySubject(subjectId,
          purpose: purpose);

      _sets = loaded;
      _setStatus(loaded.isEmpty ? QuestionSetStatus.empty : QuestionSetStatus.loaded);
    } on QuestionSetException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Error al cargar grupos de preguntas: $e');
    }
  }

  /// Crear un nuevo set armado a mano
  Future<bool> createSet({
    required String subjectId,
    required String createdBy,
    required String title,
    String? description,
    required QuestionPurpose purpose,
    required List<String> questionIds,
  }) async {
    try {
      _clearError();

      final newSet = await _repository.createQuestionSet(
        subjectId: subjectId,
        createdBy: createdBy,
        title: title,
        description: description,
        purpose: purpose,
        questionIds: questionIds,
      );

      _sets = [..._sets, newSet];
      _setStatus(QuestionSetStatus.loaded);
      return true;
    } on QuestionSetException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al crear el grupo de preguntas: $e');
      return false;
    }
  }

  /// Eliminar un set (soft delete)
  Future<bool> deleteSet(String id) async {
    try {
      _clearError();
      final success = await _repository.deleteQuestionSet(id);
      if (success) {
        _sets = _sets.where((s) => s.id != id).toList();
        notifyListeners();
      }
      return success;
    } on QuestionSetException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al eliminar el grupo de preguntas: $e');
      return false;
    }
  }

  bool canEditSet(QuestionSet set, String userId, String userRole) {
    return _repository.canEditQuestionSet(set, userId, userRole);
  }

  /// Resuelve los IDs guardados en el set a los objetos Question reales,
  /// preservando el orden en que el padre las eligió. Reutiliza preguntas
  /// ya cargadas en memoria (no hace queries adicionales a Firestore).
  /// Si alguna pregunta fue eliminada después de armar el set, simplemente
  /// se omite de la lista resultante.
  List<Question> resolveQuestions(
    QuestionSet set,
    List<Question> availableQuestions,
  ) {
    final byId = {for (final q in availableQuestions) q.id: q};
    return set.questionIds
        .map((id) => byId[id])
        .whereType<Question>()
        .toList();
  }
}