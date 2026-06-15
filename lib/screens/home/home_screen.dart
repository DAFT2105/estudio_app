// lib/screens/home/home_screen.dart
// MODIFICADO: Agregada navegación a asignación de materias

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../utils/app_theme.dart';
import '../subjects/subjects_screen.dart';
import '../students/students_screen.dart';
import '../students/assign_subjects_screen.dart'; // NUEVO IMPORT
import '../questions/questions_screen.dart'; // NUEVO IMPORT
import '../students/practice_selection_screen.dart'; // NUEVO IMPORT
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
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser!;
        
        return Scaffold(
          appBar: _buildAppBar(user, authProvider),
          body: _buildBody(user),
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
          backgroundColor: AppTheme.getRoleColor(user.role.toString().split('.').last).withOpacity(0.1),
          labelStyle: TextStyle(
            color: AppTheme.getRoleColor(user.role.toString().split('.').last),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: CircleAvatar(
            backgroundColor: AppTheme.getRoleColor(user.role.toString().split('.').last),
            child: Text(
              user.name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          onSelected: (value) {
            if (value == 'logout') {
              _showLogoutDialog(authProvider);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Perfil'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Configuración'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(User user) {
    switch (user.role) {
      case UserRole.admin:
        return _buildAdminDashboard();
      case UserRole.parent:
        return _buildParentDashboard();
      case UserRole.student:
        return _buildStudentDashboard();
    }
  }

  Widget _buildAdminDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard('Panel de Administrador', 
            'Control total del sistema educativo', 
            Icons.admin_panel_settings,
            AppTheme.adminColor),
          const SizedBox(height: 20),
          
          Text(
            'Gestión del Sistema',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildActionCard(
                'Usuarios',
                'Gestionar administradores, padres y estudiantes',
                Icons.people,
                AppTheme.adminColor,
                () => _showComingSoon('Gestión de Usuarios'),
              ),
              _buildActionCard(
                'Materias',
                'Crear y administrar todas las materias',
                Icons.book,
                AppTheme.adminColor,
                () => _navigateToSubjects(),
              ),
              _buildActionCard(
                'Estudiantes',
                'Ver todos los estudiantes del sistema',
                Icons.school,
                AppTheme.adminColor,
                () => _navigateToStudents(),
              ),
              _buildActionCard(
                'Preguntas',
                'Banco completo de preguntas',
                Icons.quiz,
                AppTheme.adminColor,
                () => _navigateToQuestions(),
              ),
              _buildActionCard(
                'Reportes',
                'Estadísticas y reportes del sistema',
                Icons.analytics,
                AppTheme.adminColor,
                () => _showComingSoon('Reportes y Estadísticas'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParentDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard('Panel de Padre/Tutor', 
            'Gestiona el aprendizaje de tus estudiantes', 
            Icons.family_restroom,
            AppTheme.parentColor),
          const SizedBox(height: 20),
          
          Text(
            'Gestión Educativa',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildActionCard(
                'Mis Materias',
                'Crear y editar materias de estudio',
                Icons.subject,
                AppTheme.parentColor,
                () => _navigateToSubjects(),
              ),
              _buildActionCard(
                'Mis Estudiantes',
                'Gestionar perfiles de estudiantes',
                Icons.people,
                AppTheme.parentColor,
                () => _navigateToStudents(),
              ),
              // NUEVA CARD: Asignación de materias
              _buildActionCard(
                'Asignar Materias',
                'Conectar materias con estudiantes',
                Icons.assignment,
                AppTheme.parentColor,
                () => _navigateToAssignSubjects(),
              ),
              _buildActionCard(
                'Preguntas',
                'Agregar y organizar preguntas',
                Icons.quiz,
                AppTheme.parentColor,
                () => _navigateToQuestions(),
              ),
              _buildActionCard(
                'Progreso',
                'Ver resultados de tus estudiantes',
                Icons.assessment,
                AppTheme.parentColor,
                () => _navigateToParentResults(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard('Panel de Estudiante', 
            'Aprende y practica tus conocimientos', 
            Icons.school,
            AppTheme.studentColor),
          const SizedBox(height: 20),
          
          Text(
            'Mis Estudios',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildActionCard(
                'Materias',
                'Ver materias asignadas',
                Icons.library_books,
                AppTheme.studentColor,
                () => _navigateToSubjects(),
              ),
              _buildActionCard(
                'Practicar',
                'Modo práctica sin límite de tiempo',
                Icons.fitness_center,
                AppTheme.studentColor,
                () => _navigateToPractice(), // CAMBIADO
              ),
              _buildActionCard(
                'Examen',
                'Realizar exámenes cronometrados',
                Icons.timer,
                AppTheme.studentColor,
                () => _navigateToExam(),
              ),
              _buildActionCard(
                'Resultados',
                'Ver mi progreso y resultados',
                Icons.assessment,
                AppTheme.studentColor,
                () => _navigateToResults(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(String title, String subtitle, IconData icon, Color color) {
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
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
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
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Usuarios'),
        const BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Reportes'),
        const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Config'),
      ];
    } else if (user.isParent) {
      items = [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
        const BottomNavigationBarItem(icon: Icon(Icons.subject), label: 'Materias'),
        const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Estudiantes'),
        const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Asignar'), // MODIFICADO
      ];
    } else if (user.isStudent) {
      items = [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
        const BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Estudiar'),
        const BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Examen'),
        const BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Resultados'),
      ];
    }

    if (items.isEmpty) return null;

    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
        
        if (user.isAdmin) {
          switch (index) {
            case 0:
              break;
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
            case 0:
              break;
            case 1:
              _navigateToSubjects();
              break;
            case 2:
              _navigateToStudents();
              break;
            case 3: // MODIFICADO: Navegación a asignación
              _navigateToAssignSubjects();
              break;
          }
        } else if (user.isStudent) {
          switch (index) {
            case 0:
              break;
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

  void _showLogoutDialog(AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  void _navigateToSubjects() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubjectsScreen(),
      ),
    );
  }

  void _navigateToStudents() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StudentsScreen(),
      ),
    );
  }

  // NUEVO: Método para navegar a asignación de materias
  void _navigateToAssignSubjects() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AssignSubjectsScreen(),
      ),
    );
  }
  
  // NUEVO: Método para navegar a preguntas
  void _navigateToQuestions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QuestionsScreen(),
      ),
    );
  }
  // NUEVO: Método para navegar a modo práctica
void _navigateToPractice() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const PracticeSelectionScreen(),
    ),
  );
}
void _navigateToResults() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const ResultsScreen(),
    ),
  );
}
void _navigateToExam() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const ExamSelectionScreen(),
    ),
  );
}
void _navigateToParentResults() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const ParentResultsScreen(),
    ),
  );
}
}