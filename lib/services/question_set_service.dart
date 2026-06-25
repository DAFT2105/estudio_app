// lib/services/question_set_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question.dart';
import '../models/question_set.dart';

class QuestionSetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'questionSets';

  QuestionSet _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuestionSet.fromJson({
      ...data,
      'id': doc.id,
      'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
      'updatedAt': data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate().toIso8601String()
          : null,
    });
  }

  Map<String, dynamic> _toFirestore(QuestionSet set) {
    final json = set.toJson();
    return {
      ...json,
      'createdAt': Timestamp.fromDate(set.createdAt),
      'updatedAt':
          set.updatedAt != null ? Timestamp.fromDate(set.updatedAt!) : null,
    };
  }

  /// Crear un nuevo set de preguntas armado a mano
  Future<QuestionSet> createQuestionSet({
    required String subjectId,
    required String createdBy,
    required String title,
    String? description,
    required QuestionPurpose purpose,
    required List<String> questionIds,
  }) async {
    try {
      if (questionIds.isEmpty) {
        throw const QuestionSetException(
            'Debes seleccionar al menos una pregunta');
      }

      final docRef = _firestore.collection(_collection).doc();

      final set = QuestionSet(
        id: docRef.id,
        subjectId: subjectId,
        createdBy: createdBy,
        title: title,
        description: description,
        purpose: purpose,
        questionIds: questionIds,
        createdAt: DateTime.now(),
      );

      await docRef.set(_toFirestore(set));
      return set;
    } catch (e) {
      if (e is QuestionSetException) rethrow;
      throw QuestionSetException('Error al crear el grupo de preguntas: $e');
    }
  }

  /// Obtener sets activos de una materia — opcionalmente filtrados por modo
  Future<List<QuestionSet>> getQuestionSetsBySubject(
    String subjectId, {
    QuestionPurpose? purpose,
  }) async {
    try {
      var query = _firestore
          .collection(_collection)
          .where('subjectId', isEqualTo: subjectId)
          .where('isActive', isEqualTo: true);

      if (purpose != null) {
        query = query.where('purpose',
            isEqualTo: purpose.toString().split('.').last);
      }

      final snapshot = await query.get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw QuestionSetException('Error al obtener grupos de preguntas: $e');
    }
  }

  /// Obtener sets activos creados por un padre
  Future<List<QuestionSet>> getQuestionSetsByCreator(String creatorId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('createdBy', isEqualTo: creatorId)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw QuestionSetException('Error al obtener tus grupos de preguntas: $e');
    }
  }

  Future<QuestionSet?> getQuestionSetById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      return _fromDoc(doc);
    } catch (e) {
      throw QuestionSetException('Error al obtener el grupo de preguntas: $e');
    }
  }

  Future<QuestionSet> updateQuestionSet(QuestionSet set) async {
    try {
      final updated = set.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(_collection)
          .doc(set.id)
          .update(_toFirestore(updated));
      return updated;
    } catch (e) {
      throw QuestionSetException('Error al actualizar el grupo de preguntas: $e');
    }
  }

  /// Eliminar — soft delete
  Future<bool> deleteQuestionSet(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      throw QuestionSetException('Error al eliminar el grupo de preguntas: $e');
    }
  }
}