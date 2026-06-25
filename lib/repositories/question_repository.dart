// lib/repositories/question_repository.dart

import '../models/question.dart';
import '../services/question_service.dart';

/// Repositorio abstracto para manejo de preguntas
abstract class QuestionRepository {
  /// Obtener todas las preguntas
  Future<List<Question>> getAllQuestions();
  
  /// Obtener preguntas por materia
  Future<List<Question>> getQuestionsBySubject(String subjectId);
  
  /// Obtener preguntas por creador
  Future<List<Question>> getQuestionsByCreator(String creatorId);
  
  /// Obtener pregunta por ID
  Future<Question?> getQuestionById(String questionId);
  
  /// Crear nueva pregunta
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
    required QuestionPurpose purpose,
  });
  
  /// Actualizar pregunta existente
  Future<Question> updateQuestion(Question question);
  
  /// Eliminar pregunta
  Future<bool> deleteQuestion(String questionId);
  
  /// Buscar preguntas por texto
  Future<List<Question>> searchQuestions(String query, String? subjectId);
  
  /// Filtrar preguntas por tipo
  Future<List<Question>> getQuestionsByType(String subjectId, QuestionType type);
  
  /// Filtrar preguntas por dificultad
  Future<List<Question>> getQuestionsByDifficulty(
    String subjectId,
    QuestionDifficulty difficulty,
  );
  
  /// Obtener preguntas aleatorias para práctica o examen
  Future<List<Question>> getRandomQuestions({
    required String subjectId,
    int count = 10,
    QuestionDifficulty? difficulty,
    String? topic,
    QuestionPurpose? purpose,
  });
  
  /// Obtener estadísticas de preguntas
  Future<QuestionStats> getQuestionStats(String subjectId);
  
  /// Verificar si usuario puede editar la pregunta
  bool canEditQuestion(Question question, String userId, String userRole);
}