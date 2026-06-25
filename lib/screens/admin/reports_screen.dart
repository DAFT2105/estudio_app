// lib/screens/admin/reports_screen.dart

import 'package:flutter/material.dart';
import '../../services/admin_stats_service.dart';
import '../../models/practice_result.dart';
import '../../utils/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _statsService = AdminStatsService();
  AdminStats? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await _statsService.getSystemStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar estadísticas: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes y Estadísticas'),
        backgroundColor: AppTheme.adminColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadStats, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final stats = _stats!;

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Resumen general'),
          _buildSummaryGrid(stats),
          const SizedBox(height: 24),
          _buildSectionTitle('Rendimiento del sistema'),
          _buildPerformanceCard(stats),
          const SizedBox(height: 24),
          _buildSectionTitle('Práctica vs Examen'),
          _buildPracticeVsExamCard(stats),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSummaryGrid(AdminStats stats) {
    final items = [
      _SummaryItem('Padres', stats.totalParents, Icons.family_restroom, AppTheme.parentColor),
      _SummaryItem('Estudiantes', stats.totalStudents, Icons.school, AppTheme.studentColor),
      _SummaryItem('Materias', stats.totalSubjects, Icons.book, Colors.orange),
      _SummaryItem('Preguntas', stats.totalQuestions, Icons.quiz, Colors.teal),
      _SummaryItem('Sesiones totales', stats.totalSessions, Icons.assignment_turned_in, AppTheme.adminColor),
      _SummaryItem('Admins', stats.totalAdmins, Icons.admin_panel_settings, Colors.deepPurple),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(item.icon, color: item.color, size: 22),
                Text(
                  '${item.value}',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: item.color,
                  ),
                ),
                Text(
                  item.label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerformanceCard(AdminStats stats) {
    if (stats.totalSessions == 0) {
      return _buildEmptyState('Aún no hay sesiones de práctica/examen registradas en el sistema');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${stats.averagePercentageRounded}%',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'promedio de aciertos\nen todo el sistema',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Distribución de calificaciones',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 12),
            _buildRatingBar(stats, ResultRating.excellent, Colors.green),
            const SizedBox(height: 10),
            _buildRatingBar(stats, ResultRating.good, Colors.lightGreen),
            const SizedBox(height: 10),
            _buildRatingBar(stats, ResultRating.regular, Colors.orange),
            const SizedBox(height: 10),
            _buildRatingBar(stats, ResultRating.needsWork, Colors.red[400]!),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar(AdminStats stats, ResultRating rating, Color color) {
    final percentage = stats.ratingPercentage(rating);
    final count = stats.ratingCount(rating);

    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '${rating.emoji} ${rating.displayName}',
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 14,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 56,
          child: Text(
            '$count (${percentage.round()}%)',
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeVsExamCard(AdminStats stats) {
    if (stats.totalSessions == 0) {
      return _buildEmptyState('Sin sesiones registradas todavía');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Barra horizontal combinada (práctica + examen)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  if (stats.practiceSessionsCount > 0)
                    Expanded(
                      flex: stats.practiceSessionsCount,
                      child: Container(height: 28, color: AppTheme.studentColor),
                    ),
                  if (stats.examSessionsCount > 0)
                    Expanded(
                      flex: stats.examSessionsCount,
                      child: Container(height: 28, color: Colors.deepOrange),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(
                  '💪 Práctica',
                  stats.practiceSessionsCount,
                  stats.practicePercentage,
                  AppTheme.studentColor,
                ),
                _buildLegendItem(
                  '📝 Examen',
                  stats.examSessionsCount,
                  stats.examPercentage,
                  Colors.deepOrange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, int count, double percentage, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, color: color),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$count sesiones (${percentage.round()}%)',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  _SummaryItem(this.label, this.value, this.icon, this.color);
}