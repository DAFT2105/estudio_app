// lib/services/question_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question.dart';

class QuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'questions';

  // ─────────────────────────────────────────────
  // HELPERS PRIVADOS
  // ─────────────────────────────────────────────

  /// Convierte un DocumentSnapshot de Firestore a Question
  Question _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Question.fromJson({
      ...data,
      'id': doc.id,
      'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
      'updatedAt': data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate().toIso8601String()
          : null,
    });
  }

  /// Convierte un Question a Map para guardar en Firestore
  Map<String, dynamic> _toFirestore(Question question) {
    final json = question.toJson();
    return {
      ...json,
      'createdAt': Timestamp.fromDate(question.createdAt),
      'updatedAt': question.updatedAt != null
          ? Timestamp.fromDate(question.updatedAt!)
          : null,
    };
  }

  // ─────────────────────────────────────────────
  // MÉTODOS PÚBLICOS — misma interfaz que antes
  // ─────────────────────────────────────────────

  /// Obtener todas las preguntas activas (solo admin)
  Future<List<Question>> getAllQuestions() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw QuestionException('Error al obtener preguntas: $e');
    }
  }

  /// Obtener preguntas activas de una materia
  Future<List<Question>> getQuestionsBySubject(String subjectId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('subjectId', isEqualTo: subjectId)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw QuestionException('Error al obtener preguntas por materia: $e');
    }
  }

  /// Obtener preguntas activas de un creador
  Future<List<Question>> getQuestionsByCreator(String creatorId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('createdBy', isEqualTo: creatorId)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw QuestionException('Error al obtener preguntas por creador: $e');
    }
  }

  /// Obtener pregunta por ID
  Future<Question?> getQuestionById(String questionId) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(questionId).get();
      if (!doc.exists) return null;
      return _fromDoc(doc);
    } catch (e) {
      throw QuestionException('Error al obtener pregunta: $e');
    }
  }

  /// Crear nueva pregunta en Firestore
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
      final docRef = _firestore.collection(_collection).doc();

      final question = Question(
        id: docRef.id,
        subjectId: subjectId,
        createdBy: createdBy,
        text: text,
        type: type,
        options: options,
        correctAnswer: correctAnswer,
        explanation: explanation,
        topic: topic,
        difficulty: difficulty,
        createdAt: DateTime.now(),
      );

      // Validar antes de guardar — misma lógica que antes
      if (!question.isValid) {
        throw QuestionException('La pregunta no es válida');
      }

      await docRef.set(_toFirestore(question));
      return question;
    } catch (e) {
      if (e is QuestionException) rethrow;
      throw QuestionException('Error al crear pregunta: $e');
    }
  }

  /// Actualizar pregunta existente en Firestore
  Future<Question> updateQuestion(Question question) async {
    try {
      if (!question.isValid) {
        throw QuestionException('La pregunta no es válida');
      }

      final updatedQuestion = question.copyWith(updatedAt: DateTime.now());

      await _firestore
          .collection(_collection)
          .doc(question.id)
          .update(_toFirestore(updatedQuestion));

      return updatedQuestion;
    } catch (e) {
      if (e is QuestionException) rethrow;
      throw QuestionException('Error al actualizar pregunta: $e');
    }
  }

  /// Eliminar pregunta — soft delete (isActive: false)
  /// Preserva integridad con resultados históricos que referencian la pregunta
  Future<bool> deleteQuestion(String questionId) async {
    try {
      await _firestore.collection(_collection).doc(questionId).update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      throw QuestionException('Error al eliminar pregunta: $e');
    }
  }

  /// Buscar preguntas por texto, tema o explicación
  /// Firestore no tiene full-text — se filtra en memoria sobre la materia
  Future<List<Question>> searchQuestions(
      String query, String? subjectId) async {
    final questions = subjectId != null
        ? await getQuestionsBySubject(subjectId)
        : await getAllQuestions();

    final lowercaseQuery = query.toLowerCase();

    return questions
        .where((question) =>
            question.text.toLowerCase().contains(lowercaseQuery) ||
            (question.topic?.toLowerCase().contains(lowercaseQuery) ?? false) ||
            (question.explanation?.toLowerCase().contains(lowercaseQuery) ??
                false))
        .toList();
  }

  /// Filtrar preguntas por tipo dentro de una materia
  Future<List<Question>> getQuestionsByType(
      String subjectId, QuestionType type) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('subjectId', isEqualTo: subjectId)
          .where('type', isEqualTo: type.toString().split('.').last)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw QuestionException('Error al filtrar por tipo: $e');
    }
  }

  /// Filtrar preguntas por dificultad dentro de una materia
  Future<List<Question>> getQuestionsByDifficulty(
      String subjectId, QuestionDifficulty difficulty) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('subjectId', isEqualTo: subjectId)
          .where('difficulty',
              isEqualTo: difficulty.toString().split('.').last)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw QuestionException('Error al filtrar por dificultad: $e');
    }
  }

  /// Obtener preguntas aleatorias para práctica o examen
  /// Se trae todo el set y se mezcla en memoria — shuffle no existe en Firestore
  Future<List<Question>> getRandomQuestions({
    required String subjectId,
    int count = 10,
    QuestionDifficulty? difficulty,
    String? topic,
  }) async {
    try {
      var questions = await getQuestionsBySubject(subjectId);

      // Filtrar por dificultad si se especifica
      if (difficulty != null) {
        questions =
            questions.where((q) => q.difficulty == difficulty).toList();
      }

      // Filtrar por tema si se especifica
      if (topic != null && topic.isNotEmpty) {
        questions = questions
            .where((q) => q.topic?.toLowerCase() == topic.toLowerCase())
            .toList();
      }

      // Mezclar en memoria y tomar la cantidad solicitada
      questions.shuffle();
      return questions.take(count).toList();
    } catch (e) {
      throw QuestionException('Error al obtener preguntas aleatorias: $e');
    }
  }

  /// Obtener estadísticas de preguntas por materia
  /// Se calcula en memoria — evita múltiples queries a Firestore
  Future<QuestionStats> getQuestionStats(String subjectId) async {
    final questions = await getQuestionsBySubject(subjectId);

    final typeCount = <QuestionType, int>{
      QuestionType.multipleChoice: 0,
      QuestionType.trueFalse: 0,
      QuestionType.shortAnswer: 0,
    };

    final difficultyCount = <QuestionDifficulty, int>{
      QuestionDifficulty.easy: 0,
      QuestionDifficulty.medium: 0,
      QuestionDifficulty.hard: 0,
    };

    final topics = <String>{};

    for (final question in questions) {
      typeCount[question.type] = (typeCount[question.type] ?? 0) + 1;
      difficultyCount[question.difficulty] =
          (difficultyCount[question.difficulty] ?? 0) + 1;

      if (question.topic != null && question.topic!.isNotEmpty) {
        topics.add(question.topic!);
      }
    }

    return QuestionStats(
      totalQuestions: questions.length,
      questionsByType: typeCount,
      questionsByDifficulty: difficultyCount,
      uniqueTopics: topics.length,
      topicsList: topics.toList()..sort(),
    );
  }

  /// Obtener conteo total de preguntas activas
  /// Usa .count() de Firestore — no descarga documentos, solo cuenta
  Future<int> getTotalQuestionCount() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw QuestionException('Error al obtener conteo de preguntas: $e');
    }
  }

  /// Limpiar todas las preguntas — SOLO para testing
  Future<void> clearAllQuestions() async {
    final snapshot = await _firestore.collection(_collection).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

/// Clase para estadísticas de preguntas — sin cambios
class QuestionStats {
  final int totalQuestions;
  final Map<QuestionType, int> questionsByType;
  final Map<QuestionDifficulty, int> questionsByDifficulty;
  final int uniqueTopics;
  final List<String> topicsList;

  const QuestionStats({
    required this.totalQuestions,
    required this.questionsByType,
    required this.questionsByDifficulty,
    required this.uniqueTopics,
    required this.topicsList,
  });
}