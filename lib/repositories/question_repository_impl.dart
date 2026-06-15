// lib/repositories/question_repository_impl.dart

import '../models/question.dart';
import '../services/question_service.dart';
import 'question_repository.dart';

class QuestionRepositoryImpl implements QuestionRepository {
  final QuestionService _questionService;

  QuestionRepositoryImpl({QuestionService? questionService})
      : _questionService = questionService ?? QuestionService();

  @override
  Future<List<Question>> getAllQuestions() async {
    try {
      return await _questionService.getAllQuestions();
    } catch (e) {
      throw QuestionException('Error al obtener preguntas: $e');
    }
  }

  @override
  Future<List<Question>> getQuestionsBySubject(String subjectId) async {
    try {
      return await _questionService.getQuestionsBySubject(subjectId);
    } catch (e) {
      throw QuestionException('Error al obtener preguntas de la materia: $e');
    }
  }

  @override
  Future<List<Question>> getQuestionsByCreator(String creatorId) async {
    try {
      return await _questionService.getQuestionsByCreator(creatorId);
    } catch (e) {
      throw QuestionException('Error al obtener preguntas del creador: $e');
    }
  }

  @override
  Future<Question?> getQuestionById(String questionId) async {
    try {
      return await _questionService.getQuestionById(questionId);
    } catch (e) {
      throw QuestionException('Error al obtener pregunta: $e');
    }
  }

  @override
  Future<Question> createQuestion({
    required String subjectId,
    required String createdBy,
    required String text,
    required QuestionType type,
    required List<String> options,
    required String correctAnswer,
    String? explanation,
    String? topic,
    QuestionDifficulty difficulty = QuestionDifficulty.medium,
  }) async {
    try {
      // Validaciones
      if (text.trim().isEmpty) {
        throw QuestionException('El texto de la pregunta es requerido');
      }

      if (text.length < 10) {
        throw QuestionException('La pregunta debe tener al menos 10 caracteres');
      }

      if (text.length > 500) {
        throw QuestionException('La pregunta no puede exceder 500 caracteres');
      }

      if (correctAnswer.trim().isEmpty) {
        throw QuestionException('Debe especificar la respuesta correcta');
      }

      // Validaciones específicas por tipo
      switch (type) {
        case QuestionType.multipleChoice:
          if (options.length < 2) {
            throw QuestionException('Debe haber al menos 2 opciones');
          }
          if (options.length > 6) {
            throw QuestionException('No puede haber más de 6 opciones');
          }
          if (!options.contains(correctAnswer)) {
            throw QuestionException('La respuesta correcta debe estar en las opciones');
          }
          break;

        case QuestionType.trueFalse:
          final validAnswers = ['verdadero', 'falso', 'true', 'false'];
          if (!validAnswers.contains(correctAnswer.toLowerCase())) {
            throw QuestionException('Respuesta debe ser Verdadero o Falso');
          }
          break;

        case QuestionType.shortAnswer:
          if (correctAnswer.length > 100) {
            throw QuestionException('La respuesta corta no puede exceder 100 caracteres');
          }
          break;
      }

      return await _questionService.createQuestion(
        subjectId: subjectId,
        createdBy: createdBy,
        text: text.trim(),
        type: type,
        options: options,
        correctAnswer: correctAnswer.trim(),
        explanation: explanation?.trim(),
        topic: topic?.trim(),
        difficulty: difficulty,
      );
    } on QuestionException {
      rethrow;
    } catch (e) {
      throw QuestionException('Error al crear pregunta: $e');
    }
  }

  @override
  Future<Question> updateQuestion(Question question) async {
    try {
      // Validaciones similares a create
      if (question.text.trim().isEmpty) {
        throw QuestionException('El texto de la pregunta es requerido');
      }

      if (!question.isValid) {
        throw QuestionException('La pregunta no es válida');
      }

      return await _questionService.updateQuestion(question);
    } on QuestionException {
      rethrow;
    } catch (e) {
      throw QuestionException('Error al actualizar pregunta: $e');
    }
  }

  @override
  Future<bool> deleteQuestion(String questionId) async {
    try {
      return await _questionService.deleteQuestion(questionId);
    } on QuestionException {
      rethrow;
    } catch (e) {
      throw QuestionException('Error al eliminar pregunta: $e');
    }
  }

  @override
  Future<List<Question>> searchQuestions(String query, String? subjectId) async {
    try {
      if (query.trim().isEmpty) {
        return subjectId != null 
            ? await getQuestionsBySubject(subjectId)
            : await getAllQuestions();
      }

      return await _questionService.searchQuestions(query.trim(), subjectId);
    } catch (e) {
      throw QuestionException('Error al buscar preguntas: $e');
    }
  }

  @override
  Future<List<Question>> getQuestionsByType(
    String subjectId,
    QuestionType type,
  ) async {
    try {
      return await _questionService.getQuestionsByType(subjectId, type);
    } catch (e) {
      throw QuestionException('Error al filtrar preguntas por tipo: $e');
    }
  }

  @override
  Future<List<Question>> getQuestionsByDifficulty(
    String subjectId,
    QuestionDifficulty difficulty,
  ) async {
    try {
      return await _questionService.getQuestionsByDifficulty(subjectId, difficulty);
    } catch (e) {
      throw QuestionException('Error al filtrar preguntas por dificultad: $e');
    }
  }

  @override
  Future<List<Question>> getRandomQuestions({
    required String subjectId,
    int count = 10,
    QuestionDifficulty? difficulty,
    String? topic,
  }) async {
    try {
      return await _questionService.getRandomQuestions(
        subjectId: subjectId,
        count: count,
        difficulty: difficulty,
        topic: topic,
      );
    } catch (e) {
      throw QuestionException('Error al obtener preguntas aleatorias: $e');
    }
  }

  @override
  Future<QuestionStats> getQuestionStats(String subjectId) async {
    try {
      return await _questionService.getQuestionStats(subjectId);
    } catch (e) {
      throw QuestionException('Error al obtener estadísticas: $e');
    }
  }

  @override
  bool canEditQuestion(Question question, String userId, String userRole) {
    // Admin puede editar todo
    if (userRole == 'admin') return true;
    // Padre puede editar solo sus preguntas
    if (userRole == 'parent') return question.createdBy == userId;
    // Estudiante no puede editar
    return false;
  }
}