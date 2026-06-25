// lib/repositories/auth_repository_impl.dart

import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../models/user.dart';
import '../services/auth_service.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;

  AuthRepositoryImpl({required AuthService authService})
      : _authService = authService;

  @override
  Future<User?> login(String email, String password) async {
    try {
      return await _authService.authenticate(email, password);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<User?> loginWithGoogle() async {
    try {
      return await _authService.signInWithGoogle();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    await _authService.clearSession();
  }

  @override
  Future<User?> getCurrentUser() async {
    return await _authService.getSavedUser();
  }

  @override
  Future<User?> register({
    required String email,
    required String name,
    required String password,
    required UserRole role,
    String? parentId,
    List<String>? assignedSubjects,
  }) async {
    try {
      return await _authService.register(
        email: email,
        name: name,
        password: password,
        role: role,
        parentId: parentId,
        assignedSubjects: assignedSubjects,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();
    return user != null;
  }

  @override
  Future<User?> updateUser(User user) async {
    try {
      return await _authService.updateUser(user);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> deleteUser(String userId) async {
    return false;
  }

  @override
  Future<List<User>> getUsers() async {
    try {
      return await _authService.getUsers();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      return await _authService.changePassword(currentPassword, newPassword);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> resetPassword(String email) async {
    try {
      await fb.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return true;
    } on fb.FirebaseAuthException {
      return false;
    }
  }

  @override
  bool hasPermission(String permission) {
    return false;
  }

  @override
  Future<bool> refreshToken() async {
    try {
      final fbUser = fb.FirebaseAuth.instance.currentUser;
      if (fbUser == null) return false;
      await fbUser.getIdToken(true);
      return true;
    } catch (e) {
      return false;
    }
  }
}