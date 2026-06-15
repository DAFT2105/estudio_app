// lib/providers/subject_provider.dart

import 'package:flutter/foundation.dart';
import '../models/subject.dart';
import '../repositories/subject_repository.dart';

// IMPORTANTE: Enum debe estar ANTES de la clase
enum SubjectStatus {
  loading,
  loaded,
  error,
  empty,
}

class SubjectProvider extends ChangeNotifier {
  final SubjectRepository _subjectRepository;
  
  List<Subject> _subjects = [];
  SubjectStatus _status = SubjectStatus.loading;
  String? _errorMessage;
  SubjectStats? _stats;
  String _searchQuery = '';
  
  // Getters
  List<Subject> get subjects => _subjects;
  SubjectStatus get status => _status;
  String? get errorMessage => _errorMessage;
  SubjectStats? get stats => _stats;
  bool get isLoading => _status == SubjectStatus.loading;
  bool get hasSubjects => _subjects.isNotEmpty;
  String get searchQuery => _searchQuery;

  // Constructor con dependency injection
  SubjectProvider({required SubjectRepository subjectRepository}) 
      : _subjectRepository = subjectRepository;

  /// Cargar materias del usuario actual
  Future<void> loadSubjects(String userId, String userRole) async {
    try {
      _setStatus(SubjectStatus.loading);
      _clearError();

      final loadedSubjects = await _subjectRepository.getSubjects(userId, userRole);
      
      _subjects = loadedSubjects;
      _setStatus(loadedSubjects.isEmpty ? SubjectStatus.empty : SubjectStatus.loaded);
      
      // Cargar estadísticas también
      await _loadStats(userId, userRole);
    } on SubjectException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Error al cargar materias: $e');
    }
  }

  /// Crear nueva materia - CORREGIDO
  Future<bool> createSubject({
    required String name,
    required String description,
    required String createdBy,
    required String userRole,
    SubjectColor color = SubjectColor.blue,
    SubjectIcon icon = SubjectIcon.book,
    int? estimatedDuration, // CORREGIDO
    TimeUnit? timeUnit, // CORREGIDO
    String? difficulty,
    List<String> assignedStudents = const [],
  }) async {
    try {
      _clearError();

      final newSubject = await _subjectRepository.createSubject(
        name: name,
        description: description,
        createdBy: createdBy,
        color: color,
        icon: icon,
        estimatedDuration: estimatedDuration, // CORREGIDO
        timeUnit: timeUnit, // CORREGIDO
        difficulty: difficulty,
        assignedStudents: assignedStudents,
      );

      // Agregar a la lista local
      _subjects.add(newSubject);
      _setStatus(SubjectStatus.loaded);
      
      // Actualizar estadísticas
      await _loadStats(createdBy, userRole);
      
      return true;
    } on SubjectException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al crear materia: $e');
      return false;
    }
  }

  /// Actualizar materia existente
  Future<bool> updateSubject(Subject subject, String userId, String userRole) async {
    try {
      _clearError();

      final updatedSubject = await _subjectRepository.updateSubject(subject);
      
      // Actualizar en la lista local
      final index = _subjects.indexWhere((s) => s.id == subject.id);
      if (index != -1) {
        _subjects[index] = updatedSubject;
        notifyListeners();
      }
      
      // Actualizar estadísticas
      await _loadStats(userId, userRole);
      
      return true;
    } on SubjectException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al actualizar materia: $e');
      return false;
    }
  }

  /// Eliminar materia
  Future<bool> deleteSubject(String subjectId, String userId, String userRole) async {
    try {
      _clearError();

      final success = await _subjectRepository.deleteSubject(subjectId);
      
      if (success) {
        // Remover de la lista local
        _subjects.removeWhere((s) => s.id == subjectId);
        _setStatus(_subjects.isEmpty ? SubjectStatus.empty : SubjectStatus.loaded);
        
        // Actualizar estadísticas
        await _loadStats(userId, userRole);
      }
      
      return success;
    } on SubjectException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al eliminar materia: $e');
      return false;
    }
  }

  /// Asignar estudiante a materia
  Future<bool> assignStudentToSubject(String subjectId, String studentId, String userId, String userRole) async {
    try {
      _clearError();

      final updatedSubject = await _subjectRepository.assignStudentToSubject(subjectId, studentId);
      
      // Actualizar en la lista local
      final index = _subjects.indexWhere((s) => s.id == subjectId);
      if (index != -1) {
        _subjects[index] = updatedSubject;
        notifyListeners();
      }
      
      // Actualizar estadísticas
      await _loadStats(userId, userRole);
      
      return true;
    } on SubjectException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al asignar estudiante: $e');
      return false;
    }
  }

  /// Desasignar estudiante de materia
  Future<bool> unassignStudentFromSubject(String subjectId, String studentId, String userId, String userRole) async {
    try {
      _clearError();

      final updatedSubject = await _subjectRepository.unassignStudentFromSubject(subjectId, studentId);
      
      // Actualizar en la lista local
      final index = _subjects.indexWhere((s) => s.id == subjectId);
      if (index != -1) {
        _subjects[index] = updatedSubject;
        notifyListeners();
      }
      
      // Actualizar estadísticas
      await _loadStats(userId, userRole);
      
      return true;
    } on SubjectException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al desasignar estudiante: $e');
      return false;
    }
  }

  /// Buscar materias
  Future<void> searchSubjects(String query, String userId, String userRole) async {
    try {
      _searchQuery = query;
      _setStatus(SubjectStatus.loading);
      _clearError();

      final searchResults = await _subjectRepository.searchSubjects(query, userId, userRole);
      
      _subjects = searchResults;
      _setStatus(searchResults.isEmpty ? SubjectStatus.empty : SubjectStatus.loaded);
    } on SubjectException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Error al buscar materias: $e');
    }
  }

  /// Limpiar búsqueda y recargar todas las materias
  Future<void> clearSearch(String userId, String userRole) async {
    _searchQuery = '';
    await loadSubjects(userId, userRole);
  }

  /// Verificar si el usuario puede editar una materia
  bool canEditSubject(Subject subject, String userId, String userRole) {
    return _subjectRepository.canEditSubject(subject, userId, userRole);
  }

  /// Obtener materia por ID
  Subject? getSubjectById(String subjectId) {
    try {
      return _subjects.firstWhere((s) => s.id == subjectId);
    } catch (e) {
      return null;
    }
  }

  /// Obtener materias filtradas por estado activo
  List<Subject> get activeSubjects {
    return _subjects.where((s) => s.isActive).toList();
  }

  /// Obtener materias agrupadas por dificultad
  Map<String, List<Subject>> get subjectsByDifficulty {
    final grouped = <String, List<Subject>>{};
    
    for (final subject in _subjects) {
      final difficulty = subject.difficulty ?? 'Medio';
      grouped[difficulty] = grouped[difficulty] ?? [];
      grouped[difficulty]!.add(subject);
    }
    
    return grouped;
  }

  // Métodos privados

  /// Cargar estadísticas
  Future<void> _loadStats(String userId, String userRole) async {
    try {
      _stats = await _subjectRepository.getSubjectStats(userId, userRole);
      notifyListeners();
    } catch (e) {
      // No mostrar error para estadísticas, solo log
      debugPrint('Error al cargar estadísticas: $e');
    }
  }

  /// Establecer estado
  void _setStatus(SubjectStatus status) {
    _status = status;
    notifyListeners();
  }

  /// Establecer error
  void _setError(String message) {
    _errorMessage = message;
    _status = SubjectStatus.error;
    notifyListeners();
  }

  /// Limpiar error
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refrescar datos
  Future<void> refresh(String userId, String userRole) async {
    await loadSubjects(userId, userRole);
  }
}