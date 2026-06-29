// lib/repositories/student_repository.dart

import '../models/student.dart';
import '../services/student_service.dart';

/// Repositorio abstracto para manejo de estudiantes
abstract class StudentRepository {
  /// Obtener todos los estudiantes de un padre específico
  Future<List<Student>> getStudentsByParent(String parentId);

  /// Obtener estudiante por ID
  Future<Student?> getStudentById(String studentId);

  /// Crear nuevo estudiante.
  /// Devuelve el Student creado junto con la clave temporal generada
  /// (solo existe en este momento — nunca se persiste en Firestore).
  Future<({Student student, String temporaryPassword})> createStudent({
    required String nombres,
    required String apellidos,
    String? email,
    required String parentId,
    StudentGrade grade = StudentGrade.primaria,
    int? gradeLevel,
    DateTime? birthDate,
    String? notes,
    StudentAvatar avatar = StudentAvatar.student1,
  });

  /// Actualizar estudiante existente
  Future<Student> updateStudent(Student student);

  /// Eliminar estudiante
  Future<bool> deleteStudent(String studentId);

  /// Asignar materia a estudiante
  Future<Student> assignSubjectToStudent(String studentId, String subjectId);

  /// Desasignar materia de estudiante
  Future<Student> unassignSubjectFromStudent(String studentId, String subjectId);

  /// Buscar estudiantes por nombre dentro de un padre
  Future<List<Student>> searchStudents(String query, String parentId);

  /// Verificar si usuario puede editar el estudiante
  bool canEditStudent(Student student, String userId, String userRole);

  /// Obtener estudiantes que tienen una materia específica asignada
  Future<List<Student>> getStudentsWithSubject(String subjectId);

  /// Obtener estadísticas de estudiantes para un padre
  Future<StudentStats> getStudentStats(String parentId);

  /// Obtener todos los estudiantes (solo para admin)
  Future<List<Student>> getAllStudents();

  /// Verificar si un email ya está en uso por otro estudiante
  Future<bool> isEmailInUse(String email, {String? excludeStudentId});
}