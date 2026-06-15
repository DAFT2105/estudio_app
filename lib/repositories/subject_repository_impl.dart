// lib/repositories/subject_repository_impl.dart

import '../models/subject.dart';
import '../services/subject_service.dart';
import 'subject_repository.dart';

class SubjectRepositoryImpl implements SubjectRepository {
  final SubjectService _subjectService;

  SubjectRepositoryImpl({SubjectService? subjectService})
      : _subjectService = subjectService ?? SubjectService();

  @override
  Future<List<Subject>> getSubjects(String userId, String userRole) async {
    try {
      return await _subjectService.getSubjectsByUser(userId, userRole);
    } catch (e) {
      throw SubjectException('Error al obtener materias: $e');
    }
  }

  @override
  Future<Subject?> getSubjectById(String subjectId) async {
    try {
      return await _subjectService.getSubjectById(subjectId);
    } catch (e) {
      throw SubjectException('Error al obtener materia: $e');
    }
  }

  @override
  Future<Subject> createSubject({
    required String name,
    required String description,
    required String createdBy,
    SubjectColor color = SubjectColor.blue,
    SubjectIcon icon = SubjectIcon.book,
    int? estimatedDuration,
    TimeUnit? timeUnit,
    String? difficulty,
    List<String> assignedStudents = const [],
  }) async {
    try {
      if (name.trim().isEmpty) {
        throw SubjectException('El nombre de la materia es requerido');
      }
      if (description.trim().isEmpty) {
        throw SubjectException('La descripción es requerida');
      }
      if (name.length > 50) {
        throw SubjectException('El nombre no puede exceder 50 caracteres');
      }
      if (description.length > 200) {
        throw SubjectException('La descripción no puede exceder 200 caracteres');
      }

      // Verificar nombre duplicado solo entre las materias del creador
      // Usa getSubjectsByUser con rol 'parent' para respetar las reglas de Firestore
      final existingSubjects = await _subjectService.getSubjectsByUser(
        createdBy,
        'parent',
      );
      final nameExists = existingSubjects.any(
        (s) => s.name.toLowerCase() == name.toLowerCase().trim(),
      );
      if (nameExists) {
        throw SubjectException('Ya existe una materia con ese nombre');
      }

      return await _subjectService.createSubject(
        name: name.trim(),
        description: description.trim(),
        createdBy: createdBy,
        color: color,
        icon: icon,
        estimatedDuration: estimatedDuration,
        timeUnit: timeUnit,
        difficulty: difficulty,
        assignedStudents: assignedStudents,
      );
    } on SubjectException {
      rethrow;
    } catch (e) {
      throw SubjectException('Error al crear materia: $e');
    }
  }

  @override
  Future<Subject> updateSubject(Subject subject) async {
    try {
      if (subject.name.trim().isEmpty) {
        throw SubjectException('El nombre de la materia es requerido');
      }
      if (subject.description.trim().isEmpty) {
        throw SubjectException('La descripción es requerida');
      }

      // Verificar nombre duplicado solo entre las materias del creador
      final existingSubjects = await _subjectService.getSubjectsByUser(
        subject.createdBy,
        'parent',
      );
      final nameExists = existingSubjects.any(
        (s) =>
            s.name.toLowerCase() == subject.name.toLowerCase().trim() &&
            s.id != subject.id,
      );
      if (nameExists) {
        throw SubjectException('Ya existe otra materia con ese nombre');
      }

      return await _subjectService.updateSubject(subject);
    } on SubjectException {
      rethrow;
    } catch (e) {
      throw SubjectException('Error al actualizar materia: $e');
    }
  }

  @override
  Future<bool> deleteSubject(String subjectId) async {
    try {
      return await _subjectService.deleteSubject(subjectId);
    } on SubjectException {
      rethrow;
    } catch (e) {
      throw SubjectException('Error al eliminar materia: $e');
    }
  }

  @override
  Future<Subject> assignStudentToSubject(
      String subjectId, String studentId) async {
    try {
      return await _subjectService.assignStudentToSubject(subjectId, studentId);
    } on SubjectException {
      rethrow;
    } catch (e) {
      throw SubjectException('Error al asignar estudiante: $e');
    }
  }

  @override
  Future<Subject> unassignStudentFromSubject(
      String subjectId, String studentId) async {
    try {
      return await _subjectService.unassignStudentFromSubject(
          subjectId, studentId);
    } on SubjectException {
      rethrow;
    } catch (e) {
      throw SubjectException('Error al desasignar estudiante: $e');
    }
  }

  @override
  Future<List<Subject>> searchSubjects(
      String query, String userId, String userRole) async {
    try {
      if (query.trim().isEmpty) {
        return await getSubjects(userId, userRole);
      }
      return await _subjectService.searchSubjects(query.trim(), userId, userRole);
    } catch (e) {
      throw SubjectException('Error al buscar materias: $e');
    }
  }

  @override
  bool canEditSubject(Subject subject, String userId, String userRole) {
    return subject.canEdit(userId, userRole);
  }

  @override
  Future<List<Subject>> getSubjectsForStudent(String studentId) async {
    try {
      // Usa el rol 'student' para filtrar por assignedStudents en Firestore
      // Respeta las reglas de seguridad sin llamar getAllSubjects()
      return await _subjectService.getSubjectsByUser(studentId, 'student');
    } catch (e) {
      throw SubjectException('Error al obtener materias del estudiante: $e');
    }
  }

  @override
  Future<SubjectStats> getSubjectStats(String userId, String userRole) async {
    try {
      final subjects = await getSubjects(userId, userRole);

      final difficultyCount = <String, int>{
        'Fácil': 0,
        'Medio': 0,
        'Difícil': 0,
      };

      int totalEstimatedMinutes = 0;
      int totalAssignedStudents = 0;

      for (final subject in subjects) {
        final difficulty = subject.difficulty ?? 'Medio';
        difficultyCount[difficulty] = (difficultyCount[difficulty] ?? 0) + 1;

        if (subject.estimatedDuration != null && subject.timeUnit != null) {
          if (subject.timeUnit == TimeUnit.hours) {
            totalEstimatedMinutes += subject.estimatedDuration! * 60;
          } else if (subject.timeUnit == TimeUnit.minutes) {
            totalEstimatedMinutes += subject.estimatedDuration!;
          }
        }

        totalAssignedStudents += subject.assignedStudents.length;
      }

      return SubjectStats(
        totalSubjects: subjects.length,
        activeSubjects: subjects.where((s) => s.isActive).length,
        assignedStudents: totalAssignedStudents,
        subjectsByDifficulty: difficultyCount,
        totalEstimatedMinutes: totalEstimatedMinutes,
      );
    } catch (e) {
      throw SubjectException('Error al obtener estadísticas: $e');
    }
  }
}