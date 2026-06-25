// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';

class AuthService {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

  /// Login con Google — exclusivo para padres.
  ///
  /// Flujo:
  /// 1. Muestra el selector de cuenta de Google del dispositivo
  /// 2. Autentica en Firebase con el credential de Google
  /// 3. Si es el primer ingreso del usuario (no tiene doc en `users/`),
  ///    crea automáticamente su perfil con rol "parent"
  /// 4. Devuelve el User con su perfil completo
  ///
  /// Devuelve `null` si el usuario canceló el selector de cuentas.
  Future<User?> signInWithGoogle() async {
    try {
      // Paso 1 — mostrar selector de cuentas de Google
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // usuario canceló

      // Paso 2 — obtener tokens de Google y autenticar en Firebase
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final fbCredential =
          await _firebaseAuth.signInWithCredential(credential);

      if (fbCredential.user == null) return null;

      final uid = fbCredential.user!.uid;
      final isNewUser = fbCredential.additionalUserInfo?.isNewUser ?? false;

      // Paso 3 — crear perfil en Firestore si es primer login
      if (isNewUser) {
        final now = DateTime.now();
        final newUser = User(
          id: uid,
          email: googleUser.email,
          name: googleUser.displayName ?? googleUser.email.split('@').first,
          role: UserRole.parent, // Google Sign-In es solo para padres
          createdAt: now,
          isActive: true,
        );
        await _firestore
            .collection(_usersCollection)
            .doc(uid)
            .set(_toFirestore(newUser));
        return newUser;
      }

      // Paso 4 — usuario existente: leer su perfil de Firestore
      return await _getUserProfile(uid);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    } catch (e) {
      // Si el error viene de que el usuario canceló (sign_in_canceled),
      // no lo propagamos — la UI lo maneja via el null de retorno
      if (e.toString().contains('sign_in_canceled') ||
          e.toString().contains('network_error')) {
        return null;
      }
      throw AuthException('Error al iniciar sesión con Google: $e');
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

  /// Cerrar sesión — también cierra la sesión de Google si aplica
  Future<void> clearSession() async {
    await _firebaseAuth.signOut();
    // Cerrar también la sesión de Google para forzar el selector de cuentas
    // en el próximo login (en vez de re-autenticar en silencio)
    if (await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }
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
      return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
    } catch (e) {
      throw AuthException('Error al obtener usuarios: $e');
    }
  }

  // ─────────────────────────────────────────────
  // HELPERS PRIVADOS
  // ─────────────────────────────────────────────

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

  User _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User.fromJson({
      ...data,
      'id': doc.id,
      'createdAt': _parseDate(data['createdAt']),
      'lastLogin': data['lastLogin'] != null
          ? _parseDate(data['lastLogin'])
          : null,
    });
  }

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

  String _parseDate(dynamic value) {
    if (value == null) return DateTime.now().toIso8601String();
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is String) return value;
    return DateTime.now().toIso8601String();
  }

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
      case 'account-exists-with-different-credential':
        return 'Ya existe una cuenta con ese email usando otro método de login';
      default:
        return 'Error de autenticación: $code';
    }
  }

  Future<void> saveSession(User user) async {}
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}