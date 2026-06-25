// lib/repositories/student_repository_impl.dart

import '../models/student.dart';
import '../services/student_service.dart';
import 'student_repository.dart';

class StudentRepositoryImpl implements StudentRepository {
  final StudentService _studentService;

  StudentRepositoryImpl({StudentService? studentService})
      : _studentService = studentService ?? StudentService();

  @override
  Future<List<Student>> getStudentsByParent(String parentId) async {
    try {
      return await _studentService.getStudentsByParent(parentId);
    } catch (e) {
      throw StudentException('Error al obtener estudiantes: $e');
    }
  }

  @override
  Future<Student?> getStudentById(String studentId) async {
    try {
      return await _studentService.getStudentById(studentId);
    } catch (e) {
      throw StudentException('Error al obtener estudiante: $e');
    }
  }

  @override
  Future<({Student student, String temporaryPassword})> createStudent({
    required String nombres,
    required String apellidos,
    String? email,
    required String parentId,
    StudentGrade grade = StudentGrade.primaria,
    DateTime? birthDate,
    String? notes,
    StudentAvatar avatar = StudentAvatar.student1,
  }) async {
    try {
      // Validaciones de formato — la generación del username y la
      // creación de la cuenta Auth las maneja el servicio
      if (nombres.trim().isEmpty) {
        throw StudentException('Los nombres del estudiante son requeridos');
      }
      if (apellidos.trim().isEmpty) {
        throw StudentException('Los apellidos del estudiante son requeridos');
      }
      if (nombres.length > 50) {
        throw StudentException('Los nombres no pueden exceder 50 caracteres');
      }
      if (apellidos.length > 50) {
        throw StudentException('Los apellidos no pueden exceder 50 caracteres');
      }
      // El email es opcional — solo se valida formato si el padre lo ingresó
      if (email != null && email.trim().isNotEmpty && !_isValidEmail(email)) {
        throw StudentException('Formato de email inválido');
      }
      if (birthDate != null) {
        final now = DateTime.now();
        if (birthDate.isAfter(now)) {
          throw StudentException('La fecha de nacimiento no puede ser futura');
        }
        final age = now.year - birthDate.year;
        if (age > 25) {
          throw StudentException('La edad no puede ser mayor a 25 años');
        }
      }

      return await _studentService.createStudent(
        nombres: nombres.trim(),
        apellidos: apellidos.trim(),
        email: email?.trim(),
        parentId: parentId,
        grade: grade,
        birthDate: birthDate,
        notes: notes?.trim(),
        avatar: avatar,
      );
    } on StudentException {
      rethrow;
    } catch (e) {
      throw StudentException('Error al crear estudiante: $e');
    }
  }

  @override
  Future<Student> updateStudent(Student student) async {
    try {
      if (student.nombres.trim().isEmpty) {
        throw StudentException('Los nombres del estudiante son requeridos');
      }
      if (student.apellidos.trim().isEmpty) {
        throw StudentException('Los apellidos del estudiante son requeridos');
      }
      // El email es opcional — solo se valida si está presente
      if (student.email != null &&
          student.email!.trim().isNotEmpty &&
          !_isValidEmail(student.email!)) {
        throw StudentException('Formato de email inválido');
      }

      // Verificar email duplicado excluyendo el propio estudiante
      // (solo aplica si el estudiante tiene un email asignado)
      if (student.email != null && student.email!.trim().isNotEmpty) {
        final emailInUse = await _studentService.isEmailInUse(
          student.email!,
          excludeStudentId: student.id,
          parentId: student.parentId,
        );
        if (emailInUse) {
          throw StudentException('Ya existe otro estudiante con ese email');
        }
      }

      return await _studentService.updateStudent(student);
    } on StudentException {
      rethrow;
    } catch (e) {
      throw StudentException('Error al actualizar estudiante: $e');
    }
  }

  @override
  Future<bool> deleteStudent(String studentId) async {
    try {
      return await _studentService.deleteStudent(studentId);
    } on StudentException {
      rethrow;
    } catch (e) {
      throw StudentException('Error al eliminar estudiante: $e');
    }
  }

  @override
  Future<Student> assignSubjectToStudent(
      String studentId, String subjectId) async {
    try {
      return await _studentService.assignSubjectToStudent(studentId, subjectId);
    } on StudentException {
      rethrow;
    } catch (e) {
      throw StudentException('Error al asignar materia: $e');
    }
  }

  @override
  Future<Student> unassignSubjectFromStudent(
      String studentId, String subjectId) async {
    try {
      return await _studentService.unassignSubjectFromStudent(
          studentId, subjectId);
    } on StudentException {
      rethrow;
    } catch (e) {
      throw StudentException('Error al desasignar materia: $e');
    }
  }

  @override
  Future<List<Student>> searchStudents(String query, String parentId) async {
    try {
      if (query.trim().isEmpty) {
        return await getStudentsByParent(parentId);
      }
      return await _studentService.searchStudents(query.trim(), parentId);
    } catch (e) {
      throw StudentException('Error al buscar estudiantes: $e');
    }
  }

  @override
  bool canEditStudent(Student student, String userId, String userRole) {
    return student.canEdit(userId, userRole);
  }

  @override
  Future<List<Student>> getStudentsWithSubject(String subjectId) async {
    try {
      return await _studentService.getStudentsWithSubject(subjectId);
    } catch (e) {
      throw StudentException('Error al obtener estudiantes con materia: $e');
    }
  }

  @override
  Future<StudentStats> getStudentStats(String parentId) async {
    try {
      final students = await getStudentsByParent(parentId);

      final gradeCount = <StudentGrade, int>{
        StudentGrade.preescolar: 0,
        StudentGrade.primaria: 0,
        StudentGrade.secundaria: 0,
        StudentGrade.preparatoria: 0,
        StudentGrade.universidad: 0,
      };

      int totalAssignedSubjects = 0;
      int studentsWithSubjects = 0;
      double totalAge = 0;
      int studentsWithAge = 0;

      for (final student in students) {
        gradeCount[student.grade] = (gradeCount[student.grade] ?? 0) + 1;
        totalAssignedSubjects += student.assignedSubjects.length;
        if (student.assignedSubjects.isNotEmpty) studentsWithSubjects++;
        if (student.age != null) {
          totalAge += student.age!;
          studentsWithAge++;
        }
      }

      final averageAge =
          studentsWithAge > 0 ? totalAge / studentsWithAge : 0.0;

      return StudentStats(
        totalStudents: students.length,
        activeStudents: students.where((s) => s.isActive).length,
        totalAssignedSubjects: totalAssignedSubjects,
        studentsByGrade: gradeCount,
        studentsWithSubjects: studentsWithSubjects,
        studentsWithoutSubjects: students.length - studentsWithSubjects,
        averageAge: averageAge,
      );
    } catch (e) {
      throw StudentException('Error al obtener estadísticas: $e');
    }
  }

  @override
  Future<List<Student>> getAllStudents() async {
    try {
      return await _studentService.getAllStudents();
    } catch (e) {
      throw StudentException('Error al obtener todos los estudiantes: $e');
    }
  }

  @override
  Future<bool> isEmailInUse(String email, {String? excludeStudentId}) async {
    try {
      return await _studentService.isEmailInUse(
        email,
        excludeStudentId: excludeStudentId,
      );
    } catch (e) {
      throw StudentException('Error al verificar email: $e');
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}