// lib/repositories/auth_repository.dart

import '../models/user.dart';

/// Repositorio abstracto para manejo de autenticación
abstract class AuthRepository {
  /// Iniciar sesión con email y contraseña
  Future<User?> login(String email, String password);
  
  /// Cerrar sesión del usuario actual
  Future<void> logout();
  
  /// Obtener usuario actual si existe sesión activa
  Future<User?> getCurrentUser();
  
  /// Registrar nuevo usuario
  Future<User?> register({
    required String email,
    required String name,
    required String password,
    required UserRole role,
    String? parentId,
    List<String>? assignedSubjects,
  });
  
  /// Verificar si hay sesión activa
  Future<bool> isLoggedIn();
  
  /// Actualizar información del usuario
  Future<User?> updateUser(User user);
  
  /// Eliminar cuenta de usuario
  Future<bool> deleteUser(String userId);
  
  /// Obtener lista de usuarios (solo admin)
  Future<List<User>> getUsers();
  
  /// Cambiar contraseña del usuario actual
  Future<bool> changePassword(String currentPassword, String newPassword);
  
  /// Resetear contraseña por email
  Future<bool> resetPassword(String email);
  
  /// Verificar si el usuario tiene un permiso específico
  bool hasPermission(String permission);
  
  /// Refrescar token de sesión
  Future<bool> refreshToken();
}