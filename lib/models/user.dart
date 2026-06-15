// lib/models/user.dart

enum UserRole {
  admin,
  parent, 
  student,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.parent:
        return 'Padre';
      case UserRole.student:
        return 'Alumno';
    }
  }

  String get description {
    switch (this) {
      case UserRole.admin:
        return 'Control total del sistema';
      case UserRole.parent:
        return 'Gestión de materias y preguntas';
      case UserRole.student:
        return 'Realizar práctica y exámenes';
    }
  }

  List<String> get permissions {
    switch (this) {
      case UserRole.admin:
        return [
          'manage_users',
          'manage_subjects',
          'manage_questions',
          'view_all_results',
          'system_settings',
          'export_data'
        ];
      case UserRole.parent:
        return [
          'manage_subjects',
          'manage_questions',
          'view_student_results',
          'assign_subjects'
        ];
      case UserRole.student:
        return [
          'take_quiz',
          'practice_mode',
          'view_own_results',
          'view_assigned_subjects'
        ];
    }
  }
}

class User {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;
  final List<String>? assignedSubjects; // Para estudiantes
  final String? parentId; // Para estudiantes, referencia al padre

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
    this.assignedSubjects,
    this.parentId,
  });

  // Verificar si tiene un permiso específico
  bool hasPermission(String permission) {
    return role.permissions.contains(permission);
  }

  // Verificar si es administrador
  bool get isAdmin => role == UserRole.admin;

  // Verificar si es padre
  bool get isParent => role == UserRole.parent;

  // Verificar si es estudiante
  bool get isStudent => role == UserRole.student;

  // Factory constructor para crear desde JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => UserRole.student,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLogin: json['lastLogin'] != null 
          ? DateTime.parse(json['lastLogin'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      assignedSubjects: json['assignedSubjects'] != null
          ? List<String>.from(json['assignedSubjects'])
          : null,
      parentId: json['parentId'] as String?,
    );
  }

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'isActive': isActive,
      'assignedSubjects': assignedSubjects,
      'parentId': parentId,
    };
  }

  // Crear copia con cambios
  User copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
    List<String>? assignedSubjects,
    String? parentId,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
      assignedSubjects: assignedSubjects ?? this.assignedSubjects,
      parentId: parentId ?? this.parentId,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, name: $name, role: ${role.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}