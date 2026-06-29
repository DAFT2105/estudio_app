// lib/repositories/subject_repository.dart

import '../models/subject.dart';

/// Repositorio abstracto para manejo de materias
abstract class SubjectRepository {
  /// Obtener todas las materias del usuario según su rol
  Future<List<Subject>> getSubjects(String userId, String userRole);
  
  /// Obtener materia por ID
  Future<Subject?> getSubjectById(String subjectId);
  
  /// Crear nueva materia - ACTUALIZADO con duración y unidad de tiempo
  Future<Subject> createSubject({
    required String name,
    required String description,
    required String createdBy,
    SubjectColor color = SubjectColor.blue,
    SubjectIcon icon = SubjectIcon.book,
    int? estimatedDuration, // CAMBIAR AQUÍ: de estimatedHours
    TimeUnit? timeUnit, // AGREGAR AQUÍ
    String? difficulty,
    List<String> assignedStudents = const [],
    required SubjectArea area,
  });
  
  /// Actualizar materia existente
  Future<Subject> updateSubject(Subject subject);
  
  /// Eliminar materia
  Future<bool> deleteSubject(String subjectId);
  
  /// Asignar estudiante a materia
  Future<Subject> assignStudentToSubject(String subjectId, String studentId);
  
  /// Desasignar estudiante de materia
  Future<Subject> unassignStudentFromSubject(String subjectId, String studentId);
  
  /// Buscar materias por nombre
  Future<List<Subject>> searchSubjects(String query, String userId, String userRole);
  
  /// Verificar si usuario puede editar la materia
  bool canEditSubject(Subject subject, String userId, String userRole);
  
  /// Obtener materias asignadas a un estudiante específico
  Future<List<Subject>> getSubjectsForStudent(String studentId);
  
  /// Obtener estadísticas de materias
  Future<SubjectStats> getSubjectStats(String userId, String userRole);
}

/// Clase para estadísticas de materias
class SubjectStats {
  final int totalSubjects;
  final int activeSubjects;
  final int assignedStudents;
  final Map<String, int> subjectsByDifficulty;
  final int totalEstimatedMinutes; // Acumulado en minutos para mayor precisión

  const SubjectStats({
    required this.totalSubjects,
    required this.activeSubjects,
    required this.assignedStudents,
    required this.subjectsByDifficulty,
    required this.totalEstimatedMinutes,
  });
    /// Formato legible: "2h 30min", "45min", "3h"
  String get formattedTotalTime {
    if (totalEstimatedMinutes == 0) return '0min';
    final hours = totalEstimatedMinutes ~/ 60;
    final minutes = totalEstimatedMinutes % 60;
    if (hours == 0) return '${minutes}min';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}min';
  }
}