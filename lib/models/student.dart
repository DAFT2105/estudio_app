// lib/models/student.dart

import 'package:flutter/material.dart';

class Student {
  final String id;
  final String nombres;
  final String apellidos;
  final String username; // Usuario de acceso (sin @), único — generado automáticamente
  final String? email; // Opcional — reservado para futura integración con colegios
  final String parentId; // ID del padre que lo creó
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final List<String> assignedSubjects; // IDs de materias asignadas
  final StudentGrade grade; // Grado escolar
  final DateTime? birthDate;
  final String? notes; // Notas adicionales del padre
  final StudentAvatar avatar; // Avatar visual para el estudiante

  const Student({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.username,
    this.email,
    required this.parentId,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.assignedSubjects = const [],
    this.grade = StudentGrade.primaria,
    this.birthDate,
    this.notes,
    this.avatar = StudentAvatar.student1,
  });

  /// Nombre completo — calculado a partir de nombres + apellidos.
  /// Se mantiene como getter (no como campo) para que todas las pantallas
  /// que ya usan `student.name` sigan funcionando sin cambios.
  String get name => '$nombres $apellidos'.trim();

  // Obtener edad calculada
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  // Obtener número de materias asignadas
  int get subjectCount => assignedSubjects.length;

  // Verificar si tiene una materia asignada
  bool isAssignedToSubject(String subjectId) {
    return assignedSubjects.contains(subjectId);
  }

  // Verificar si el padre puede editar este estudiante
  bool canEdit(String userId, String userRole) {
    // Admin puede editar todo
    if (userRole == 'admin') return true;
    // Padre puede editar solo sus estudiantes
    if (userRole == 'parent') return parentId == userId;
    // Estudiante no puede editar otros estudiantes
    return false;
  }

  // Factory constructor desde JSON
  factory Student.fromJson(Map<String, dynamic> json) {
    // Compatibilidad con documentos creados antes de la Fase 5.3
    // (tenían un único campo `name` en vez de nombres/apellidos/username)
    final legacyName = json['name'] as String?;
    String nombres = json['nombres'] as String? ?? '';
    String apellidos = json['apellidos'] as String? ?? '';

    if (nombres.isEmpty && legacyName != null && legacyName.trim().isNotEmpty) {
      final parts = legacyName.trim().split(RegExp(r'\s+'));
      nombres = parts.first;
      apellidos = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    return Student(
      id: json['id'] as String,
      nombres: nombres,
      apellidos: apellidos,
      username: json['username'] as String? ?? '',
      email: json['email'] as String?,
      parentId: json['parentId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      assignedSubjects: json['assignedSubjects'] != null
          ? List<String>.from(json['assignedSubjects'])
          : const [],
      grade: StudentGrade.values.firstWhere(
        (e) => e.toString().split('.').last == json['grade'],
        orElse: () => StudentGrade.primaria,
      ),
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'] as String)
          : null,
      notes: json['notes'] as String?,
      avatar: StudentAvatar.values.firstWhere(
        (e) => e.toString().split('.').last == json['avatar'],
        orElse: () => StudentAvatar.student1,
      ),
    );
  }

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombres': nombres,
      'apellidos': apellidos,
      'name': name, // se mantiene por compatibilidad / búsquedas simples en memoria
      'username': username,
      'email': email,
      'parentId': parentId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
      'assignedSubjects': assignedSubjects,
      'grade': grade.toString().split('.').last,
      'birthDate': birthDate?.toIso8601String(),
      'notes': notes,
      'avatar': avatar.toString().split('.').last,
    };
  }

  // Crear copia con cambios
  Student copyWith({
    String? id,
    String? nombres,
    String? apellidos,
    String? username,
    String? email,
    String? parentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    List<String>? assignedSubjects,
    StudentGrade? grade,
    DateTime? birthDate,
    String? notes,
    StudentAvatar? avatar,
  }) {
    return Student(
      id: id ?? this.id,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      username: username ?? this.username,
      email: email ?? this.email,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      assignedSubjects: assignedSubjects ?? this.assignedSubjects,
      grade: grade ?? this.grade,
      birthDate: birthDate ?? this.birthDate,
      notes: notes ?? this.notes,
      avatar: avatar ?? this.avatar,
    );
  }

  @override
  String toString() {
    return 'Student(id: $id, name: $name, username: $username, parentId: $parentId, grade: ${grade.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Student && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Enum para grados escolares
enum StudentGrade {
  preescolar,
  primaria,
  secundaria,
  preparatoria,
  universidad,
}

extension StudentGradeExtension on StudentGrade {
  String get displayName {
    switch (this) {
      case StudentGrade.preescolar:
        return 'Preescolar';
      case StudentGrade.primaria:
        return 'Primaria';
      case StudentGrade.secundaria:
        return 'Secundaria';
      case StudentGrade.preparatoria:
        return 'Preparatoria';
      case StudentGrade.universidad:
        return 'Universidad';
    }
  }

  String get shortName {
    switch (this) {
      case StudentGrade.preescolar:
        return 'Pre';
      case StudentGrade.primaria:
        return 'Pri';
      case StudentGrade.secundaria:
        return 'Sec';
      case StudentGrade.preparatoria:
        return 'Prep';
      case StudentGrade.universidad:
        return 'Univ';
    }
  }

  Color get color {
    switch (this) {
      case StudentGrade.preescolar:
        return Colors.pink;
      case StudentGrade.primaria:
        return Colors.green;
      case StudentGrade.secundaria:
        return Colors.blue;
      case StudentGrade.preparatoria:
        return Colors.orange;
      case StudentGrade.universidad:
        return Colors.purple;
    }
  }
}

// Enum para avatares de estudiantes
enum StudentAvatar {
  student1,
  student2,
  student3,
  student4,
  student5,
  student6,
}

extension StudentAvatarExtension on StudentAvatar {
  IconData get icon {
    switch (this) {
      case StudentAvatar.student1:
        return Icons.face;
      case StudentAvatar.student2:
        return Icons.face_2;
      case StudentAvatar.student3:
        return Icons.face_3;
      case StudentAvatar.student4:
        return Icons.face_4;
      case StudentAvatar.student5:
        return Icons.face_5;
      case StudentAvatar.student6:
        return Icons.face_6;
    }
  }

  String get displayName {
    switch (this) {
      case StudentAvatar.student1:
        return 'Avatar 1';
      case StudentAvatar.student2:
        return 'Avatar 2';
      case StudentAvatar.student3:
        return 'Avatar 3';
      case StudentAvatar.student4:
        return 'Avatar 4';
      case StudentAvatar.student5:
        return 'Avatar 5';
      case StudentAvatar.student6:
        return 'Avatar 6';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case StudentAvatar.student1:
        return Colors.blue[100]!;
      case StudentAvatar.student2:
        return Colors.green[100]!;
      case StudentAvatar.student3:
        return Colors.orange[100]!;
      case StudentAvatar.student4:
        return Colors.purple[100]!;
      case StudentAvatar.student5:
        return Colors.teal[100]!;
      case StudentAvatar.student6:
        return Colors.pink[100]!;
    }
  }
}

/// Excepción personalizada para operaciones de estudiantes
class StudentException implements Exception {
  final String message;
  const StudentException(this.message);

  @override
  String toString() => 'StudentException: $message';
}