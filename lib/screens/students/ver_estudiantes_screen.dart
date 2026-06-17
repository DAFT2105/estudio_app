// lib/screens/students/ver_estudiantes_screen.dart
// Pantalla de SOLO CONSULTA — no permite crear/editar/eliminar
// Accesible desde la barra de navegación inferior del padre

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/subject_provider.dart';
import '../../models/subject.dart';
import '../../models/student.dart';
import '../../utils/app_theme.dart';

class VerEstudiantesScreen extends StatefulWidget {
  const VerEstudiantesScreen({super.key});

  @override
  State<VerEstudiantesScreen> createState() => _VerEstudiantesScreenState();
}

class _VerEstudiantesScreenState extends State<VerEstudiantesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    final studentProvider = context.read<StudentProvider>();
    final subjectProvider = context.read<SubjectProvider>();

    await Future.wait([
      studentProvider.loadStudents(user.id),
      subjectProvider.loadSubjects(user.id, 'parent'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Estudiantes'),
        backgroundColor: AppTheme.parentColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer2<StudentProvider, SubjectProvider>(
        builder: (context, studentProvider, subjectProvider, child) {
          final students = studentProvider.activeStudents;

          if (students.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No tienes estudiantes registrados',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];

                // Nombres de las materias asignadas a este estudiante
                final assignedSubjectNames = subjectProvider.activeSubjects
                    .where((s) => student.assignedSubjects.contains(s.id))
                    .toList();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: student.avatar.backgroundColor,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(student.avatar.icon,
                            color: student.grade.color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    student.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: student.isActive
                                        ? Colors.green[50]
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    student.isActive ? 'Activo' : 'Inactivo',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: student.isActive
                                          ? Colors.green[700]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              student.grade.displayName,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            if (assignedSubjectNames.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: assignedSubjectNames
                                    .map((s) => Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: s.color.color
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            s.name,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: s.color.color,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              )
                            else
                              Text(
                                'Sin materias asignadas',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                    fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}