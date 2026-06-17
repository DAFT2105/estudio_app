// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subject_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/question_provider.dart';
import '../../models/user.dart';
import '../../models/subject.dart';
import '../../utils/app_theme.dart';
import '../subjects/subjects_screen.dart';
import '../students/students_screen.dart';
import '../students/assign_subjects_screen.dart';
import '../questions/questions_screen.dart';
import '../questions/ai_generate_screen.dart';
import '../students/practice_selection_screen.dart';
import '../results/results_screen.dart';
import '../students/exam_selection_screen.dart';
import '../results/parent_results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadParentStats());
  }

  Future<void> _loadParentStats() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null || !user.isParent) return;

    final subjectProvider = context.read<SubjectProvider>();
    final studentProvider = context.read<StudentProvider>();
    final questionProvider = context.read<QuestionProvider>();

    await Future.wait([
      subjectProvider.loadSubjects(user.id, 'parent'),
      studentProvider.loadStudents(user.id),
    ]);

    if (subjectProvider.activeSubjects.isNotEmpty) {
      await questionProvider.loadQuestionsBySubject(
          subjectProvider.activeSubjects.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser!;
        return Scaffold(
          appBar: user.isParent ? null : _buildAppBar(user, authProvider),
          body: _buildBody(user, authProvider),
          bottomNavigationBar: _buildBottomNavigation(user),
          floatingActionButton: _buildFloatingActionButton(user),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(User user, AuthProvider authProvider) {
    return AppBar(
      title: Text('Bienvenido, ${user.name}'),
      actions: [
        Chip(
          label: Text(user.role.displayName),
          backgroundColor: AppTheme.getRoleColor(
                  user.role.toString().split('.').last)
              .withOpacity(0.1),
          labelStyle: TextStyle(
            color: AppTheme.getRoleColor(
                user.role.toString().split('.').last),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: CircleAvatar(
            backgroundColor: AppTheme.getRoleColor(
                user.role.toString().split('.').last),
            child: Text(
              user.name[0].toUpperCase(),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          onSelected: (value) {
            if (value == 'logout') _showLogoutDialog(authProvider);
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Cerrar Sesión',
                    style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(User user, AuthProvider authProvider) {
    switch (user.role) {
      case UserRole.admin:
        return _buildAdminDashboard();
      case UserRole.parent:
        return _buildParentDashboard(user, authProvider);
      case UserRole.student:
        return _buildStudentDashboard();
    }
  }

  // ─────────────────────────────────────────────
  // PARENT DASHBOARD — Nuevo diseño
  // ─────────────────────────────────────────────

  Widget _buildParentDashboard(User user, AuthProvider authProvider) {
    return Consumer3<SubjectProvider, StudentProvider, QuestionProvider>(
      builder: (context, subjectProvider, studentProvider, questionProvider,
          child) {
        final subjectCount = subjectProvider.activeSubjects.length;
        final studentCount = studentProvider.activeStudents.length;

        // Total preguntas de todas las materias
        final questionCount =
            questionProvider.stats?.totalQuestions ?? 0;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header verde con stats
              _buildParentHeader(
                user: user,
                authProvider: authProvider,
                subjectCount: subjectCount,
                studentCount: studentCount,
                questionCount: questionCount,
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Card de Progreso destacada
                    _buildProgressCard(studentCount),
                    const SizedBox(height: 20),

                    // ── Acciones
                    Text(
                      'ACCIONES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.3,
                      children: [
                        _buildNewActionCard(
                          title: 'Mis Materias',
                          subtitle: 'Crear y editar',
                          icon: Icons.library_books,
                          color: Colors.blue[700]!,
                          bgColor: Colors.blue[50]!,
                          onTap: _navigateToSubjects,
                        ),
                        _buildNewActionCard(
                          title: 'Estudiantes',
                          subtitle: 'Gestionar perfiles',
                          icon: Icons.people,
                          color: Colors.purple[700]!,
                          bgColor: Colors.purple[50]!,
                          onTap: _navigateToStudents,
                        ),
                        _buildNewActionCard(
                          title: 'Preguntas',
                          subtitle: 'Banco + IA',
                          icon: Icons.quiz,
                          color: Colors.orange[700]!,
                          bgColor: Colors.orange[50]!,
                          onTap: _navigateToQuestions,
                        ),
                        _buildNewActionCard(
                          title: 'Asignar',
                          subtitle: 'Materias a alumnos',
                          icon: Icons.assignment,
                          color: AppTheme.parentColor,
                          bgColor: Colors.green[50]!,
                          onTap: _navigateToAssignSubjects,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Banner IA
                    _buildAIBanner(subjectProvider.activeSubjects),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParentHeader({
    required User user,
    required AuthProvider authProvider,
    required int subjectCount,
    required int studentCount,
    required int questionCount,
  }) {
    return Container(
      color: AppTheme.parentColor,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 24,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido de vuelta',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                child: CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.25),
                  child: Text(
                    user.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                onSelected: (value) {
                  if (value == 'logout') _showLogoutDialog(authProvider);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading:
                          const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Cerrar Sesión',
                          style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats
          Row(
            children: [
              _buildStatBadge('$subjectCount', 'Materias'),
              const SizedBox(width: 8),
              _buildStatBadge('$studentCount', 'Estudiantes'),
              const SizedBox(width: 8),
              _buildStatBadge('$questionCount', 'Preguntas'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(int studentCount) {
    return InkWell(
      onTap: _navigateToParentResults,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.parentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bar_chart,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ver progreso de estudiantes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[900],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    studentCount > 0
                        ? '$studentCount estudiante${studentCount > 1 ? 's' : ''} activo${studentCount > 1 ? 's' : ''}'
                        : 'Sin estudiantes aún',
                    style: TextStyle(fontSize: 12, color: Colors.green[700]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.green[700]),
          ],
        ),
      ),
    );
  }

  Widget _buildNewActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIBanner(List<Subject> subjects) {
    return InkWell(
      onTap: () => _showAISubjectPicker(subjects),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.pink[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.pink[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.pink[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.auto_awesome,
                  color: Colors.pink[700], size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generar preguntas con IA',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink[900],
                    ),
                  ),
                  Text(
                    'Groq + Gemini disponibles',
                    style:
                        TextStyle(fontSize: 11, color: Colors.pink[700]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.pink[700]),
          ],
        ),
      ),
    );
  }

  void _showAISubjectPicker(List<Subject> subjects) {
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero crea una materia para generar preguntas'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.pink[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.auto_awesome,
                      color: Colors.pink[700], size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Generar con IA',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Selecciona la materia',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...subjects.map((subject) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: subject.color.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(subject.icon.icon,
                        color: subject.color.color, size: 20),
                  ),
                  title: Text(subject.name,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(subject.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                  trailing:
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AIGenerateScreen(subject: subject),
                      ),
                    );
                  },
                )),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ADMIN DASHBOARD
  // ─────────────────────────────────────────────

  Widget _buildAdminDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(
            'Panel de Administrador',
            'Control total del sistema educativo',
            Icons.admin_panel_settings,
            AppTheme.adminColor,
          ),
          const SizedBox(height: 20),
          Text('Gestión del Sistema',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildActionCard('Usuarios',
                  'Gestionar administradores, padres y estudiantes',
                  Icons.people, AppTheme.adminColor,
                  () => _showComingSoon('Gestión de Usuarios')),
              _buildActionCard(
                  'Materias',
                  'Crear y administrar todas las materias',
                  Icons.book,
                  AppTheme.adminColor,
                  _navigateToSubjects),
              _buildActionCard(
                  'Estudiantes',
                  'Ver todos los estudiantes del sistema',
                  Icons.school,
                  AppTheme.adminColor,
                  _navigateToStudents),
              _buildActionCard('Preguntas', 'Banco completo de preguntas',
                  Icons.quiz, AppTheme.adminColor, _navigateToQuestions),
              _buildActionCard(
                  'Reportes',
                  'Estadísticas y reportes del sistema',
                  Icons.analytics,
                  AppTheme.adminColor,
                  () => _showComingSoon('Reportes y Estadísticas')),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STUDENT DASHBOARD
  // ─────────────────────────────────────────────

  Widget _buildStudentDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard('Panel de Estudiante',
              'Aprende y practica tus conocimientos',
              Icons.school, AppTheme.studentColor),
          const SizedBox(height: 20),
          Text('Mis Estudios',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildActionCard('Materias', 'Ver materias asignadas',
                  Icons.library_books, AppTheme.studentColor,
                  _navigateToSubjects),
              _buildActionCard(
                  'Practicar',
                  'Modo práctica sin límite de tiempo',
                  Icons.fitness_center,
                  AppTheme.studentColor,
                  _navigateToPractice),
              _buildActionCard('Examen', 'Realizar exámenes cronometrados',
                  Icons.timer, AppTheme.studentColor, _navigateToExam),
              _buildActionCard('Resultados', 'Ver mi progreso y resultados',
                  Icons.assessment, AppTheme.studentColor,
                  _navigateToResults),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // WIDGETS COMPARTIDOS
  // ─────────────────────────────────────────────

  Widget _buildWelcomeCard(
      String title, String subtitle, IconData icon, Color color) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                              fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey[700])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildBottomNavigation(User user) {
    List<BottomNavigationBarItem> items = [];

    if (user.isAdmin) {
      items = [
        const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard), label: 'Dashboard'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.people), label: 'Usuarios'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.analytics), label: 'Reportes'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.settings), label: 'Config'),
      ];
    } else if (user.isParent) {
      items = [
        const BottomNavigationBarItem(
            icon: Icon(Icons.home), label: 'Inicio'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.subject), label: 'Materias'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.people), label: 'Estudiantes'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.assignment), label: 'Asignar'),
      ];
    } else if (user.isStudent) {
      items = [
        const BottomNavigationBarItem(
            icon: Icon(Icons.home), label: 'Inicio'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.book), label: 'Estudiar'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.quiz), label: 'Examen'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.assessment), label: 'Resultados'),
      ];
    }

    if (items.isEmpty) return null;

    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() => _selectedIndex = index);

        if (user.isAdmin) {
          switch (index) {
            case 1:
              _showComingSoon('Gestión de Usuarios');
              break;
            case 2:
              _showComingSoon('Reportes y Estadísticas');
              break;
            case 3:
              _showComingSoon('Configuración');
              break;
          }
        } else if (user.isParent) {
          switch (index) {
            case 1:
              _navigateToSubjects();
              break;
            case 2:
              _navigateToStudents();
              break;
            case 3:
              _navigateToAssignSubjects();
              break;
          }
        } else if (user.isStudent) {
          switch (index) {
            case 1:
              _navigateToPractice();
              break;
            case 2:
              _navigateToExam();
              break;
            case 3:
              _navigateToResults();
              break;
          }
        }
      },
      type: BottomNavigationBarType.fixed,
      items: items,
    );
  }

  Widget? _buildFloatingActionButton(User user) {
    if (user.isStudent) {
      return FloatingActionButton(
        onPressed: _navigateToPractice,
        tooltip: 'Práctica rápida',
        backgroundColor: AppTheme.studentColor,
        child: const Icon(Icons.play_arrow),
      );
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // NAVEGACIÓN
  // ─────────────────────────────────────────────

  void _navigateToSubjects() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const SubjectsScreen()));

  void _navigateToStudents() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const StudentsScreen()));

  void _navigateToAssignSubjects() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const AssignSubjectsScreen()));

  void _navigateToQuestions() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const QuestionsScreen()));

  void _navigateToPractice() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const PracticeSelectionScreen()));

  void _navigateToResults() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const ResultsScreen()));

  void _navigateToExam() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const ExamSelectionScreen()));

  void _navigateToParentResults() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const ParentResultsScreen()));

  void _showLogoutDialog(AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content:
            const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              authProvider.logout();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Próximamente disponible'),
        backgroundColor: Colors.blue[600],
      ),
    );
  }
}