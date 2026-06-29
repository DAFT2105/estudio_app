// lib/services/subject_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subject.dart';

class SubjectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'subjects';

  // ─────────────────────────────────────────────
  // HELPERS PRIVADOS
  // ─────────────────────────────────────────────

  /// Convierte un DocumentSnapshot de Firestore a Subject
  Subject _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Firestore devuelve Timestamp — los convertimos a ISO String
    // para reusar Subject.fromJson sin modificar el modelo
    return Subject.fromJson({
      ...data,
      'id': doc.id,
      'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
      'updatedAt': data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate().toIso8601String()
          : null,
    });
  }

  /// Convierte un Subject a Map para guardar en Firestore
  Map<String, dynamic> _toFirestore(Subject subject) {
    final json = subject.toJson();
    // Reemplazamos las fechas ISO String por Timestamp nativos de Firestore
    return {
      ...json,
      'createdAt': Timestamp.fromDate(subject.createdAt),
      'updatedAt': subject.updatedAt != null
          ? Timestamp.fromDate(subject.updatedAt!)
          : null,
    };
  }

  // ─────────────────────────────────────────────
  // MÉTODOS PÚBLICOS — misma interfaz que antes
  // ─────────────────────────────────────────────

  /// Obtener todas las materias activas (solo admin)
  Future<List<Subject>> getAllSubjects() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw SubjectException('Error al obtener materias: $e');
    }
  }

  /// Obtener materias filtradas según el rol del usuario
  Future<List<Subject>> getSubjectsByUser(
      String userId, String userRole) async {
    try {
      switch (userRole) {
        case 'admin':
          // Admin ve todas las materias activas
          return getAllSubjects();

        case 'parent':
          // Padre ve solo las materias que él creó
          final snapshot = await _firestore
              .collection(_collection)
              .where('createdBy', isEqualTo: userId)
              .where('isActive', isEqualTo: true)
              .get();
          return snapshot.docs.map(_fromDoc).toList();

        case 'student':
          // Estudiante ve solo materias donde está asignado
          final snapshot = await _firestore
              .collection(_collection)
              .where('assignedStudents', arrayContains: userId)
              .where('isActive', isEqualTo: true)
              .get();
          return snapshot.docs.map(_fromDoc).toList();

        default:
          return [];
      }
    } catch (e) {
      throw SubjectException('Error al obtener materias por usuario: $e');
    }
  }

  /// Crear nueva materia en Firestore
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
    required SubjectArea area,
  }) async {
    try {
      // Firestore genera el ID — no usamos DateTime.millisecondsSinceEpoch
      final docRef = _firestore.collection(_collection).doc();

      final subject = Subject(
        id: docRef.id,
        name: name,
        description: description,
        createdBy: createdBy,
        createdAt: DateTime.now(),
        color: color,
        icon: icon,
        estimatedDuration: estimatedDuration,
        timeUnit: timeUnit,
        difficulty: difficulty,
        assignedStudents: assignedStudents,
        area: area,
      );

      await docRef.set(_toFirestore(subject));
      return subject;
    } catch (e) {
      throw SubjectException('Error al crear materia: $e');
    }
  }

  /// Actualizar materia existente en Firestore
  Future<Subject> updateSubject(Subject subject) async {
    try {
      final updatedSubject = subject.copyWith(updatedAt: DateTime.now());

      await _firestore
          .collection(_collection)
          .doc(subject.id)
          .update(_toFirestore(updatedSubject));

      return updatedSubject;
    } catch (e) {
      throw SubjectException('Error al actualizar materia: $e');
    }
  }

  /// Eliminar materia — soft delete (isActive: false)
  /// No borramos el documento para preservar integridad referencial
  /// con preguntas y resultados que apuntan a este subjectId
  Future<bool> deleteSubject(String subjectId) async {
    try {
      await _firestore.collection(_collection).doc(subjectId).update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      throw SubjectException('Error al eliminar materia: $e');
    }
  }

  /// Asignar estudiante a materia usando arrayUnion (atómico)
  Future<Subject> assignStudentToSubject(
      String subjectId, String studentId) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(subjectId).get();

      if (!doc.exists) {
        throw SubjectException('Materia no encontrada');
      }

      final subject = _fromDoc(doc);

      if (subject.assignedStudents.contains(studentId)) {
        throw SubjectException('Estudiante ya está asignado a esta materia');
      }

      // arrayUnion garantiza que no se dupliquen IDs
      await _firestore.collection(_collection).doc(subjectId).update({
        'assignedStudents': FieldValue.arrayUnion([studentId]),
        'updatedAt': Timestamp.now(),
      });

      return subject.copyWith(
        assignedStudents: [...subject.assignedStudents, studentId],
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      if (e is SubjectException) rethrow;
      throw SubjectException('Error al asignar estudiante: $e');
    }
  }

  /// Desasignar estudiante de materia usando arrayRemove (atómico)
  Future<Subject> unassignStudentFromSubject(
      String subjectId, String studentId) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(subjectId).get();

      if (!doc.exists) {
        throw SubjectException('Materia no encontrada');
      }

      final subject = _fromDoc(doc);

      // arrayRemove elimina el ID sin necesidad de leer-modificar-escribir
      await _firestore.collection(_collection).doc(subjectId).update({
        'assignedStudents': FieldValue.arrayRemove([studentId]),
        'updatedAt': Timestamp.now(),
      });

      return subject.copyWith(
        assignedStudents:
            subject.assignedStudents.where((id) => id != studentId).toList(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      if (e is SubjectException) rethrow;
      throw SubjectException('Error al desasignar estudiante: $e');
    }
  }

  /// Obtener materia por ID
  Future<Subject?> getSubjectById(String subjectId) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(subjectId).get();
      if (!doc.exists) return null;
      return _fromDoc(doc);
    } catch (e) {
      throw SubjectException('Error al obtener materia: $e');
    }
  }

  /// Buscar materias por nombre o descripción
  /// Firestore no tiene búsqueda de texto nativa —
  /// se trae la lista filtrada por usuario y se filtra en memoria
  Future<List<Subject>> searchSubjects(
      String query, String userId, String userRole) async {
    final subjects = await getSubjectsByUser(userId, userRole);
    final lowercaseQuery = query.toLowerCase();

    return subjects
        .where((subject) =>
            subject.name.toLowerCase().contains(lowercaseQuery) ||
            subject.description.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Limpiar todas las materias — SOLO para testing
  Future<void> clearAllSubjects() async {
    final snapshot = await _firestore.collection(_collection).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}