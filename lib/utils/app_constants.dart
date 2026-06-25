// lib/utils/app_constants.dart

/// Constantes compartidas entre distintas capas de la app.
class AppConstants {
  /// Dominio sintético usado para construir el "email" interno de Firebase
  /// Auth de los estudiantes que no tienen un correo propio (Fase 5.3).
  /// Firebase Auth exige formato de email válido, pero este dominio nunca
  /// recibe correos reales — el estudiante solo ve y usa su `username`.
  ///
  /// Usado en:
  ///  - StudentService al crear la cuenta Auth del estudiante
  ///  - AuthProvider al iniciar sesión (detecta "usuario" vs "correo")
  static const String studentEmailDomain = 'alumno.estudioapp.local';
}