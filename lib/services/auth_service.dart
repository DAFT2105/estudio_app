// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class AuthService {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _usersCollection = 'users';

  /// Login con email y contraseña
  Future<User?> authenticate(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (credential.user == null) return null;

      return await _getUserProfile(credential.user!.uid);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    } catch (e) {
      throw AuthException('Error al iniciar sesión: $e');
    }
  }

  /// Obtener usuario actualmente autenticado
  Future<User?> getSavedUser() async {
    try {
      final fbUser = _firebaseAuth.currentUser;
      if (fbUser == null) return null;

      await fbUser.reload();
      return await _getUserProfile(fbUser.uid);
    } catch (e) {
      return null;
    }
  }

  /// Cerrar sesión
  Future<void> clearSession() async {
    await _firebaseAuth.signOut();
  }

  /// Registrar nuevo usuario
  Future<User?> register({
    required String email,
    required String name,
    required String password,
    required UserRole role,
    String? parentId,
    List<String>? assignedSubjects,
  }) async {
    try {
      final credential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (credential.user == null) return null;

      final uid = credential.user!.uid;
      final now = DateTime.now();

      final newUser = User(
        id: uid,
        email: email.trim(),
        name: name.trim(),
        role: role,
        createdAt: now,
        isActive: true,
        parentId: parentId,
        assignedSubjects: assignedSubjects ?? [],
      );

      // Guardar en Firestore con Timestamps nativos
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .set(_toFirestore(newUser));

      return newUser;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    } catch (e) {
      throw AuthException('Error al registrar usuario: $e');
    }
  }

  /// Actualizar perfil de usuario en Firestore
  Future<User?> updateUser(User user) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(user.id)
          .update(_toFirestore(user));
      return user;
    } catch (e) {
      throw AuthException('Error al actualizar usuario: $e');
    }
  }

  /// Cambiar contraseña
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final fbUser = _firebaseAuth.currentUser;
      if (fbUser == null) throw const AuthException('No hay sesión activa');

      final credential = fb.EmailAuthProvider.credential(
        email: fbUser.email!,
        password: currentPassword,
      );
      await fbUser.reauthenticateWithCredential(credential);
      await fbUser.updatePassword(newPassword);
      return true;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    } catch (e) {
      throw AuthException('Error al cambiar contraseña: $e');
    }
  }

  /// Obtener todos los usuarios (solo admin)
  Future<List<User>> getUsers() async {
    try {
      final snapshot =
          await _firestore.collection(_usersCollection).get();
      return snapshot.docs
          .map((doc) => _fromDoc(doc))
          .toList();
    } catch (e) {
      throw AuthException('Error al obtener usuarios: $e');
    }
  }

  // ─────────────────────────────────────────────
  // HELPERS PRIVADOS
  // ─────────────────────────────────────────────

  /// Obtener perfil de usuario desde Firestore por UID
  Future<User?> _getUserProfile(String uid) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        throw const AuthException('Perfil de usuario no encontrado');
      }

      return _fromDoc(doc);
    } catch (e) {
      throw AuthException('Error al obtener perfil: $e');
    }
  }

  /// Convierte un DocumentSnapshot a User manejando Timestamps y Strings
  User _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User.fromJson({
      ...data,
      'id': doc.id,
      // Maneja tanto Timestamp (Firestore) como String (legacy/manual)
      'createdAt': _parseDate(data['createdAt']),
      'lastLogin': data['lastLogin'] != null
          ? _parseDate(data['lastLogin'])
          : null,
    });
  }

  /// Convierte un User a Map con Timestamps nativos de Firestore
  Map<String, dynamic> _toFirestore(User user) {
    final json = user.toJson();
    return {
      ...json,
      'createdAt': Timestamp.fromDate(user.createdAt),
      'lastLogin': user.lastLogin != null
          ? Timestamp.fromDate(user.lastLogin!)
          : null,
    };
  }

  /// Convierte Timestamp o String a ISO String para User.fromJson
  String _parseDate(dynamic value) {
    if (value == null) return DateTime.now().toIso8601String();
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is String) return value;
    return DateTime.now().toIso8601String();
  }

  /// Mapear códigos de error de Firebase a mensajes en español
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta con ese email';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'invalid-credential':
        return 'Email o contraseña incorrectos';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese email';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres';
      case 'invalid-email':
        return 'El formato del email no es válido';
      case 'user-disabled':
        return 'Esta cuenta ha sido desactivada';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Intenta más tarde';
      case 'network-request-failed':
        return 'Error de conexión. Verifica tu internet';
      case 'requires-recent-login':
        return 'Por seguridad, inicia sesión nuevamente';
      default:
        return 'Error de autenticación: $code';
    }
  }

  /// Guardar sesión — Firebase maneja la sesión automáticamente
  Future<void> saveSession(User user) async {}
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}