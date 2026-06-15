// lib/models/subject.dart

import 'package:flutter/material.dart';

class Subject {
  final String id;
  final String name;
  final String description;
  final String createdBy; // ID del usuario que la creó
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final List<String> assignedStudents; // IDs de estudiantes asignados
  final SubjectColor color;
  final SubjectIcon icon;
  final int? estimatedDuration; // Duración estimada (número)
  final TimeUnit? timeUnit; // NUEVO: Unidad de tiempo (horas/minutos)
  final String? difficulty; // Fácil, Medio, Difícil

  const Subject({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.assignedStudents = const [],
    this.color = SubjectColor.blue,
    this.icon = SubjectIcon.book,
    this.estimatedDuration,
    this.timeUnit,
    this.difficulty,
  });

  // Verificar si un estudiante está asignado
  bool isAssignedToStudent(String studentId) {
    return assignedStudents.contains(studentId);
  }

  // Obtener número de estudiantes asignados
  int get studentCount => assignedStudents.length;

  // NUEVO: Obtener duración formateada con unidad
  String get formattedDuration {
    if (estimatedDuration == null || timeUnit == null) return '';
    return '$estimatedDuration${timeUnit!.shortName}';
  }

  // NUEVO: Obtener duración en minutos para cálculos
  int get durationInMinutes {
    if (estimatedDuration == null || timeUnit == null) return 0;
    return timeUnit == TimeUnit.hours 
        ? estimatedDuration! * 60 
        : estimatedDuration!;
  }

  // Verificar si el usuario puede editar esta materia
  bool canEdit(String userId, String userRole) {
    // Admin puede editar todo
    if (userRole == 'admin') return true;
    // Padre puede editar solo sus materias
    if (userRole == 'parent') return createdBy == userId;
    // Estudiante no puede editar
    return false;
  }

  // Factory constructor desde JSON
  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      assignedStudents: json['assignedStudents'] != null
          ? List<String>.from(json['assignedStudents'])
          : const [],
      color: SubjectColor.values.firstWhere(
        (e) => e.toString().split('.').last == json['color'],
        orElse: () => SubjectColor.blue,
      ),
      icon: SubjectIcon.values.firstWhere(
        (e) => e.toString().split('.').last == json['icon'],
        orElse: () => SubjectIcon.book,
      ),
      estimatedDuration: json['estimatedDuration'] as int?,
      timeUnit: json['timeUnit'] != null
          ? TimeUnit.values.firstWhere(
              (e) => e.toString().split('.').last == json['timeUnit'],
              orElse: () => TimeUnit.hours,
            )
          : null,
      difficulty: json['difficulty'] as String?,
    );
  }

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
      'assignedStudents': assignedStudents,
      'color': color.toString().split('.').last,
      'icon': icon.toString().split('.').last,
      'estimatedDuration': estimatedDuration,
      'timeUnit': timeUnit?.toString().split('.').last,
      'difficulty': difficulty,
    };
  }

  // Crear copia con cambios
  Subject copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    List<String>? assignedStudents,
    SubjectColor? color,
    SubjectIcon? icon,
    int? estimatedDuration,
    TimeUnit? timeUnit,
    String? difficulty,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      assignedStudents: assignedStudents ?? this.assignedStudents,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      timeUnit: timeUnit ?? this.timeUnit,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  @override
  String toString() {
    return 'Subject(id: $id, name: $name, createdBy: $createdBy)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Subject && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// NUEVO: Enum para unidades de tiempo
enum TimeUnit {
  hours,
  minutes,
}

extension TimeUnitExtension on TimeUnit {
  String get displayName {
    switch (this) {
      case TimeUnit.hours:
        return 'Horas';
      case TimeUnit.minutes:
        return 'Minutos';
    }
  }

  String get shortName {
    switch (this) {
      case TimeUnit.hours:
        return 'h';
      case TimeUnit.minutes:
        return 'min';
    }
  }
}

// Colores disponibles para materias
enum SubjectColor {
  blue,
  green,
  orange,
  purple,
  red,
  teal,
  pink,
  indigo,
}

extension SubjectColorExtension on SubjectColor {
  Color get color {
    switch (this) {
      case SubjectColor.blue:
        return Colors.blue;
      case SubjectColor.green:
        return Colors.green;
      case SubjectColor.orange:
        return Colors.orange;
      case SubjectColor.purple:
        return Colors.purple;
      case SubjectColor.red:
        return Colors.red;
      case SubjectColor.teal:
        return Colors.teal;
      case SubjectColor.pink:
        return Colors.pink;
      case SubjectColor.indigo:
        return Colors.indigo;
    }
  }

  String get displayName {
    switch (this) {
      case SubjectColor.blue:
        return 'Azul';
      case SubjectColor.green:
        return 'Verde';
      case SubjectColor.orange:
        return 'Naranja';
      case SubjectColor.purple:
        return 'Morado';
      case SubjectColor.red:
        return 'Rojo';
      case SubjectColor.teal:
        return 'Turquesa';
      case SubjectColor.pink:
        return 'Rosa';
      case SubjectColor.indigo:
        return 'Índigo';
    }
  }
}

// Iconos disponibles para materias
enum SubjectIcon {
  book,
  calculate,
  science,
  history,
  language,
  art,
  music,
  sports,
  computer,
  geography,
}

extension SubjectIconExtension on SubjectIcon {
  IconData get icon {
    switch (this) {
      case SubjectIcon.book:
        return Icons.book;
      case SubjectIcon.calculate:
        return Icons.calculate;
      case SubjectIcon.science:
        return Icons.science;
      case SubjectIcon.history:
        return Icons.history_edu;
      case SubjectIcon.language:
        return Icons.language;
      case SubjectIcon.art:
        return Icons.palette;
      case SubjectIcon.music:
        return Icons.music_note;
      case SubjectIcon.sports:
        return Icons.sports;
      case SubjectIcon.computer:
        return Icons.computer;
      case SubjectIcon.geography:
        return Icons.public;
    }
  }

  String get displayName {
    switch (this) {
      case SubjectIcon.book:
        return 'Libro';
      case SubjectIcon.calculate:
        return 'Matemáticas';
      case SubjectIcon.science:
        return 'Ciencia';
      case SubjectIcon.history:
        return 'Historia';
      case SubjectIcon.language:
        return 'Idioma';
      case SubjectIcon.art:
        return 'Arte';
      case SubjectIcon.music:
        return 'Música';
      case SubjectIcon.sports:
        return 'Deportes';
      case SubjectIcon.computer:
        return 'Computación';
      case SubjectIcon.geography:
        return 'Geografía';
    }
  }
}

/// Excepción personalizada para operaciones de materias
class SubjectException implements Exception {
  final String message;
  const SubjectException(this.message);

  @override
  String toString() => 'SubjectException: $message';
}