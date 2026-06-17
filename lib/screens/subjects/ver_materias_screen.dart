// lib/screens/subjects/ver_materias_screen.dart
// Pantalla de SOLO CONSULTA — no permite crear/editar/eliminar
// Accesible desde la barra de navegación inferior del padre

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subject_provider.dart';
import '../../models/subject.dart';
import '../../utils/app_theme.dart';

class VerMateriasScreen extends StatefulWidget {
  const VerMateriasScreen({super.key});

  @override
  State<VerMateriasScreen> createState() => _VerMateriasScreenState();
}

class _VerMateriasScreenState extends State<VerMateriasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final subjectProvider = context.read<SubjectProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;
    await subjectProvider.loadSubjects(user.id, 'parent');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Materias'),
        backgroundColor: AppTheme.parentColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<SubjectProvider>(
        builder: (context, subjectProvider, child) {
          final subjects = subjectProvider.activeSubjects;

          if (subjects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No tienes materias creadas',
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
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final subject = subjects[index];
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
                          color: subject.color.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(subject.icon.icon,
                            color: subject.color.color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subject.description,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (subject.difficulty != null)
                                  _miniChip(
                                    subject.difficulty!,
                                    Icons.signal_cellular_alt,
                                    Colors.grey[600]!,
                                  ),
                                if (subject.formattedDuration.isNotEmpty)
                                  _miniChip(
                                    subject.formattedDuration,
                                    Icons.schedule,
                                    Colors.grey[600]!,
                                  ),
                                _miniChip(
                                  '${subject.studentCount} estudiante${subject.studentCount != 1 ? 's' : ''}',
                                  Icons.people,
                                  subject.color.color,
                                ),
                              ],
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

  Widget _miniChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}