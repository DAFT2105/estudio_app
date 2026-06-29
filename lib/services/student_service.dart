// lib/services/student_service.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import '../models/student.dart';
import '../models/user.dart';
import '../utils/app_constants.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;

  static const String _collection = 'students';
  static const String _subjectsCollection = 'subjects';
  static const String _usersCollection = 'users';

  // Nombre único para la instancia secundaria de Firebase
  static const String _secondaryAppName = 'studentCreation';

  // Caracteres usados para generar claves temporales — se excluyen
  // 0/O y 1/l/I para evitar confusión visual al copiarla a mano.
  static const String _passwordChars =
      'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';

  // ─────────────────────────────────────────────
  // HELPERS PRIVADOS
  // ─────────────────────────────────────────────

  /// Convierte un DocumentSnapshot de Firestore a Student
  Student _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Student.fromJson({
      ...data,
      'id': doc.id,
      'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
      'updatedAt': data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate().toIso8601String()
          : null,
      'birthDate': data['birthDate'] != null
          ? (data['birthDate'] as Timestamp).toDate().toIso8601String()
          : null,
    });
  }

  /// Convierte un Student a Map para guardar en Firestore
  Map<String, dynamic> _toFirestore(Student student) {
    final json = student.toJson();
    return {
      ...json,
      'createdAt': Timestamp.fromDate(student.createdAt),
      'updatedAt': student.updatedAt != null
          ? Timestamp.fromDate(student.updatedAt!)
          : null,
      'birthDate': student.birthDate != null
          ? Timestamp.fromDate(student.birthDate!)
          : null,
    };
  }

  /// Quita tildes/ñ y caracteres no alfabéticos, deja todo en minúsculas.
  /// "José Ñúñez" → "josennez"
  String _normalizeForUsername(String text) {
    const withAccents = 'áéíóúÁÉÍÓÚñÑüÜ';
    const withoutAccents = 'aeiouAEIOUnNuU';
    var result = text;
    for (var i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return result.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  }

  /// Email sintético usado internamente por Firebase Auth.
  /// El estudiante NUNCA ve ni necesita conocer este valor.
  String _buildSyntheticEmail(String username) =>
      '$username@${AppConstants.studentEmailDomain}';

  /// Genera una clave temporal aleatoria — distinta para cada estudiante,
  /// nunca persistida en Firestore (solo se devuelve una vez al crearla).
  String _generateTemporaryPassword({int length = 8}) {
    final rand = Random.secure();
    return List.generate(
            length, (_) => _passwordChars[rand.nextInt(_passwordChars.length)])
        .join();
  }

  /// Genera un username único probando candidatos crecientes y crea la
  /// cuenta Auth correspondiente en la instancia secundaria de Firebase.
  /// La sesión del padre NO se interrumpe en ningún momento.
  ///
  /// Algoritmo:
  ///   1 letra del nombre + primer apellido   → "jperez"
  ///   2 letras del nombre + primer apellido   → "juperez"  (si "jperez" ya existe)
  ///   ...hasta agotar el nombre
  ///   Si aun así hay colisión: nombre completo + apellido + sufijo numérico
  ///
  /// La unicidad la garantiza Firebase Auth mismo (error `email-already-in-use`),
  /// sin necesitar consultas ni reglas de Firestore adicionales.
  Future<({String uid, String username, String temporaryPassword})>
      _createStudentAuthAccount(String nombres, String apellidos) async {
    final nombreNorm = _normalizeForUsername(nombres);
    final apellidosParts = apellidos.trim().split(RegExp(r'\s+'));
    final primerApellido = apellidosParts.isNotEmpty ? apellidosParts.first : '';
    final apellidoNorm = _normalizeForUsername(primerApellido);

    if (nombreNorm.isEmpty || apellidoNorm.isEmpty) {
      throw StudentException(
          'Nombres y apellidos deben contener al menos una letra');
    }

    final temporaryPassword = _generateTemporaryPassword();

    FirebaseApp? secondaryApp;
    try {
      // Verificar si ya existe una instancia con ese nombre y eliminarla
      try {
        final existing = Firebase.app(_secondaryAppName);
        await existing.delete();
      } catch (_) {
        // No existía — continuar
      }

      // Crear segunda instancia con las mismas credenciales de Firebase
      secondaryApp = await Firebase.initializeApp(
        name: _secondaryAppName,
        options: Firebase.app().options,
      );
      final secondaryAuth = fb.FirebaseAuth.instanceFor(app: secondaryApp);

      Future<({String uid, String username, String temporaryPassword})?>
          tryCandidate(String candidate) async {
        try {
          final credential = await secondaryAuth.createUserWithEmailAndPassword(
            email: _buildSyntheticEmail(candidate),
            password: temporaryPassword,
          );
          if (credential.user == null) {
            throw StudentException('Error al crear cuenta del estudiante');
          }
          return (
            uid: credential.user!.uid,
            username: candidate,
            temporaryPassword: temporaryPassword,
          );
        } on fb.FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') return null;
          rethrow;
        }
      }

      // Paso 1: 1 letra del nombre, 2 letras, 3... hasta agotar el nombre
      for (var n = 1; n <= nombreNorm.length; n++) {
        final candidate = nombreNorm.substring(0, n) + apellidoNorm;
        final result = await tryCandidate(candidate);
        if (result != null) return result;
      }

      // Paso 2: último recurso — nombre completo + apellido + sufijo numérico
      final fullBase = nombreNorm + apellidoNorm;
      for (var suffix = 2; suffix <= 99; suffix++) {
        final result = await tryCandidate('$fullBase$suffix');
        if (result != null) return result;
      }

      throw StudentException(
          'No se pudo generar un usuario único para este estudiante. '
          'Intenta con un nombre o apellido distinto.');
    } finally {
      // Siempre eliminar la instancia secundaria al terminar
      // tanto si tuvo éxito como si falló
      try {
        await secondaryApp?.delete();
      } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────
  // MÉTODOS PÚBLICOS
  // ─────────────────────────────────────────────

  /// Obtener todos los estudiantes activos (solo admin)
  Future<List<Student>> getAllStudents() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw StudentException('Error al obtener estudiantes: $e');
    }
  }

  /// Obtener estudiantes activos de un padre
  Future<List<Student>> getStudentsByParent(String parentId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('parentId', isEqualTo: parentId)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw StudentException('Error al obtener estudiantes del padre: $e');
    }
  }

  /// Obtener estudiante por ID
  Future<Student?> getStudentById(String studentId) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(studentId).get();
      if (!doc.exists) return null;
      return _fromDoc(doc);
    } catch (e) {
      throw StudentException('Error al obtener estudiante: $e');
    }
  }

  /// Crear nuevo estudiante
  ///
  /// Flujo (Fase 5.3 — sin email obligatorio, sin Cloud Functions):
  /// 1. Genera un `username` único (ej: "jperez") y crea la cuenta Auth
  ///    correspondiente vía instancia secundaria (sin afectar sesión del padre)
  /// 2. Fuerza refresh del token del padre para que Firestore lo reconozca
  /// 3. WriteBatch: crea students/{uid} y users/{uid} juntos,
  ///    marcando `mustChangePassword: true`
  /// 4. Devuelve el Student creado + la clave temporal en texto plano
  ///    (única vez que existe — el padre debe copiarla/compartirla ahora)
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
  }) async {
    try {
      // Paso 1 — Generar username único y crear cuenta Auth
      final authResult =
          await _createStudentAuthAccount(nombres, apellidos);

      // Paso 2 — Forzar refresh del token del padre
      // Garantiza que Firestore use el token correcto del padre para el batch
      await _firebaseAuth.currentUser?.getIdToken(true);

      final now = DateTime.now();
      final cleanEmail =
          (email != null && email.trim().isNotEmpty) ? email.trim().toLowerCase() : null;

      final student = Student(
        id: authResult.uid, // ← ID del documento = UID de Firebase Auth
        nombres: nombres.trim(),
        apellidos: apellidos.trim(),
        username: authResult.username,
        email: cleanEmail,
        parentId: parentId,
        createdAt: now,
        grade: grade,
        gradeLevel: gradeLevel,
        birthDate: birthDate,
        notes: notes,
        avatar: avatar,
      );

      // Paso 3 — WriteBatch: crea students y users de forma atómica
      final batch = _firestore.batch();

      // Documento en students/{uid}
      batch.set(
        _firestore.collection(_collection).doc(authResult.uid),
        _toFirestore(student),
      );

      // Documento en users/{uid} — necesario para el login del estudiante
      batch.set(
        _firestore.collection(_usersCollection).doc(authResult.uid),
        {
          'id': authResult.uid,
          'email': _buildSyntheticEmail(authResult.username),
          'username': authResult.username,
          'name': student.name,
          'role': UserRole.student.toString().split('.').last,
          'parentId': parentId,
          'assignedSubjects': [],
          'isActive': true,
          'mustChangePassword': true,
          'createdAt': Timestamp.fromDate(now),
          'lastLogin': null,
        },
      );

      await batch.commit();

      return (student: student, temporaryPassword: authResult.temporaryPassword);
    } on StudentException {
      rethrow;
    } on fb.FirebaseAuthException catch (e) {
      throw StudentException('Error al crear cuenta del estudiante: ${e.message}');
    } catch (e) {
      throw StudentException('Error al crear estudiante: $e');
    }
  }

  /// Actualizar estudiante existente en Firestore
  Future<Student> updateStudent(Student student) async {
    try {
      final updatedStudent = student.copyWith(updatedAt: DateTime.now());

      final batch = _firestore.batch();

      // Actualizar students/{uid}
      batch.update(
        _firestore.collection(_collection).doc(student.id),
        _toFirestore(updatedStudent),
      );

      // Sincronizar nombre en users/{uid}
      try {
        batch.update(
          _firestore.collection(_usersCollection).doc(student.id),
          {'name': updatedStudent.name, 'updatedAt': Timestamp.now()},
        );
      } catch (_) {}

      await batch.commit();
      return updatedStudent;
    } catch (e) {
      throw StudentException('Error al actualizar estudiante: $e');
    }
  }

  /// Eliminar estudiante — soft delete (isActive: false)
  Future<bool> deleteStudent(String studentId) async {
    try {
      final batch = _firestore.batch();

      batch.update(
        _firestore.collection(_collection).doc(studentId),
        {'isActive': false, 'updatedAt': Timestamp.now()},
      );

      try {
        batch.update(
          _firestore.collection(_usersCollection).doc(studentId),
          {'isActive': false, 'updatedAt': Timestamp.now()},
        );
      } catch (_) {}

      await batch.commit();
      return true;
    } catch (e) {
      throw StudentException('Error al eliminar estudiante: $e');
    }
  }

  /// Asignar materia a estudiante — WriteBatch atómico
  /// Actualiza students, subjects y users en una sola operación
  Future<Student> assignSubjectToStudent(
      String studentId, String subjectId) async {
    try {
      final studentDoc =
          await _firestore.collection(_collection).doc(studentId).get();

      if (!studentDoc.exists) {
        throw StudentException('Estudiante no encontrado');
      }

      final student = _fromDoc(studentDoc);

      if (student.assignedSubjects.contains(subjectId)) {
        throw StudentException('El estudiante ya tiene esta materia asignada');
      }

      final batch = _firestore.batch();

      batch.update(
        _firestore.collection(_collection).doc(studentId),
        {'assignedSubjects': FieldValue.arrayUnion([subjectId]), 'updatedAt': Timestamp.now()},
      );

      batch.update(
        _firestore.collection(_subjectsCollection).doc(subjectId),
        {'assignedStudents': FieldValue.arrayUnion([studentId]), 'updatedAt': Timestamp.now()},
      );

      // Sincronizar en users/{studentId} para que el estudiante vea la materia al login
      try {
        batch.update(
          _firestore.collection(_usersCollection).doc(studentId),
          {'assignedSubjects': FieldValue.arrayUnion([subjectId]), 'updatedAt': Timestamp.now()},
        );
      } catch (_) {}

      await batch.commit();

      return student.copyWith(
        assignedSubjects: [...student.assignedSubjects, subjectId],
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      if (e is StudentException) rethrow;
      throw StudentException('Error al asignar materia: $e');
    }
  }

  /// Desasignar materia de estudiante — WriteBatch atómico
  Future<Student> unassignSubjectFromStudent(
      String studentId, String subjectId) async {
    try {
      final studentDoc =
          await _firestore.collection(_collection).doc(studentId).get();

      if (!studentDoc.exists) {
        throw StudentException('Estudiante no encontrado');
      }

      final student = _fromDoc(studentDoc);

      final batch = _firestore.batch();

      batch.update(
        _firestore.collection(_collection).doc(studentId),
        {'assignedSubjects': FieldValue.arrayRemove([subjectId]), 'updatedAt': Timestamp.now()},
      );

      batch.update(
        _firestore.collection(_subjectsCollection).doc(subjectId),
        {'assignedStudents': FieldValue.arrayRemove([studentId]), 'updatedAt': Timestamp.now()},
      );

      try {
        batch.update(
          _firestore.collection(_usersCollection).doc(studentId),
          {'assignedSubjects': FieldValue.arrayRemove([subjectId]), 'updatedAt': Timestamp.now()},
        );
      } catch (_) {}

      await batch.commit();

      return student.copyWith(
        assignedSubjects:
            student.assignedSubjects.where((id) => id != subjectId).toList(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      if (e is StudentException) rethrow;
      throw StudentException('Error al desasignar materia: $e');
    }
  }

  /// Buscar estudiantes por nombre, usuario o email dentro de un padre
  Future<List<Student>> searchStudents(String query, String parentId) async {
    final students = await getStudentsByParent(parentId);
    final lowercaseQuery = query.toLowerCase();

    return students
        .where((student) =>
            student.name.toLowerCase().contains(lowercaseQuery) ||
            student.username.toLowerCase().contains(lowercaseQuery) ||
            (student.email?.toLowerCase().contains(lowercaseQuery) ?? false) ||
            (student.notes?.toLowerCase().contains(lowercaseQuery) ?? false))
        .toList();
  }

  /// Obtener estudiantes que tienen una materia específica asignada
  Future<List<Student>> getStudentsWithSubject(String subjectId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('assignedSubjects', arrayContains: subjectId)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw StudentException('Error al obtener estudiantes por materia: $e');
    }
  }

  /// Obtener estudiantes por grado
  Future<List<Student>> getStudentsByGrade(StudentGrade grade) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('grade', isEqualTo: grade.toString().split('.').last)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw StudentException('Error al obtener estudiantes por grado: $e');
    }
  }

  /// Verificar si un email ya está en uso.
  /// El email ahora es opcional (Fase 5.3) — solo aplica si el padre
  /// decide asignarle uno (ej. integración futura con colegios).
  Future<bool> isEmailInUse(
    String email, {
    String? excludeStudentId,
    String? parentId,
  }) async {
    if (email.trim().isEmpty) return false;
    try {
      var query = _firestore
          .collection(_collection)
          .where('email', isEqualTo: email.toLowerCase())
          .where('isActive', isEqualTo: true);

      if (parentId != null) {
        query = query.where('parentId', isEqualTo: parentId);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) return false;

      if (excludeStudentId != null) {
        return snapshot.docs.any((doc) => doc.id != excludeStudentId);
      }

      return true;
    } catch (e) {
      throw StudentException('Error al verificar email: $e');
    }
  }

  /// Obtener estudiantes activos de un padre (alias explícito)
  Future<List<Student>> getActiveStudentsByParent(String parentId) async {
    return getStudentsByParent(parentId);
  }

  /// Obtener conteo de estudiantes por padre
  Future<int> getStudentCountByParent(String parentId) async {
    final students = await getStudentsByParent(parentId);
    return students.length;
  }

  /// Sincronizar emails inválidos (mantenimiento — ya no es crítico
  /// desde que el email es opcional, se conserva para datos legacy)
  Future<void> syncStudentsWithUsers() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      bool hasFixes = false;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final email = data['email'] as String? ?? '';

        if (email.isNotEmpty && !email.contains('@')) {
          final name = data['name'] as String? ?? 'estudiante';
          final fixedEmail =
              '${name.toLowerCase().replaceAll(' ', '.')}@estudiante.com';

          batch.update(doc.reference, {
            'email': fixedEmail,
            'updatedAt': Timestamp.now(),
          });
          hasFixes = true;
        }
      }

      if (hasFixes) await batch.commit();
    } catch (e) {
      throw StudentException('Error al sincronizar estudiantes: $e');
    }
  }

  /// Limpiar todos los estudiantes — SOLO para testing
  Future<void> clearAllStudents() async {
    final snapshot = await _firestore.collection(_collection).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

/// Estadísticas de estudiantes de un padre.
/// Definida aquí (capa de servicio) para que tanto el repository
/// como el provider puedan importarla sin crear dependencia circular.
class StudentStats {
  final int totalStudents;
  final int activeStudents;
  final int totalAssignedSubjects;
  final Map<StudentGrade, int> studentsByGrade;
  final int studentsWithSubjects;
  final int studentsWithoutSubjects;
  final double averageAge;

  const StudentStats({
    required this.totalStudents,
    required this.activeStudents,
    required this.totalAssignedSubjects,
    required this.studentsByGrade,
    required this.studentsWithSubjects,
    required this.studentsWithoutSubjects,
    required this.averageAge,
  });
}