// lib/screens/students/assign_subjects_screen.dart
// ARCHIVO NUEVO - Pantalla principal de asignación de materias a estudiantes

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/subject_provider.dart';
import '../../models/student.dart';
import '../../models/subject.dart';
import '../../utils/app_theme.dart';

class AssignSubjectsScreen extends StatefulWidget {
  final Student? selectedStudent; // Opcional: si viene desde un estudiante específico
  
  const AssignSubjectsScreen({
    super.key,
    this.selectedStudent,
  });

  @override
  State<AssignSubjectsScreen> createState() => _AssignSubjectsScreenState();
}

class _AssignSubjectsScreenState extends State<AssignSubjectsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  Student? _currentStudent;
  List<Student> _students = [];
  List<Subject> _subjects = [];
  Map<String, bool> _pendingChanges = {};
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentStudent = widget.selectedStudent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

Future<void> _loadData() async {
  final authProvider = context.read<AuthProvider>();
  final studentProvider = context.read<StudentProvider>();
  final subjectProvider = context.read<SubjectProvider>();
  
  final parentId = authProvider.currentUser!.id;
  
  await Future.wait([
    studentProvider.loadStudents(parentId),
    subjectProvider.loadSubjects(parentId, 'parent'),
  ]);

  if (mounted) {
    setState(() {
      _students = studentProvider.activeStudents;
      _subjects = subjectProvider.activeSubjects;
      
      if (_currentStudent != null) {
        _currentStudent = _students.firstWhere(
          (s) => s.id == _currentStudent!.id,
          orElse: () => _students.isNotEmpty ? _students.first : _currentStudent!,
        );
      } else if (_students.isNotEmpty) {
        _currentStudent = _students.first;
      }
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _hasChanges ? _buildSaveBar() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Asignar Materias'),
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(icon: Icon(Icons.assignment), text: 'Por Estudiante'),
          Tab(icon: Icon(Icons.book), text: 'Por Materia'),
        ],
      ),
      actions: [
        if (_subjects.isNotEmpty && _students.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
            tooltip: 'Información',
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_students.isEmpty || _subjects.isEmpty) {
      return _buildEmptyState();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildByStudentTab(),
        _buildBySubjectTab(),
      ],
    );
  }

  Widget _buildEmptyState() {
    final hasStudents = _students.isNotEmpty;
    final hasSubjects = _subjects.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            !hasStudents && !hasSubjects
                ? 'Necesitas crear estudiantes y materias'
                : !hasStudents
                    ? 'Necesitas crear estudiantes primero'
                    : 'Necesitas crear materias primero',
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Crea al menos un estudiante y una materia para poder asignar.',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: Text(!hasStudents ? 'Crear Estudiantes' : 'Crear Materias'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.parentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildByStudentTab() {
    return Column(
      children: [
        _buildStudentSelector(),
        if (_currentStudent != null) 
          Expanded(child: _buildSubjectsList()),
      ],
    );
  }

  Widget _buildStudentSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.parentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.parentColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _currentStudent?.avatar.backgroundColor ?? Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _currentStudent?.avatar.icon ?? Icons.person,
              color: _currentStudent?.grade.color ?? Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estudiante seleccionado:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                DropdownButton<Student>(
                  value: _currentStudent,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.parentColor,
                  ),
                  items: _students.map((student) {
                    return DropdownMenuItem(
                      value: student,
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: student.avatar.backgroundColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              student.avatar.icon,
                              color: student.grade.color,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              student.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: student.grade.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              student.grade.shortName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: student.grade.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (student) {
                    if (student != null) {
                      setState(() {
                        _currentStudent = student;
                        _pendingChanges.clear();
                        _hasChanges = false;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsList() {
    if (_currentStudent == null) return const SizedBox.shrink();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        final isCurrentlyAssigned = _currentStudent!.isAssignedToSubject(subject.id);
        final pendingKey = '${_currentStudent!.id}|||${subject.id}';
        final hasPendingChange = _pendingChanges.containsKey(pendingKey);
        final finalState = hasPendingChange ? _pendingChanges[pendingKey]! : isCurrentlyAssigned;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
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
              style: const TextStyle(fontWeight: FontWeight.bold),
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
                // ← CAMBIO: Wrap en lugar de Row para evitar overflow
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (subject.difficulty != null)
                      _buildInfoChip(subject.difficulty!, Icons.signal_cellular_alt),
                    if (subject.formattedDuration.isNotEmpty)
                      _buildInfoChip(subject.formattedDuration, Icons.schedule),
                    if (hasPendingChange)
                      _buildInfoChip(
                        finalState ? 'A asignar' : 'A desasignar',
                        finalState ? Icons.add_circle : Icons.remove_circle,
                        finalState ? Colors.green : Colors.orange,
                      ),
                  ],
                ),
              ],
            ),
            trailing: Switch(
              value: finalState,
              onChanged: (value) {
                setState(() {
                  if (value == isCurrentlyAssigned) {
                    _pendingChanges.remove(pendingKey);
                  } else {
                    _pendingChanges[pendingKey] = value;
                  }
                  _hasChanges = _pendingChanges.isNotEmpty;
                });
              },
              activeColor: AppTheme.parentColor,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBySubjectTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        final assignedStudents = _students.where((s) => s.isAssignedToSubject(subject.id)).toList();
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
              children: [
                Text('${assignedStudents.length} estudiante(s) asignado(s)'),
                if (subject.formattedDuration.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildInfoChip(subject.formattedDuration, Icons.schedule),
                ],
              ],
            ),
            children: [
              if (assignedStudents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay estudiantes asignados a esta materia',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ...assignedStudents.map((student) => ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: student.avatar.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      student.avatar.icon,
                      color: student.grade.color,
                      size: 16,
                    ),
                  ),
                  title: Text(student.name),
                  subtitle: Text(student.grade.displayName),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _quickUnassign(student, subject),
                  ),
                )),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => _showAssignDialog(subject),
                  icon: const Icon(Icons.add),
                  label: const Text('Asignar más estudiantes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.parentColor,
                    minimumSize: const Size(double.infinity, 36),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
              fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_pendingChanges.length} cambio(s) pendiente(s)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _pendingChanges.clear();
                _hasChanges = false;
              });
            },
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.parentColor,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      final studentProvider = context.read<StudentProvider>();
      final authProvider = context.read<AuthProvider>();
      final parentId = authProvider.currentUser!.id;

      int successCount = 0;
      
      for (final entry in _pendingChanges.entries) {
        final parts = entry.key.split('|||');
        final studentId = parts[0];
        final subjectId = parts[1];
        final shouldAssign = entry.value;

        bool success;
        if (shouldAssign) {
          success = await studentProvider.assignSubjectToStudent(studentId, subjectId, parentId);
        } else {
          success = await studentProvider.unassignSubjectFromStudent(studentId, subjectId, parentId);
        }

        if (success) successCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount de ${_pendingChanges.length} cambios aplicados exitosamente'),
            backgroundColor: successCount == _pendingChanges.length ? Colors.green : Colors.orange,
          ),
        );

        setState(() {
          _pendingChanges.clear();
          _hasChanges = false;
        });

        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar cambios: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _quickUnassign(Student student, Subject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('¿Desasignar "${subject.name}" de ${student.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Desasignar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final studentProvider = context.read<StudentProvider>();
      final authProvider = context.read<AuthProvider>();
      
      final success = await studentProvider.unassignSubjectFromStudent(
        student.id,
        subject.id,
        authProvider.currentUser!.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
              ? 'Materia desasignada exitosamente'
              : 'Error al desasignar materia'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );

        if (success) {
          await _loadData();
        }
      }
    }
  }

  void _showAssignDialog(Subject subject) {
    final unassignedStudents = _students.where((s) => !s.isAssignedToSubject(subject.id)).toList();
    
    if (unassignedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos los estudiantes ya tienen esta materia asignada'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Asignar "${subject.name}"'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: unassignedStudents.length,
            itemBuilder: (context, index) {
              final student = unassignedStudents[index];
              return ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: student.avatar.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    student.avatar.icon,
                    color: student.grade.color,
                    size: 16,
                  ),
                ),
                title: Text(student.name),
                subtitle: Text(student.grade.displayName),
                onTap: () async {
                  Navigator.pop(context);
                  
                  final studentProvider = context.read<StudentProvider>();
                  final authProvider = context.read<AuthProvider>();
                  
                  final success = await studentProvider.assignSubjectToStudent(
                    student.id,
                    subject.id,
                    authProvider.currentUser!.id,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success 
                          ? 'Materia asignada a ${student.name}'
                          : 'Error al asignar materia'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );

                    if (success) {
                      await _loadData();
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('• Usa los switches para asignar/desasignar materias'),
            Text('• Los cambios se marcan como pendientes hasta que los guardes'),
            Text('• Puedes ver las asignaciones por estudiante o por materia'),
            Text('• Cada estudiante puede tener múltiples materias'),
            Text('• Una materia puede estar asignada a múltiples estudiantes'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
