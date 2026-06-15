// lib/providers/result_provider.dart

import 'package:flutter/foundation.dart';
import '../models/practice_result.dart';
import '../repositories/result_repository.dart';
import '../services/result_service.dart';

enum ResultStatus { loading, loaded, error, empty }

class ResultProvider extends ChangeNotifier {
  final ResultRepository _resultRepository;

  List<PracticeResult> _results = [];
  ResultStatus _status = ResultStatus.empty;
  String? _errorMessage;
  PracticeStats? _stats;

  List<PracticeResult> get results => _results;
  ResultStatus get status => _status;
  String? get errorMessage => _errorMessage;
  PracticeStats? get stats => _stats;
  bool get isLoading => _status == ResultStatus.loading;
  bool get hasResults => _results.isNotEmpty;

  ResultProvider({required ResultRepository resultRepository})
      : _resultRepository = resultRepository;

  Future<void> loadResults(String studentId) async {
    try {
      _status = ResultStatus.loading;
      notifyListeners();

      _results = await _resultRepository.getResultsByStudent(studentId);
      _stats = await _resultRepository.getStudentStats(studentId);
      _status = _results.isEmpty ? ResultStatus.empty : ResultStatus.loaded;
      _errorMessage = null;
    } on ResultException catch (e) {
      _status = ResultStatus.error;
      _errorMessage = e.message;
    } catch (e) {
      _status = ResultStatus.error;
      _errorMessage = 'Error inesperado: $e';
    }
    notifyListeners();
  }

  /// [parentId] debe pasarse siempre que el usuario sea estudiante.
  /// Se obtiene de AuthProvider.currentUser.parentId y se guarda
  /// en Firestore para que las reglas de producción permitan al padre
  /// leer los resultados de sus hijos.
  Future<void> saveResult(PracticeResult result, {String? parentId}) async {
    try {
      await _resultRepository.saveResult(result, parentId: parentId);
      await loadResults(result.studentId);
    } on ResultException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al guardar: $e';
      notifyListeners();
    }
  }

  Future<void> deleteResult(String resultId, String studentId) async {
    try {
      await _resultRepository.deleteResult(resultId);
      await loadResults(studentId);
    } on ResultException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  List<PracticeResult> getResultsBySubject(String subjectId) {
    return _results.where((r) => r.subjectId == subjectId).toList();
  }

  Map<String, double> get averageBySubject {
    final Map<String, List<double>> bySubject = {};
    for (final r in _results) {
      bySubject.putIfAbsent(r.subjectId, () => []).add(r.percentage);
    }
    return bySubject.map((key, values) =>
        MapEntry(key, values.reduce((a, b) => a + b) / values.length));
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}