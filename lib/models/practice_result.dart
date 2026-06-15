// lib/models/practice_result.dart

class PracticeResult {
  final String id;
  final String studentId;
  final String subjectId;
  final String subjectName;
  final int totalQuestions;
  final int correctAnswers;
  final DateTime completedAt;
  final QuestionDifficultyFilter difficultyFilter;
  final int durationSeconds;
  final SessionType sessionType; // NUEVO

  const PracticeResult({
    required this.id,
    required this.studentId,
    required this.subjectId,
    required this.subjectName,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.completedAt,
    this.difficultyFilter = QuestionDifficultyFilter.all,
    this.durationSeconds = 0,
    this.sessionType = SessionType.practice,
  });

  int get incorrectAnswers => totalQuestions - correctAnswers;
  double get percentage =>
      totalQuestions > 0 ? (correctAnswers / totalQuestions * 100) : 0.0;
  int get percentageRounded => percentage.round();

  ResultRating get rating {
    if (percentage >= 90) return ResultRating.excellent;
    if (percentage >= 70) return ResultRating.good;
    if (percentage >= 50) return ResultRating.regular;
    return ResultRating.needsWork;
  }

  factory PracticeResult.fromJson(Map<String, dynamic> json) {
    return PracticeResult(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      subjectId: json['subjectId'] as String,
      subjectName: json['subjectName'] as String,
      totalQuestions: json['totalQuestions'] as int,
      correctAnswers: json['correctAnswers'] as int,
      completedAt: DateTime.parse(json['completedAt'] as String),
      difficultyFilter: QuestionDifficultyFilter.values.firstWhere(
        (e) => e.toString().split('.').last == json['difficultyFilter'],
        orElse: () => QuestionDifficultyFilter.all,
      ),
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      sessionType: SessionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['sessionType'],
        orElse: () => SessionType.practice,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'completedAt': completedAt.toIso8601String(),
      'difficultyFilter': difficultyFilter.toString().split('.').last,
      'durationSeconds': durationSeconds,
      'sessionType': sessionType.toString().split('.').last,
    };
  }

  PracticeResult copyWith({
    String? id,
    String? studentId,
    String? subjectId,
    String? subjectName,
    int? totalQuestions,
    int? correctAnswers,
    DateTime? completedAt,
    QuestionDifficultyFilter? difficultyFilter,
    int? durationSeconds,
    SessionType? sessionType,
  }) {
    return PracticeResult(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      completedAt: completedAt ?? this.completedAt,
      difficultyFilter: difficultyFilter ?? this.difficultyFilter,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      sessionType: sessionType ?? this.sessionType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PracticeResult && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// NUEVO: Tipo de sesión
enum SessionType { practice, exam }

extension SessionTypeExtension on SessionType {
  String get displayName {
    switch (this) {
      case SessionType.practice:
        return 'Práctica';
      case SessionType.exam:
        return 'Examen';
    }
  }

  String get emoji {
    switch (this) {
      case SessionType.practice:
        return '💪';
      case SessionType.exam:
        return '📝';
    }
  }
}

enum ResultRating { excellent, good, regular, needsWork }

extension ResultRatingExtension on ResultRating {
  String get displayName {
    switch (this) {
      case ResultRating.excellent:
        return '¡Excelente!';
      case ResultRating.good:
        return '¡Bien!';
      case ResultRating.regular:
        return 'Regular';
      case ResultRating.needsWork:
        return 'A mejorar';
    }
  }

  String get emoji {
    switch (this) {
      case ResultRating.excellent:
        return '🏆';
      case ResultRating.good:
        return '⭐';
      case ResultRating.regular:
        return '📚';
      case ResultRating.needsWork:
        return '💪';
    }
  }
}

enum QuestionDifficultyFilter { all, easy, medium, hard }

extension QuestionDifficultyFilterExtension on QuestionDifficultyFilter {
  String get displayName {
    switch (this) {
      case QuestionDifficultyFilter.all:
        return 'Todas';
      case QuestionDifficultyFilter.easy:
        return 'Fácil';
      case QuestionDifficultyFilter.medium:
        return 'Medio';
      case QuestionDifficultyFilter.hard:
        return 'Difícil';
    }
  }
}

class ResultException implements Exception {
  final String message;
  const ResultException(this.message);

  @override
  String toString() => 'ResultException: $message';
}