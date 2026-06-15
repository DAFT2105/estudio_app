// lib/screens/subjects/subjects_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subject_provider.dart';
import '../../models/subject.dart';
import '../../utils/app_theme.dart';
import 'create_subject_screen.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubjects();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadSubjects() {
    final authProvider = context.read<AuthProvider>();
    final subjectProvider = context.read<SubjectProvider>();
    
    if (authProvider.currentUser != null) {
      subjectProvider.loadSubjects(
        authProvider.currentUser!.id,
        authProvider.currentUser!.role.toString().split('.').last,
      );
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
      title: const Text('Mis Materias'),
      actions: [
        Consumer<SubjectProvider>(
          builder: (context, subjectProvider, child) {
            if (subjectProvider.stats != null) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Chip(
                    label: Text('${subjectProvider.stats!.totalSubjects}'),
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    labelStyle: const TextStyle(
                      color: AppTheme.primaryColor,
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
    return Consumer2<AuthProvider, SubjectProvider>(
      builder: (context, authProvider, subjectProvider, child) {
        return Column(
          children: [
            _buildSearchBar(authProvider, subjectProvider),
            _buildStatsSection(subjectProvider),
            Expanded(
              child: _buildSubjectsList(subjectProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar(AuthProvider authProvider, SubjectProvider subjectProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar materias...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    subjectProvider.clearSearch(
                      authProvider.currentUser!.id,
                      authProvider.currentUser!.role.toString().split('.').last,
                    );
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
            subjectProvider.searchSubjects(
              query,
              authProvider.currentUser!.id,
              authProvider.currentUser!.role.toString().split('.').last,
            );
          } else {
            subjectProvider.clearSearch(
              authProvider.currentUser!.id,
              authProvider.currentUser!.role.toString().split('.').last,
            );
          }
        },
      ),
    );
  }

  Widget _buildStatsSection(SubjectProvider subjectProvider) {
    if (subjectProvider.stats == null) return const SizedBox.shrink();

    final stats = subjectProvider.stats!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1), 
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
          _buildStatItem('Total', stats.totalSubjects.toString(), Icons.book),
          _buildStatItem('Activas', stats.activeSubjects.toString(), Icons.check_circle),
          _buildStatItem('Estudiantes', stats.assignedStudents.toString(), Icons.people),
          _buildStatItem('Tiempo', stats.formattedTotalTime, Icons.schedule),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
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

  Widget _buildSubjectsList(SubjectProvider subjectProvider) {
    switch (subjectProvider.status) {
      case SubjectStatus.loading:
        return const Center(
          child: CircularProgressIndicator(),
        );

      case SubjectStatus.error:
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
                subjectProvider.errorMessage ?? 'Error desconocido',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSubjects,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        );

      case SubjectStatus.empty:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.book_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                subjectProvider.searchQuery.isNotEmpty
                    ? 'No se encontraron materias'
                    : 'No tienes materias creadas',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                subjectProvider.searchQuery.isNotEmpty
                    ? 'Prueba con otros términos de búsqueda'
                    : 'Crea tu primera materia para comenzar',
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (subjectProvider.searchQuery.isEmpty) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _navigateToCreateSubject,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear Primera Materia'),
                ),
              ],
            ],
          ),
        );

      case SubjectStatus.loaded:
        return RefreshIndicator(
          onRefresh: () async => _loadSubjects(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: subjectProvider.subjects.length,
            itemBuilder: (context, index) {
              final subject = subjectProvider.subjects[index];
              return _buildSubjectCard(subject);
            },
          ),
        );
    }
  }

  Widget _buildSubjectCard(Subject subject) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: subject.color.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            subject.icon.icon,
            color: subject.color.color,
          ),
        ),
        title: Text(
          subject.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subject.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (subject.difficulty != null) ...[
                  _buildInfoChip(subject.difficulty!, Icons.signal_cellular_alt),
                  const SizedBox(width: 8),
                ],
                if (subject.formattedDuration.isNotEmpty) ...[
                  _buildInfoChip(subject.formattedDuration, Icons.schedule),
                  const SizedBox(width: 8),
                ],
                _buildInfoChip('${subject.studentCount}', Icons.people),
              ],
            ),
          ],
        ),
        trailing: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final canEdit = context.read<SubjectProvider>().canEditSubject(
              subject,
              authProvider.currentUser!.id,
              authProvider.currentUser!.role.toString().split('.').last,
            );
            
            return PopupMenuButton<String>(
              onSelected: (value) => _handleSubjectAction(value, subject),
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
                /*  const PopupMenuItem(
                    value: 'students',
                    child: ListTile(
                      leading: Icon(Icons.people),
                      title: Text('Gestionar estudiantes'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),*/
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

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
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
        
        // Solo admin y parent pueden crear materias
        if (userRole == 'admin' || userRole == 'parent') {
          return FloatingActionButton(
            onPressed: _navigateToCreateSubject,
            tooltip: 'Crear nueva materia',
            child: const Icon(Icons.add),
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  // MÉTODO PARA CREAR NUEVA MATERIA - Sin cambios
  void _navigateToCreateSubject() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateSubjectScreen(), // Sin parámetros = modo crear
      ),
    );
  }

  // MÉTODO ACTUALIZADO - Manejo de acciones del menú contextual
  void _handleSubjectAction(String action, Subject subject) {
    switch (action) {
      case 'view':
        _showComingSoon('Ver detalles de ${subject.name}');
        break;
      case 'edit':
        // ACTUALIZADO: Usar formulario unificado en modo edición
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateSubjectScreen(
              subjectToEdit: subject, // Pasar materia = modo editar
            ),
          ),
        );
        break;
      /*case 'students':
        _showComingSoon('Gestionar estudiantes de ${subject.name}');
        break;*/
      case 'delete':
        _confirmDelete(subject);
        break;
    }
  }

  void _confirmDelete(Subject subject) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Materia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de que quieres eliminar "${subject.name}"?'),
            if (subject.formattedDuration.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Duración: ${subject.formattedDuration}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
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
              _deleteSubject(subject);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubject(Subject subject) async {
    final authProvider = context.read<AuthProvider>();
    final subjectProvider = context.read<SubjectProvider>();
    
    final success = await subjectProvider.deleteSubject(
      subject.id,
      authProvider.currentUser!.id,
      authProvider.currentUser!.role.toString().split('.').last,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
            ? 'Materia eliminada exitosamente' 
            : 'Error al eliminar materia'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
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