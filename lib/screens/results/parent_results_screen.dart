// lib/screens/results/parent_results_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../models/student.dart';
import '../../services/result_service.dart';
import '../../utils/app_theme.dart';
import 'student_detail_screen.dart';

class ParentResultsScreen extends StatefulWidget {
  const ParentResultsScreen({super.key});

  @override
  State<ParentResultsScreen> createState() => _ParentResultsScreenState();
}

class _ParentResultsScreenState extends State<ParentResultsScreen> {
  Map<String, PracticeStats> _statsMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final studentProvider = context.read<StudentProvider>();
    final resultService = context.read<ResultService>();

    final parentId = authProvider.currentUser!.id;
    await studentProvider.loadStudents(parentId);

    if (!mounted) return;

    // Una sola query filtrando por parentId — respeta las reglas de Firestore
    // En lugar de una query por cada estudiante (que el padre no puede hacer)
    final allResults = await resultService.getResultsByParent(parentId);

    // Agrupar resultados por estudiante en memoria
    final Map<String, PracticeStats> statsMap = {};
    for (final student in studentProvider.students) {
      final studentResults = allResults
          .where((r) => r.studentId == student.id)
          .toList();

      if (studentResults.isEmpty) {
        statsMap[student.id] = PracticeStats.empty();
      } else {
        final total = studentResults.length;
        final avg = studentResults
            .map((r) => r.percentage)
            .reduce((a, b) => a + b) / total;
        final best = studentResults
            .reduce((a, b) => a.percentage > b.percentage ? a : b);
        final bySubject = <String, bool>{};
        for (final r in studentResults) {
          bySubject[r.subjectId] = true;
        }
        statsMap[student.id] = PracticeStats(
          totalSessions: total,
          averagePercentage: avg,
          bestResult: best,
          subjectCount: bySubject.length,
          recentResults: studentResults.take(5).toList(),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _statsMap = statsMap;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progreso de Estudiantes'),
        backgroundColor: AppTheme.parentColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<StudentProvider>(
              builder: (context, studentProvider, _) {
                if (!studentProvider.hasStudents) {
                  return _buildEmptyState();
                }
                return RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryHeader(studentProvider.students),
                      const SizedBox(height: 20),
                      ...studentProvider.students
                          .map((s) => _buildStudentCard(s)),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text('No tienes estudiantes registrados',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('Agrega estudiantes para ver su progreso',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(List<Student> students) {
    int totalSessions = 0;
    double totalAvg = 0;
    int studentsWithActivity = 0;

    for (final student in students) {
      final stats = _statsMap[student.id];
      if (stats != null && !stats.isEmpty) {
        totalSessions += stats.totalSessions;
        totalAvg += stats.averagePercentage;
        studentsWithActivity++;
      }
    }

    final globalAvg = studentsWithActivity > 0
        ? (totalAvg / studentsWithActivity).round()
        : 0;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppTheme.parentColor.withOpacity(0.15),
              AppTheme.parentColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen General',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.parentColor,
                    )),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatBox('$globalAvg%', 'Promedio\ngeneral',
                    Icons.trending_up, AppTheme.parentColor),
                _buildStatBox('$totalSessions', 'Sesiones\ntotales',
                    Icons.fitness_center, Colors.green),
                _buildStatBox('$studentsWithActivity/${students.length}',
                    'Con\nactividad', Icons.people, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey[600], height: 1.3),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    final stats = _statsMap[student.id];
    final hasActivity = stats != null && !stats.isEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToStudentDetail(student),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: student.avatar.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(student.avatar.icon,
                    color: AppTheme.parentColor, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(student.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: student.grade.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(student.grade.displayName,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: student.grade.color,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (!hasActivity)
                      Text('Sin actividad registrada',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13))
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: stats.averagePercentage / 100,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getProgressColor(stats.averagePercentage),
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${stats.averagePercentageRounded}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  _getProgressColor(stats.averagePercentage),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${stats.totalSessions} sesiones • ${stats.subjectCount} materias',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 70) return Colors.blue;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  void _navigateToStudentDetail(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailScreen(student: student),
      ),
    );
  }
}