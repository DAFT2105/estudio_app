// lib/screens/results/results_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/result_provider.dart';
import '../../models/practice_result.dart';
import '../../utils/app_theme.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  SessionType? _filterType; // null = todos

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadResults());
  }

  Future<void> _loadResults() async {
    final authProvider = context.read<AuthProvider>();
    final resultProvider = context.read<ResultProvider>();
    await resultProvider.loadResults(authProvider.currentUser!.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Resultados'),
        backgroundColor: AppTheme.studentColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<ResultProvider>(
        builder: (context, resultProvider, child) {
          if (resultProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!resultProvider.hasResults) {
            return _buildEmptyState();
          }
          return RefreshIndicator(
            onRefresh: _loadResults,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsCard(resultProvider),
                  const SizedBox(height: 20),
                  _buildFilterRow(resultProvider),
                  const SizedBox(height: 12),
                  _buildHistorySection(resultProvider),
                ],
              ),
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
            Icon(Icons.assessment_outlined,
                size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text('Aún no tienes resultados',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('Completa una práctica o examen para ver tu progreso aquí',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Ir a Practicar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.studentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(ResultProvider resultProvider) {
    final stats = resultProvider.stats;
    if (stats == null || stats.isEmpty) return const SizedBox.shrink();

    final practiceCount = resultProvider.results
        .where((r) => r.sessionType == SessionType.practice)
        .length;
    final examCount = resultProvider.results
        .where((r) => r.sessionType == SessionType.exam)
        .length;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppTheme.studentColor.withOpacity(0.15),
              AppTheme.studentColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mi Progreso General',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.studentColor,
                    )),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatItem('${stats.averagePercentageRounded}%',
                    'Promedio', Icons.trending_up, AppTheme.studentColor),
                _buildStatItem('$practiceCount', 'Prácticas',
                    Icons.fitness_center, Colors.green),
                _buildStatItem('$examCount', 'Exámenes',
                    Icons.timer, Colors.red),
                _buildStatItem('${stats.subjectCount}', 'Materias',
                    Icons.book, Colors.orange),
              ],
            ),
            if (stats.bestResult != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.emoji_events,
                      color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text('Mejor resultado: ',
                      style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500)),
                  Expanded(
                    child: Text(
                      '${stats.bestResult!.percentageRounded}% en ${stats.bestResult!.subjectName}',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // Filtro por tipo de sesión
  Widget _buildFilterRow(ResultProvider resultProvider) {
    final total = resultProvider.results.length;
    final practiceCount = resultProvider.results
        .where((r) => r.sessionType == SessionType.practice)
        .length;
    final examCount = resultProvider.results
        .where((r) => r.sessionType == SessionType.exam)
        .length;

    return Row(
      children: [
        Text('Historial',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const Spacer(),
        _buildFilterChip('Todos ($total)', null, Colors.grey),
        const SizedBox(width: 6),
        _buildFilterChip(
            'Práctica ($practiceCount)', SessionType.practice, Colors.green),
        const SizedBox(width: 6),
        _buildFilterChip(
            'Examen ($examCount)', SessionType.exam, Colors.red),
      ],
    );
  }

  Widget _buildFilterChip(
      String label, SessionType? type, Color color) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? color : Colors.grey[600],
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection(ResultProvider resultProvider) {
    final results = _filterType != null
        ? resultProvider.results
            .where((r) => r.sessionType == _filterType)
            .toList()
        : resultProvider.results;

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('Sin resultados para este filtro',
              style: TextStyle(color: Colors.grey[600])),
        ),
      );
    }

    return Column(
      children: results.map((r) => _buildResultCard(r)).toList(),
    );
  }

  Widget _buildResultCard(PracticeResult result) {
    final color = _getPercentageColor(result.percentage);
    final isExam = result.sessionType == SessionType.exam;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Círculo de porcentaje
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: Text(
                  '${result.percentageRounded}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Información
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre materia + emoji rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          result.subjectName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ),
                      Text(result.rating.emoji,
                          style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Correctas y rating
                  Text(
                    '${result.correctAnswers}/${result.totalQuestions} correctas  •  ${result.rating.displayName}',
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 6),

                  // Fila inferior: tipo + fecha
                  Row(
                    children: [
                      // Badge tipo: Práctica o Examen
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isExam
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isExam
                                ? Colors.red.withOpacity(0.3)
                                : Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isExam
                                  ? Icons.timer
                                  : Icons.fitness_center,
                              size: 11,
                              color: isExam
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              result.sessionType.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                color: isExam
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(result.completedAt),
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPercentageColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 70) return Colors.blue;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${date.day}/${date.month}/${date.year}';
  }
}