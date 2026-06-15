// lib/providers/student_provider.dart

import 'package:flutter/foundation.dart';
import '../models/student.dart';
import '../repositories/student_repository.dart';
import '../services/student_service.dart'; // ← esta línea debe estar

enum StudentStatus {
  loading,
  loaded,
  error,
  empty,
}

class StudentProvider extends ChangeNotifier {
  final StudentRepository _studentRepository;
  
  List<Student> _students = [];
  StudentStatus _status = StudentStatus.loading;
  String? _errorMessage;
  StudentStats? _stats;
  String _searchQuery = '';
  
  // Getters
  List<Student> get students => _students;
  StudentStatus get status => _status;
  String? get errorMessage => _errorMessage;
  StudentStats? get stats => _stats;
  bool get isLoading => _status == StudentStatus.loading;
  bool get hasStudents => _students.isNotEmpty;
  String get searchQuery => _searchQuery;

  // Constructor con dependency injection
  StudentProvider({required StudentRepository studentRepository}) 
      : _studentRepository = studentRepository;

  /// Cargar estudiantes del padre actual
  Future<void> loadStudents(String parentId) async {
    try {
      _setStatus(StudentStatus.loading);
      _clearError();

      final loadedStudents = await _studentRepository.getStudentsByParent(parentId);
      
      _students = loadedStudents;
      _setStatus(loadedStudents.isEmpty ? StudentStatus.empty : StudentStatus.loaded);
      
      // Cargar estadísticas también
      await _loadStats(parentId);
    } on StudentException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Error al cargar estudiantes: $e');
    }
  }

  /// Crear nuevo estudiante
  Future<bool> createStudent({
    required String name,
    required String email,
    required String parentId,
    StudentGrade grade = StudentGrade.primaria,
    DateTime? birthDate,
    String? notes,
    StudentAvatar avatar = StudentAvatar.student1,
  }) async {
    try {
      _clearError();

      final newStudent = await _studentRepository.createStudent(
        name: name,
        email: email,
        parentId: parentId,
        grade: grade,
        birthDate: birthDate,
        notes: notes,
        avatar: avatar,
      );

      // Agregar a la lista local
      _students.add(newStudent);
      _setStatus(StudentStatus.loaded);
      
      // Actualizar estadísticas
      await _loadStats(parentId);
      
      return true;
    } on StudentException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al crear estudiante: $e');
      return false;
    }
  }

  /// Actualizar estudiante existente
  Future<bool> updateStudent(Student student, String parentId) async {
    try {
      _clearError();

      final updatedStudent = await _studentRepository.updateStudent(student);
      
      // Actualizar en la lista local
      final index = _students.indexWhere((s) => s.id == student.id);
      if (index != -1) {
        _students[index] = updatedStudent;
        notifyListeners();
      }
      
      // Actualizar estadísticas
      await _loadStats(parentId);
      
      return true;
    } on StudentException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al actualizar estudiante: $e');
      return false;
    }
  }

  /// Eliminar estudiante
  Future<bool> deleteStudent(String studentId, String parentId) async {
    try {
      _clearError();

      final success = await _studentRepository.deleteStudent(studentId);
      
      if (success) {
        // Remover de la lista local
        _students.removeWhere((s) => s.id == studentId);
        _setStatus(_students.isEmpty ? StudentStatus.empty : StudentStatus.loaded);
        
        // Actualizar estadísticas
        await _loadStats(parentId);
      }
      
      return success;
    } on StudentException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al eliminar estudiante: $e');
      return false;
    }
  }

  /// Asignar materia a estudiante
  Future<bool> assignSubjectToStudent(String studentId, String subjectId, String parentId) async {
    try {
      _clearError();

      final updatedStudent = await _studentRepository.assignSubjectToStudent(studentId, subjectId);
      
      // Actualizar en la lista local
      final index = _students.indexWhere((s) => s.id == studentId);
      if (index != -1) {
        _students[index] = updatedStudent;
        notifyListeners();
      }
      
      // Actualizar estadísticas
      await _loadStats(parentId);
      
      return true;
    } on StudentException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al asignar materia: $e');
      return false;
    }
  }

  /// Desasignar materia de estudiante
  Future<bool> unassignSubjectFromStudent(String studentId, String subjectId, String parentId) async {
    try {
      _clearError();

      final updatedStudent = await _studentRepository.unassignSubjectFromStudent(studentId, subjectId);
      
      // Actualizar en la lista local
      final index = _students.indexWhere((s) => s.id == studentId);
      if (index != -1) {
        _students[index] = updatedStudent;
        notifyListeners();
      }
      
      // Actualizar estadísticas
      await _loadStats(parentId);
      
      return true;
    } on StudentException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al desasignar materia: $e');
      return false;
    }
  }

  /// Buscar estudiantes
  Future<void> searchStudents(String query, String parentId) async {
    try {
      _searchQuery = query;
      _setStatus(StudentStatus.loading);
      _clearError();

      final searchResults = await _studentRepository.searchStudents(query, parentId);
      
      _students = searchResults;
      _setStatus(searchResults.isEmpty ? StudentStatus.empty : StudentStatus.loaded);
    } on StudentException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Error al buscar estudiantes: $e');
    }
  }

  /// Limpiar búsqueda y recargar todos los estudiantes
  Future<void> clearSearch(String parentId) async {
    _searchQuery = '';
    await loadStudents(parentId);
  }

  /// Verificar si el usuario puede editar un estudiante
  bool canEditStudent(Student student, String userId, String userRole) {
    return _studentRepository.canEditStudent(student, userId, userRole);
  }

  /// Obtener estudiante por ID
  Student? getStudentById(String studentId) {
    try {
      return _students.firstWhere((s) => s.id == studentId);
    } catch (e) {
      return null;
    }
  }

  /// Obtener estudiantes filtrados por estado activo
  List<Student> get activeStudents {
    return _students.where((s) => s.isActive).toList();
  }

  /// Obtener estudiantes agrupados por grado
  Map<StudentGrade, List<Student>> get studentsByGrade {
    final grouped = <StudentGrade, List<Student>>{};
    
    for (final student in _students) {
      grouped[student.grade] = grouped[student.grade] ?? [];
      grouped[student.grade]!.add(student);
    }
    
    return grouped;
  }

  /// Obtener estudiantes con materias asignadas
  List<Student> get studentsWithSubjects {
    return _students.where((s) => s.assignedSubjects.isNotEmpty).toList();
  }

  /// Obtener estudiantes sin materias asignadas
  List<Student> get studentsWithoutSubjects {
    return _students.where((s) => s.assignedSubjects.isEmpty).toList();
  }

  // Métodos privados

  /// Cargar estadísticas
  Future<void> _loadStats(String parentId) async {
    try {
      _stats = await _studentRepository.getStudentStats(parentId);
      notifyListeners();
    } catch (e) {
      // No mostrar error para estadísticas, solo log
      debugPrint('Error al cargar estadísticas de estudiantes: $e');
    }
  }

  /// Establecer estado
  void _setStatus(StudentStatus status) {
    _status = status;
    notifyListeners();
  }

  /// Establecer error
  void _setError(String message) {
    _errorMessage = message;
    _status = StudentStatus.error;
    notifyListeners();
  }

  /// Limpiar error
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refrescar datos
  Future<void> refresh(String parentId) async {
    await loadStudents(parentId);
  }

  /// Obtener estudiantes que pueden recibir una materia específica
  List<Student> getStudentsEligibleForSubject(String subjectId) {
    return _students.where((student) => 
        student.isActive && !student.isAssignedToSubject(subjectId)
    ).toList();
  }

  /// Obtener total de materias asignadas a todos los estudiantes
  int get totalAssignedSubjects {
    return _students.fold(0, (total, student) => total + student.subjectCount);
  }
}

