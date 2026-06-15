// lib/screens/students/students_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../models/student.dart';
import '../../utils/app_theme.dart';
import 'student_form_screen.dart';
import 'assign_subjects_screen.dart'; // IMPORT NECESARIO para asignación

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadStudents() {
    final authProvider = context.read<AuthProvider>();
    final studentProvider = context.read<StudentProvider>();
    
    if (authProvider.currentUser != null) {
      studentProvider.loadStudents(authProvider.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Mis Estudiantes'),
      actions: [
        Consumer<StudentProvider>(
          builder: (context, studentProvider, child) {
            if (studentProvider.stats != null) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Chip(
                    label: Text('${studentProvider.stats!.totalStudents}'),
                    backgroundColor: AppTheme.parentColor.withOpacity(0.1),
                    labelStyle: const TextStyle(
                      color: AppTheme.parentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer2<AuthProvider, StudentProvider>(
      builder: (context, authProvider, studentProvider, child) {
        return Column(
          children: [
            _buildSearchBar(authProvider, studentProvider),
            _buildStatsSection(studentProvider),
            Expanded(
              child: _buildStudentsList(studentProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar(AuthProvider authProvider, StudentProvider studentProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar estudiantes...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    studentProvider.clearSearch(authProvider.currentUser!.id);
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (query) {
          setState(() {});
          if (query.isNotEmpty) {
            studentProvider.searchStudents(query, authProvider.currentUser!.id);
          } else {
            studentProvider.clearSearch(authProvider.currentUser!.id);
          }
        },
      ),
    );
  }

  Widget _buildStatsSection(StudentProvider studentProvider) {
    if (studentProvider.stats == null) return const SizedBox.shrink();

    final stats = studentProvider.stats!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.parentColor.withOpacity(0.1), 
            AppTheme.secondaryColor.withOpacity(0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', stats.totalStudents.toString(), Icons.people),
          _buildStatItem('Activos', stats.activeStudents.toString(), Icons.check_circle),
          _buildStatItem('Materias', stats.totalAssignedSubjects.toString(), Icons.book),
          _buildStatItem('Edad', stats.averageAge > 0 ? '${stats.averageAge.round()}' : '-', Icons.cake),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.parentColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.parentColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentsList(StudentProvider studentProvider) {
    switch (studentProvider.status) {
      case StudentStatus.loading:
        return const Center(
          child: CircularProgressIndicator(),
        );

      case StudentStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                studentProvider.errorMessage ?? 'Error desconocido',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadStudents,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        );

      case StudentStatus.empty:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                studentProvider.searchQuery.isNotEmpty
                    ? 'No se encontraron estudiantes'
                    : 'No tienes estudiantes registrados',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                studentProvider.searchQuery.isNotEmpty
                    ? 'Prueba con otros términos de búsqueda'
                    : 'Agrega tu primer estudiante para comenzar',
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (studentProvider.searchQuery.isEmpty) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _navigateToCreateStudent,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar Primer Estudiante'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.parentColor,
                  ),
                ),
              ],
            ],
          ),
        );

      case StudentStatus.loaded:
        return RefreshIndicator(
          onRefresh: () async => _loadStudents(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: studentProvider.students.length,
            itemBuilder: (context, index) {
              final student = studentProvider.students[index];
              return _buildStudentCard(student);
            },
          ),
        );
    }
  }

  Widget _buildStudentCard(Student student) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: student.avatar.backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            student.avatar.icon,
            color: student.grade.color,
            size: 24,
          ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(student.email),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoChip(student.grade.displayName, Icons.school, student.grade.color),
                const SizedBox(width: 8),
                if (student.age != null) ...[
                  _buildInfoChip('${student.age} años', Icons.cake),
                  const SizedBox(width: 8),
                ],
                _buildInfoChip('${student.subjectCount}', Icons.book),
              ],
            ),
          ],
        ),
        trailing: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final canEdit = context.read<StudentProvider>().canEditStudent(
              student,
              authProvider.currentUser!.id,
              authProvider.currentUser!.role.toString().split('.').last,
            );
            
            return PopupMenuButton<String>(
              onSelected: (value) => _handleStudentAction(value, student),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: ListTile(
                    leading: Icon(Icons.visibility),
                    title: Text('Ver detalles'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (canEdit) ...[
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Editar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'subjects',
                    child: ListTile(
                      leading: Icon(Icons.book),
                      title: Text('Asignar materias'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Eliminar', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon, [Color? color]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color ?? Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final userRole = authProvider.currentUser!.role.toString().split('.').last;
        
        if (userRole == 'admin' || userRole == 'parent') {
          return FloatingActionButton(
            onPressed: _navigateToCreateStudent,
            tooltip: 'Agregar nuevo estudiante',
            backgroundColor: AppTheme.parentColor,
            child: const Icon(Icons.add),
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  void _navigateToCreateStudent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StudentFormScreen(),
      ),
    );
  }

  // MÉTODO ACTUALIZADO con navegación a asignación de materias
  void _handleStudentAction(String action, Student student) {
    switch (action) {
      case 'view':
        _showStudentDetails(student);
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentFormScreen(
              studentToEdit: student,
            ),
          ),
        );
        break;
      case 'subjects':
        // AQUÍ SE USA AssignSubjectsScreen - por eso necesitamos el import
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssignSubjectsScreen(
              selectedStudent: student,
            ),
          ),
        );
        break;
      case 'delete':
        _confirmDelete(student);
        break;
    }
  }

  void _showStudentDetails(Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: student.avatar.backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                student.avatar.icon,
                color: student.grade.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(student.name)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Email', student.email),
            _buildDetailRow('Grado', student.grade.displayName),
            if (student.age != null) _buildDetailRow('Edad', '${student.age} años'),
            _buildDetailRow('Materias asignadas', '${student.subjectCount}'),
            if (student.notes != null && student.notes!.isNotEmpty)
              _buildDetailRow('Notas', student.notes!),
            _buildDetailRow('Registrado', 
              '${student.createdAt.day}/${student.createdAt.month}/${student.createdAt.year}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentFormScreen(studentToEdit: student),
                ),
              );
            },
            child: const Text('Editar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _confirmDelete(Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Estudiante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de que quieres eliminar a "${student.name}"?'),
            const SizedBox(height: 8),
            Text(
              'Esta acción no se puede deshacer.',
              style: TextStyle(color: Colors.red[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteStudent(student);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStudent(Student student) async {
    final authProvider = context.read<AuthProvider>();
    final studentProvider = context.read<StudentProvider>();
    
    final success = await studentProvider.deleteStudent(
      student.id,
      authProvider.currentUser!.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
            ? 'Estudiante eliminado exitosamente' 
            : 'Error al eliminar estudiante'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  /*void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Próximamente disponible'),
        backgroundColor: Colors.blue[600],
      ),
    );
  }*/
}