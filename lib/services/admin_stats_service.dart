// lib/services/admin_stats_service.dart

import '../models/user.dart';
import '../models/practice_result.dart';
import '../services/auth_service.dart';
import '../services/student_service.dart';
import '../services/subject_service.dart';
import '../services/question_service.dart';
import '../services/result_service.dart';

/// Agrega estadísticas de todo el sistema para el panel de administrador.
/// Reutiliza los servicios existentes (no duplica queries) — solo combina
/// y calcula sobre los datos que cada uno ya expone.
class AdminStatsService {
  final AuthService _authService;
  final StudentService _studentService;
  final SubjectService _subjectService;
  final QuestionService _questionService;
  final ResultService _resultService;

  AdminStatsService({
    AuthService? authService,
    StudentService? studentService,
    SubjectService? subjectService,
    QuestionService? questionService,
    ResultService? resultService,
  })  : _authService = authService ?? AuthService(),
        _studentService = studentService ?? StudentService(),
        _subjectService = subjectService ?? SubjectService(),
        _questionService = questionService ?? QuestionService(),
        _resultService = resultService ?? ResultService();

  Future<AdminStats> getSystemStats() async {
    // Las 5 consultas no dependen entre sí — se piden en paralelo
    final responses = await Future.wait([
      _authService.getUsers(),
      _studentService.getAllStudents(),
      _subjectService.getAllSubjects(),
      _questionService.getAllQuestions(),
      _resultService.getAllResults(),
    ]);

    final users = responses[0] as List<User>;
    final totalStudentsList = responses[1] as List;
    final totalSubjectsList = responses[2] as List;
    final totalQuestionsList = responses[3] as List;
    final results = responses[4] as List<PracticeResult>;

    final totalParents = users.where((u) => u.role == UserRole.parent).length;
    final totalAdmins = users.where((u) => u.role == UserRole.admin).length;
    final totalStudentUsers =
        users.where((u) => u.role == UserRole.student).length;
    final inactiveUsers = users.where((u) => !u.isActive).length;

    // Rendimiento promedio y distribución de calificaciones
    double averagePercentage = 0;
    final Map<ResultRating, int> ratingDistribution = {
      ResultRating.excellent: 0,
      ResultRating.good: 0,
      ResultRating.regular: 0,
      ResultRating.needsWork: 0,
    };

    if (results.isNotEmpty) {
      averagePercentage =
          results.map((r) => r.percentage).reduce((a, b) => a + b) /
              results.length;
      for (final r in results) {
        ratingDistribution[r.rating] = (ratingDistribution[r.rating] ?? 0) + 1;
      }
    }

    // Práctica vs Examen
    final practiceCount =
        results.where((r) => r.sessionType == SessionType.practice).length;
    final examCount =
        results.where((r) => r.sessionType == SessionType.exam).length;

    return AdminStats(
      totalParents: totalParents,
      totalAdmins: totalAdmins,
      totalStudentUsers: totalStudentUsers,
      inactiveUsers: inactiveUsers,
      totalStudents: totalStudentsList.length,
      totalSubjects: totalSubjectsList.length,
      totalQuestions: totalQuestionsList.length,
      totalSessions: results.length,
      averagePercentage: averagePercentage,
      ratingDistribution: ratingDistribution,
      practiceSessionsCount: practiceCount,
      examSessionsCount: examCount,
    );
  }
}

/// Snapshot de estadísticas de todo el sistema, calculado en el momento
/// de la consulta (no se persiste, siempre refleja el estado actual).
class AdminStats {
  final int totalParents;
  final int totalAdmins;
  final int totalStudentUsers; // usuarios con rol student (cuentas Auth)
  final int inactiveUsers;
  final int totalStudents; // documentos en la colección students
  final int totalSubjects;
  final int totalQuestions;
  final int totalSessions; // total de resultados (práctica + examen)
  final double averagePercentage;
  final Map<ResultRating, int> ratingDistribution;
  final int practiceSessionsCount;
  final int examSessionsCount;

  const AdminStats({
    required this.totalParents,
    required this.totalAdmins,
    required this.totalStudentUsers,
    required this.inactiveUsers,
    required this.totalStudents,
    required this.totalSubjects,
    required this.totalQuestions,
    required this.totalSessions,
    required this.averagePercentage,
    required this.ratingDistribution,
    required this.practiceSessionsCount,
    required this.examSessionsCount,
  });

  int get averagePercentageRounded => averagePercentage.round();

  double get practicePercentage =>
      totalSessions > 0 ? (practiceSessionsCount / totalSessions * 100) : 0;

  double get examPercentage =>
      totalSessions > 0 ? (examSessionsCount / totalSessions * 100) : 0;

  int ratingCount(ResultRating rating) => ratingDistribution[rating] ?? 0;

  double ratingPercentage(ResultRating rating) =>
      totalSessions > 0 ? (ratingCount(rating) / totalSessions * 100) : 0;
} 