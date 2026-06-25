// lib/models/question_set.dart

import 'question.dart';

/// Un grupo de preguntas elegidas a mano por el padre (de uno o varios
/// temas dentro de la misma materia) para armar un Examen o Práctica
/// reutilizable — alternativa a la generación aleatoria.
class QuestionSet {
  final String id;
  final String subjectId;
  final String createdBy; // ID del padre que lo armó
  final String title; // Ej: "Examen Bimestral 1"
  final String? description;
  final QuestionPurpose purpose; // Práctica o Examen — coherente con
  // las preguntas que contiene (no se mezclan modos en un mismo set)
  final List<String> questionIds; // En el orden elegido por el padre
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  const QuestionSet({
    required this.id,
    required this.subjectId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.purpose,
    required this.questionIds,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  int get questionCount => questionIds.length;

  /// Verificar si el usuario puede editar/eliminar este set
  bool canEdit(String userId, String userRole) {
    if (userRole == 'admin') return true;
    if (userRole == 'parent') return createdBy == userId;
    return false;
  }

  factory QuestionSet.fromJson(Map<String, dynamic> json) {
    return QuestionSet(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      createdBy: json['createdBy'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      purpose: QuestionPurpose.values.firstWhere(
        (e) => e.toString().split('.').last == json['purpose'],
        orElse: () => QuestionPurpose.practice,
      ),
      questionIds: json['questionIds'] != null
          ? List<String>.from(json['questionIds'])
          : const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectId': subjectId,
      'createdBy': createdBy,
      'title': title,
      'description': description,
      'purpose': purpose.toString().split('.').last,
      'questionIds': questionIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  QuestionSet copyWith({
    String? id,
    String? subjectId,
    String? createdBy,
    String? title,
    String? description,
    QuestionPurpose? purpose,
    List<String>? questionIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return QuestionSet(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      description: description ?? this.description,
      purpose: purpose ?? this.purpose,
      questionIds: questionIds ?? this.questionIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() =>
      'QuestionSet(id: $id, title: $title, purpose: ${purpose.displayName}, questions: $questionCount)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuestionSet && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class QuestionSetException implements Exception {
  final String message;
  const QuestionSetException(this.message);

  @override
  String toString() => 'QuestionSetException: $message';
}