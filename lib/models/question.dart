// lib/models/question.dart

import 'package:flutter/material.dart';

class Question {
  final String id;
  final String subjectId; // Materia a la que pertenece
  final String createdBy; // ID del usuario que la creó
  final String text; // Texto de la pregunta
  final QuestionType type; // Tipo de pregunta
  final List<String> options; // Opciones de respuesta
  final String correctAnswer; // Respuesta correcta
  final String? explanation; // Explicación de la respuesta
  final String? topic; // Tema/subtema (opcional)
  final QuestionDifficulty difficulty; // Nivel de dificultad
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final String? imageUrl; // URL de imagen (para futuro)

  const Question({
    required this.id,
    required this.subjectId,
    required this.createdBy,
    required this.text,
    required this.type,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    this.topic,
    this.difficulty = QuestionDifficulty.medium,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.imageUrl,
  });

  // Verificar si una respuesta es correcta
  bool isCorrect(String answer) {
    return answer.trim().toLowerCase() == correctAnswer.trim().toLowerCase();
  }

  // Obtener letra de la opción correcta (A, B, C, D)
  String? get correctOptionLetter {
    if (type != QuestionType.multipleChoice) return null;
    
    final index = options.indexWhere((opt) => 
      opt.trim().toLowerCase() == correctAnswer.trim().toLowerCase()
    );
    
    if (index == -1) return null;
    return String.fromCharCode(65 + index); // 65 = 'A'
  }

  // Validar que la pregunta esté bien formada
  bool get isValid {
    if (text.trim().isEmpty) return false;
    if (correctAnswer.trim().isEmpty) return false;
    
    switch (type) {
      case QuestionType.multipleChoice:
        return options.length >= 2 && options.length <= 6 &&
               options.contains(correctAnswer);
      case QuestionType.trueFalse:
        return ['verdadero', 'falso', 'true', 'false']
            .contains(correctAnswer.toLowerCase());
      case QuestionType.shortAnswer:
        return correctAnswer.length <= 100;
    }
  }

  // Factory constructor desde JSON
  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      createdBy: json['createdBy'] as String,
      text: json['text'] as String,
      type: QuestionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => QuestionType.multipleChoice,
      ),
      options: json['options'] != null
          ? List<String>.from(json['options'])
          : const [],
      correctAnswer: json['correctAnswer'] as String,
      explanation: json['explanation'] as String?,
      topic: json['topic'] as String?,
      difficulty: QuestionDifficulty.values.firstWhere(
        (e) => e.toString().split('.').last == json['difficulty'],
        orElse: () => QuestionDifficulty.medium,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectId': subjectId,
      'createdBy': createdBy,
      'text': text,
      'type': type.toString().split('.').last,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'topic': topic,
      'difficulty': difficulty.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
      'imageUrl': imageUrl,
    };
  }

  // Crear copia con cambios
  Question copyWith({
    String? id,
    String? subjectId,
    String? createdBy,
    String? text,
    QuestionType? type,
    List<String>? options,
    String? correctAnswer,
    String? explanation,
    String? topic,
    QuestionDifficulty? difficulty,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? imageUrl,
  }) {
    return Question(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      createdBy: createdBy ?? this.createdBy,
      text: text ?? this.text,
      type: type ?? this.type,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
      topic: topic ?? this.topic,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  String toString() {
    return 'Question(id: $id, text: $text, type: ${type.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Question && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Enum para tipos de pregunta
enum QuestionType {
  multipleChoice,  // Opción múltiple (A, B, C, D)
  trueFalse,       // Verdadero/Falso
  shortAnswer,     // Respuesta corta
}

extension QuestionTypeExtension on QuestionType {
  String get displayName {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'Opción Múltiple';
      case QuestionType.trueFalse:
        return 'Verdadero/Falso';
      case QuestionType.shortAnswer:
        return 'Respuesta Corta';
    }
  }

  IconData get icon {
    switch (this) {
      case QuestionType.multipleChoice:
        return Icons.list;
      case QuestionType.trueFalse:
        return Icons.check_circle_outline;
      case QuestionType.shortAnswer:
        return Icons.edit_note;
    }
  }

  Color get color {
    switch (this) {
      case QuestionType.multipleChoice:
        return Colors.blue;
      case QuestionType.trueFalse:
        return Colors.green;
      case QuestionType.shortAnswer:
        return Colors.orange;
    }
  }
}

// Enum para niveles de dificultad
enum QuestionDifficulty {
  easy,
  medium,
  hard,
}

extension QuestionDifficultyExtension on QuestionDifficulty {
  String get displayName {
    switch (this) {
      case QuestionDifficulty.easy:
        return 'Fácil';
      case QuestionDifficulty.medium:
        return 'Medio';
      case QuestionDifficulty.hard:
        return 'Difícil';
    }
  }

  Color get color {
    switch (this) {
      case QuestionDifficulty.easy:
        return Colors.green;
      case QuestionDifficulty.medium:
        return Colors.orange;
      case QuestionDifficulty.hard:
        return Colors.red;
    }
  }

  int get value {
    switch (this) {
      case QuestionDifficulty.easy:
        return 1;
      case QuestionDifficulty.medium:
        return 2;
      case QuestionDifficulty.hard:
        return 3;
    }
  }
}

// Excepción personalizada para operaciones de preguntas
class QuestionException implements Exception {
  final String message;
  const QuestionException(this.message);

  @override
  String toString() => 'QuestionException: $message';
}