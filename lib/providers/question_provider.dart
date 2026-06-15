// lib/providers/question_provider.dart

import 'package:flutter/foundation.dart';
import '../models/question.dart';
import '../repositories/question_repository.dart';
import '../services/question_service.dart';

enum QuestionStatus {
  loading,
  loaded,
  error,
  empty,
}

class QuestionProvider extends ChangeNotifier {
  final QuestionRepository _questionRepository;
  
  List<Question> _questions = [];
  QuestionStatus _status = QuestionStatus.loading;
  String? _errorMessage;
  QuestionStats? _stats;
  String _searchQuery = '';
  String? _currentSubjectId;
  
  // Getters
  List<Question> get questions => _questions;
  QuestionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  QuestionStats? get stats => _stats;
  bool get isLoading => _status == QuestionStatus.loading;
  bool get hasQuestions => _questions.isNotEmpty;
  String get searchQuery => _searchQuery;
  String? get currentSubjectId => _currentSubjectId;

  // Constructor con dependency injection
  QuestionProvider({required QuestionRepository questionRepository}) 
      : _questionRepository = questionRepository;

  /// Cargar preguntas de una materia
  Future<void> loadQuestionsBySubject(String subjectId) async {
    try {
      _currentSubjectId = subjectId;
      _setStatus(QuestionStatus.loading);
      _clearError();

      final loadedQuestions = await _questionRepository.getQuestionsBySubject(subjectId);
      
      _questions = loadedQuestions;
      _setStatus(loadedQuestions.isEmpty ? QuestionStatus.empty : QuestionStatus.loaded);
      
      // Cargar estadísticas también
      await _loadStats(subjectId);
    } on QuestionException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Error al cargar preguntas: $e');
    }
  }

  /// Cargar todas las preguntas del creador
  Future<void> loadQuestionsByCreator(String creatorId) async {
    try {
      _currentSubjectId = null;
      _setStatus(QuestionStatus.loading);
      _clearError();

      final loadedQuestions = await _questionRepository.getQuestionsByCreator(creatorId);
      
      _questions = loadedQuestions;
      _setStatus(loadedQuestions.isEmpty ? QuestionStatus.empty : QuestionStatus.loaded);
    } on QuestionException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Error al cargar preguntas: $e');
    }
  }

  /// Crear nueva pregunta
  Future<bool> createQuestion({
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
      _clearError();

      final newQuestion = await _questionRepository.createQuestion(
        subjectId: subjectId,
        createdBy: createdBy,
        text: text,
        type: type,
        options: options,
        correctAnswer: correctAnswer,
        explanation: explanation,
        topic: topic,
        difficulty: difficulty,
      );

      // Agregar a la lista local
      _questions.add(newQuestion);
      _setStatus(QuestionStatus.loaded);
      
      // Actualizar estadísticas
      if (_currentSubjectId == subjectId) {
        await _loadStats(subjectId);
      }
      
      return true;
    } on QuestionException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al crear pregunta: $e');
      return false;
    }
  }

  /// Actualizar pregunta existente
  Future<bool> updateQuestion(Question question) async {
    try {
      _clearError();

      final updatedQuestion = await _questionRepository.updateQuestion(question);
      
      // Actualizar en la lista local
      final index = _questions.indexWhere((q) => q.id == question.id);
      if (index != -1) {
        _questions[index] = updatedQuestion;
        notifyListeners();
      }
      
      // Actualizar estadísticas si es de la materia actual
      if (_currentSubjectId == question.subjectId) {
        await _loadStats(question.subjectId);
      }
      
      return true;
    } on QuestionException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al actualizar pregunta: $e');
      return false;
    }
  }

  /// Eliminar pregunta
  Future<bool> deleteQuestion(String questionId) async {
    try {
      _clearError();

      final success = await _questionRepository.deleteQuestion(questionId);
      
      if (success) {
        final deletedQuestion = _questions.firstWhere((q) => q.id == questionId);
        
        // Remover de la lista local
        _questions.removeWhere((q) => q.id == questionId);
        _setStatus(_questions.isEmpty ? QuestionStatus.empty : QuestionStatus.loaded);
        
        // Actualizar estadísticas
        if (_currentSubjectId == deletedQuestion.subjectId) {
          await _loadStats(deletedQuestion.subjectId);
        }
      }
      
      return success;
    } on QuestionException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al eliminar pregunta: $e');
      return false;
    }
  }

  /// Buscar preguntas
  Future<void> searchQuestions(String query, String? subjectId) async {
    try {
      _searchQuery = query;
      _setStatus(QuestionStatus.loading);
      _clearError();

      final searchResults = await _questionRepository.searchQuestions(query, subjectId);
      
      _questions = searchResults;
      _setStatus(searchResults.isEmpty ? QuestionStatus.empty : QuestionStatus.loaded);
    } on QuestionException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Error al buscar preguntas: $e');
    }
  }

  /// Limpiar búsqueda
  Future<void> clearSearch(String? subjectId) async {
    _searchQuery = '';
    if (subjectId != null) {
      await loadQuestionsBySubject(subjectId);
    } else {
      _questions = [];
      _setStatus(QuestionStatus.empty);
    }
  }

  /// Filtrar por tipo
  Future<void> filterByType(String subjectId, QuestionType type) async {
    try {
      _setStatus(QuestionStatus.loading);
      _clearError();

      final filtered = await _questionRepository.getQuestionsByType(subjectId, type);
      
      _questions = filtered;
      _setStatus(filtered.isEmpty ? QuestionStatus.empty : QuestionStatus.loaded);
    } on QuestionException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Error al filtrar preguntas: $e');
    }
  }

  /// Filtrar por dificultad
  Future<void> filterByDifficulty(String subjectId, QuestionDifficulty difficulty) async {
    try {
      _setStatus(QuestionStatus.loading);
      _clearError();

      final filtered = await _questionRepository.getQuestionsByDifficulty(subjectId, difficulty);
      
      _questions = filtered;
      _setStatus(filtered.isEmpty ? QuestionStatus.empty : QuestionStatus.loaded);
    } on QuestionException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Error al filtrar preguntas: $e');
    }
  }

  /// Obtener preguntas aleatorias
  Future<List<Question>> getRandomQuestions({
    required String subjectId,
    int count = 10,
    QuestionDifficulty? difficulty,
    String? topic,
  }) async {
    try {
      return await _questionRepository.getRandomQuestions(
        subjectId: subjectId,
        count: count,
        difficulty: difficulty,
        topic: topic,
      );
    } on QuestionException catch (e) {
      _setError(e.message);
      return [];
    } catch (e) {
      _setError('Error al obtener preguntas aleatorias: $e');
      return [];
    }
  }

  /// Verificar si el usuario puede editar una pregunta
  bool canEditQuestion(Question question, String userId, String userRole) {
    return _questionRepository.canEditQuestion(question, userId, userRole);
  }

  /// Obtener pregunta por ID
  Question? getQuestionById(String questionId) {
    try {
      return _questions.firstWhere((q) => q.id == questionId);
    } catch (e) {
      return null;
    }
  }

  /// Obtener preguntas filtradas por estado activo
  List<Question> get activeQuestions {
    return _questions.where((q) => q.isActive).toList();
  }

  /// Obtener preguntas agrupadas por dificultad
  Map<QuestionDifficulty, List<Question>> get questionsByDifficulty {
    final grouped = <QuestionDifficulty, List<Question>>{};
    
    for (final question in _questions) {
      grouped[question.difficulty] = grouped[question.difficulty] ?? [];
      grouped[question.difficulty]!.add(question);
    }
    
    return grouped;
  }

  /// Obtener preguntas agrupadas por tipo
  Map<QuestionType, List<Question>> get questionsByType {
    final grouped = <QuestionType, List<Question>>{};
    
    for (final question in _questions) {
      grouped[question.type] = grouped[question.type] ?? [];
      grouped[question.type]!.add(question);
    }
    
    return grouped;
  }

  /// Obtener temas únicos
  List<String> get uniqueTopics {
    final topics = <String>{};
    
    for (final question in _questions) {
      if (question.topic != null && question.topic!.isNotEmpty) {
        topics.add(question.topic!);
      }
    }
    
    return topics.toList()..sort();
  }

  // Métodos privados

  /// Cargar estadísticas
  Future<void> _loadStats(String subjectId) async {
    try {
      _stats = await _questionRepository.getQuestionStats(subjectId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar estadísticas de preguntas: $e');
    }
  }

  /// Establecer estado
  void _setStatus(QuestionStatus status) {
    _status = status;
    notifyListeners();
  }

  /// Establecer error
  void _setError(String message) {
    _errorMessage = message;
    _status = QuestionStatus.error;
    notifyListeners();
  }

  /// Limpiar error
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refrescar datos
  Future<void> refresh(String? subjectId) async {
    if (subjectId != null) {
      await loadQuestionsBySubject(subjectId);
    }
  }
}