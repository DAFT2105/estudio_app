// lib/services/result_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/practice_result.dart';

class ResultService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'results';

  // ─────────────────────────────────────────────
  // HELPERS PRIVADOS
  // ─────────────────────────────────────────────

  /// Convierte un DocumentSnapshot de Firestore a PracticeResult
  PracticeResult _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PracticeResult.fromJson({
      ...data,
      'id': doc.id,
      'completedAt':
          (data['completedAt'] as Timestamp).toDate().toIso8601String(),
    });
  }

  /// Convierte un PracticeResult a Map para guardar en Firestore
  /// [parentId] se guarda como campo extra para que las reglas de seguridad
  /// permitan al padre leer los resultados de sus hijos:
  ///   allow read: if uid == studentId || uid == parentId
  Map<String, dynamic> _toFirestore(PracticeResult result, {String? parentId}) {
    final json = result.toJson();
    return {
      ...json,
      'completedAt': Timestamp.fromDate(result.completedAt),
      // parentId no está en el modelo pero es necesario para las reglas
      // de seguridad de producción — se guarda solo en Firestore
      if (parentId != null) 'parentId': parentId,
    };
  }

  // ─────────────────────────────────────────────
  // MÉTODOS PÚBLICOS — misma interfaz que antes
  // ─────────────────────────────────────────────

  /// Guardar resultado en Firestore
  ///
  /// [parentId] es opcional pero necesario para las reglas de producción.
  /// Sin él, el padre no podrá leer los resultados con las reglas finales.
  /// Debe pasarse siempre que se conozca el padre del estudiante.
  Future<void> saveResult(PracticeResult result, {String? parentId}) async {
    try {
      // Usamos el ID del modelo como ID del documento para mantener
      // consistencia con el resto de la app
      await _firestore
          .collection(_collection)
          .doc(result.id)
          .set(_toFirestore(result, parentId: parentId));
    } catch (e) {
      throw ResultException('Error al guardar resultado: $e');
    }
  }

  /// Obtener todos los resultados — solo para admin o testing
  Future<List<PracticeResult>> getAllResults() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('completedAt', descending: true)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw ResultException('Error al obtener resultados: $e');
    }
  }

  /// Obtener resultados de un estudiante, ordenados del más reciente al más antiguo
  Future<List<PracticeResult>> getResultsByStudent(String studentId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('studentId', isEqualTo: studentId)
          .orderBy('completedAt', descending: true)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw ResultException('Error al obtener resultados del estudiante: $e');
    }
  }

  /// Obtener resultados de un estudiante filtrados por materia
  Future<List<PracticeResult>> getResultsByStudentAndSubject(
    String studentId,
    String subjectId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('studentId', isEqualTo: studentId)
          .where('subjectId', isEqualTo: subjectId)
          .orderBy('completedAt', descending: true)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw ResultException(
          'Error al obtener resultados por materia: $e');
    }
  }

  /// Obtener resultados de todos los hijos de un padre
  /// Requiere que parentId esté guardado en el documento (ver saveResult)
  Future<List<PracticeResult>> getResultsByParent(String parentId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('parentId', isEqualTo: parentId)
          .orderBy('completedAt', descending: true)
          .get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      throw ResultException('Error al obtener resultados del padre: $e');
    }
  }

  /// Eliminar un resultado por ID
  ///
  /// ⚠️ NOTA DE SEGURIDAD: Con las reglas de producción acordadas,
  /// los resultados son de solo-creación (allow update, delete: if false).
  /// Este método funcionará en desarrollo pero será bloqueado en producción.
  /// Conservado para uso exclusivo de admin o limpieza de datos de prueba.
  Future<void> deleteResult(String resultId) async {
    try {
      await _firestore.collection(_collection).doc(resultId).delete();
    } catch (e) {
      throw ResultException('Error al eliminar resultado: $e');
    }
  }

  /// Eliminar todos los resultados de un estudiante
  ///
  /// ⚠️ NOTA DE SEGURIDAD: Mismo caso que deleteResult — bloqueado en producción.
  /// Usar solo en desarrollo o con cuenta admin con reglas temporales.
  Future<void> deleteResultsByStudent(String studentId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('studentId', isEqualTo: studentId)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw ResultException(
          'Error al eliminar resultados del estudiante: $e');
    }
  }

  /// Calcular estadísticas de práctica/examen de un estudiante
  Future<PracticeStats> getStudentStats(String studentId) async {
    final results = await getResultsByStudent(studentId);

    if (results.isEmpty) return PracticeStats.empty();

    final totalSessions = results.length;
    final avgPercentage =
        results.map((r) => r.percentage).reduce((a, b) => a + b) /
            totalSessions;
    final bestResult =
        results.reduce((a, b) => a.percentage > b.percentage ? a : b);

    final Map<String, List<PracticeResult>> bySubject = {};
    for (final r in results) {
      bySubject.putIfAbsent(r.subjectId, () => []).add(r);
    }

    return PracticeStats(
      totalSessions: totalSessions,
      averagePercentage: avgPercentage,
      bestResult: bestResult,
      subjectCount: bySubject.length,
      recentResults: results.take(5).toList(),
    );
  }

  /// Calcular estadísticas agrupadas por materia para un estudiante
  /// Útil para la vista de resultados del padre
  Future<Map<String, PracticeStats>> getStatsBySubject(
      String studentId) async {
    final results = await getResultsByStudent(studentId);

    final Map<String, List<PracticeResult>> bySubject = {};
    for (final r in results) {
      bySubject.putIfAbsent(r.subjectId, () => []).add(r);
    }

    final Map<String, PracticeStats> statsMap = {};
    for (final entry in bySubject.entries) {
      final subjectResults = entry.value;
      final total = subjectResults.length;
      final avg = subjectResults
              .map((r) => r.percentage)
              .reduce((a, b) => a + b) /
          total;
      final best = subjectResults
          .reduce((a, b) => a.percentage > b.percentage ? a : b);

      statsMap[entry.key] = PracticeStats(
        totalSessions: total,
        averagePercentage: avg,
        bestResult: best,
        subjectCount: 1,
        recentResults: subjectResults.take(5).toList(),
      );
    }

    return statsMap;
  }

  /// Limpiar todos los resultados — SOLO para testing
  Future<void> clearAllResults() async {
    final snapshot = await _firestore.collection(_collection).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

/// Estadísticas de resultados de práctica/examen de un estudiante
class PracticeStats {
  final int totalSessions;
  final double averagePercentage;
  final PracticeResult? bestResult;
  final int subjectCount;
  final List<PracticeResult> recentResults;

  const PracticeStats({
    required this.totalSessions,
    required this.averagePercentage,
    this.bestResult,
    required this.subjectCount,
    required this.recentResults,
  });

  factory PracticeStats.empty() => const PracticeStats(
        totalSessions: 0,
        averagePercentage: 0,
        bestResult: null,
        subjectCount: 0,
        recentResults: [],
      );

  bool get isEmpty => totalSessions == 0;
  int get averagePercentageRounded => averagePercentage.round();
}