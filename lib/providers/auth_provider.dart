// lib/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_service.dart';

enum AuthStatus {
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  
  User? _currentUser;
  AuthStatus _status = AuthStatus.loading;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  // Constructor with dependency injection
  AuthProvider({required AuthRepository authRepository}) 
      : _authRepository = authRepository {
    _checkAuthStatus();
  }

  // Verificar estado de autenticación al iniciar
  Future<void> _checkAuthStatus() async {
    try {
      _setStatus(AuthStatus.loading);
      
      // Verificar si hay una sesión guardada usando el repository
      final user = await _authRepository.getCurrentUser();
      
      if (user != null) {
        _currentUser = user;
        _setStatus(AuthStatus.authenticated);
      } else {
        _setStatus(AuthStatus.unauthenticated);
      }
    } catch (e) {
      _setError('Error al verificar autenticación: $e');
    }
  }

  // Login con email y password
  Future<bool> login(String email, String password) async {
    try {
      _setStatus(AuthStatus.loading);
      _clearError();

      // Validaciones básicas
      if (email.trim().isEmpty || password.trim().isEmpty) {
        _setError('Email y contraseña son requeridos');
        return false;
      }

      if (!_isValidEmail(email)) {
        _setError('Formato de email inválido');
        return false;
      }

      // Usar repository para autenticación
      final user = await _authRepository.login(email.trim(), password.trim());
      
      if (user != null) {
        _currentUser = user;
        _setStatus(AuthStatus.authenticated);
        return true;
      } else {
        _setError('Error desconocido durante el login');
        return false;
      }

    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error durante el login: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      _setStatus(AuthStatus.loading);
      
      // Usar repository para logout
      await _authRepository.logout();
      
      _currentUser = null;
      _setStatus(AuthStatus.unauthenticated);
      _clearError();
      
    } catch (e) {
      _setError('Error durante el logout: $e');
    }
  }

  // Registro de nuevo usuario (solo para admin/parent)
  Future<bool> registerUser({
    required String email,
    required String name,
    required String password,
    required UserRole role,
    String? parentId,
    List<String>? assignedSubjects,
  }) async {
    try {
      _setStatus(AuthStatus.loading);
      _clearError();

      // Verificar permisos
      if (_currentUser == null || !_currentUser!.hasPermission('manage_users')) {
        _setError('No tienes permisos para registrar usuarios');
        return false;
      }

      // Validaciones básicas
      if (email.trim().isEmpty || name.trim().isEmpty || password.trim().isEmpty) {
        _setError('Todos los campos son requeridos');
        return false;
      }

      if (!_isValidEmail(email)) {
        _setError('Formato de email inválido');
        return false;
      }

      if (password.length < 6) {
        _setError('La contraseña debe tener al menos 6 caracteres');
        return false;
      }

      // Usar repository para registro
      final newUser = await _authRepository.register(
        email: email.trim(),
        name: name.trim(),
        password: password.trim(),
        role: role,
        parentId: parentId,
        assignedSubjects: assignedSubjects,
      );
      
      if (newUser != null) {
        return true;
      } else {
        _setError('Error desconocido durante el registro');
        return false;
      }

    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error durante el registro: $e');
      return false;
    }
  }

  // Actualizar usuario actual
  Future<bool> updateCurrentUser(User updatedUser) async {
    try {
      final result = await _authRepository.updateUser(updatedUser);
      if (result != null) {
        _currentUser = result;
        notifyListeners();
        return true;
      }
      return false;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al actualizar usuario: $e');
      return false;
    }
  }

  // Cambiar contraseña
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      _clearError();

      if (currentPassword.isEmpty || newPassword.isEmpty) {
        _setError('Las contraseñas son requeridas');
        return false;
      }

      if (newPassword.length < 6) {
        _setError('La nueva contraseña debe tener al menos 6 caracteres');
        return false;
      }

      final success = await _authRepository.changePassword(currentPassword, newPassword);
      if (!success) {
        _setError('Error al cambiar contraseña');
      }
      return success;

    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al cambiar contraseña: $e');
      return false;
    }
  }

  // Obtener lista de usuarios (solo para admin)
  Future<List<User>> getUsers() async {
    try {
      if (_currentUser == null || !_currentUser!.hasPermission('manage_users')) {
        throw const AuthException('No tienes permisos para ver usuarios'); //AGREGUE CONST 
      }

      return await _authRepository.getUsers();
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Error al obtener usuarios: $e');
    }
  }

  // Validar formato de email
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Métodos auxiliares para actualizar estado
  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = AuthStatus.error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Verificar si el usuario actual tiene un permiso específico
  bool hasPermission(String permission) {
    return _currentUser?.hasPermission(permission) ?? false;
  }

  // Obtener información de credenciales para testing
  static Map<String, String> get testCredentials => {
    'Administrador': 'admin@escuela.com / admin123',
    'Padre': 'padre@familia.com / padre123',
    'Estudiante': 'estudiante@escuela.com / estudiante123',
  };
}