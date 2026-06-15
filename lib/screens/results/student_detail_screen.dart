// lib/screens/results/student_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../models/practice_result.dart';
import '../../services/result_service.dart';
import '../../utils/app_theme.dart';

class StudentDetailScreen extends StatefulWidget {
  final Student student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  List<PracticeResult> _results = [];
  PracticeStats? _stats;
  bool _isLoading = true;
  SessionType? _filterType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final resultService = context.read<ResultService>();

    // Usa getResultsByParent filtrando por parentId del estudiante
    // para respetar las reglas de Firestore — el padre puede leer por su UID
    final allResults = await resultService.getResultsByParent(
      widget.student.parentId,
    );

    // Filtrar en memoria solo los resultados de este estudiante
    final results = allResults
        .where((r) => r.studentId == widget.student.id)
        .toList();

    if (!mounted) return;

    // Calcular stats en memoria
    PracticeStats stats;
    if (results.isEmpty) {
      stats = PracticeStats.empty();
    } else {
      final total = results.length;
      final avg =
          results.map((r) => r.percentage).reduce((a, b) => a + b) / total;
      final best =
          results.reduce((a, b) => a.percentage > b.percentage ? a : b);
      final bySubject = <String, bool>{};
      for (final r in results) {
        bySubject[r.subjectId] = true;
      }
      stats = PracticeStats(
        totalSessions: total,
        averagePercentage: avg,
        bestResult: best,
        subjectCount: bySubject.length,
        recentResults: results.take(5).toList(),
      );
    }

    setState(() {
      _results = results;
      _stats = stats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.student.name),
        backgroundColor: AppTheme.parentColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStudentHeader(),
                        const SizedBox(height: 16),
                        _buildStatsCard(),
                        const SizedBox(height: 16),
                        _buildSubjectBreakdown(),
                        const SizedBox(height: 16),
                        _buildHistorySection(),
                      ],
                    ),
                  ),
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: widget.student.avatar.backgroundColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(widget.student.avatar.icon,
                  color: AppTheme.parentColor, size: 44),
            ),
            const SizedBox(height: 20),
            Text(widget.student.name,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Icon(Icons.hourglass_empty, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Sin actividad registrada',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Este estudiante aún no ha completado\nprácticas ni exámenes',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: widget.student.avatar.backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(widget.student.avatar.icon,
                  color: AppTheme.parentColor, size: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.student.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              widget.student.grade.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(widget.student.grade.displayName,
                            style: TextStyle(
                                fontSize: 12,
                                color: widget.student.grade.color,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (widget.student.age != null) ...[
                        const SizedBox(width: 8),
                        Text('${widget.student.age} años',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                      ],
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

  Widget _buildStatsCard() {
    if (_stats == null || _stats!.isEmpty) return const SizedBox.shrink();

    final practiceCount = _results
        .where((r) => r.sessionType == SessionType.practice)
        .length;
    final examCount =
        _results.where((r) => r.sessionType == SessionType.exam).length;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppTheme.parentColor.withOpacity(0.12),
              AppTheme.parentColor.withOpacity(0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estadísticas Generales',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.parentColor,
                    )),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatItem(
                    '${_stats!.averagePercentageRounded}%',
                    'Promedio',
                    Icons.trending_up,
                    _getProgressColor(_stats!.averagePercentage)),
                _buildStatItem('$practiceCount', 'Prácticas',
                    Icons.fitness_center, Colors.green),
                _buildStatItem(
                    '$examCount', 'Exámenes', Icons.timer, Colors.red),
                _buildStatItem('${_stats!.subjectCount}', 'Materias',
                    Icons.book, Colors.orange),
              ],
            ),
            if (_stats!.bestResult != null) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.emoji_events,
                      color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text('Mejor resultado: ',
                      style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                  Expanded(
                    child: Text(
                      '${_stats!.bestResult!.percentageRounded}% en ${_stats!.bestResult!.subjectName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSubjectBreakdown() {
    final Map<String, List<PracticeResult>> bySubject = {};
    for (final r in _results) {
      bySubject.putIfAbsent(r.subjectName, () => []).add(r);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progreso por Materia',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 16),
            ...bySubject.entries.map((entry) {
              final subjectResults = entry.value;
              final avg = subjectResults
                      .map((r) => r.percentage)
                      .reduce((a, b) => a + b) /
                  subjectResults.length;
              final best = subjectResults.reduce(
                  (a, b) => a.percentage > b.percentage ? a : b);

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(entry.key,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ),
                        Text(
                          '${avg.round()}% prom.',
                          style: TextStyle(
                            color: _getProgressColor(avg),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: avg / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _getProgressColor(avg)),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${subjectResults.length} sesiones  •  Mejor: ${best.percentageRounded}%',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    final filtered = _filterType != null
        ? _results.where((r) => r.sessionType == _filterType).toList()
        : _results;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Historial',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            _buildFilterChip('Todos', null, Colors.grey),
            const SizedBox(width: 6),
            _buildFilterChip('Práctica', SessionType.practice, Colors.green),
            const SizedBox(width: 6),
            _buildFilterChip('Examen', SessionType.exam, Colors.red),
          ],
        ),
        const SizedBox(height: 12),
        ...filtered.map((r) => _buildResultCard(r)),
      ],
    );
  }

  Widget _buildFilterChip(String label, SessionType? type, Color color) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? color : Colors.grey[600],
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
            )),
      ),
    );
  }

  Widget _buildResultCard(PracticeResult result) {
    final color = _getProgressColor(result.percentage);
    final isExam = result.sessionType == SessionType.exam;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
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
                      fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(result.subjectName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      Text(result.rating.emoji,
                          style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${result.correctAnswers}/${result.totalQuestions} correctas  •  ${result.rating.displayName}',
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isExam
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
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
                              isExam ? Icons.timer : Icons.fitness_center,
                              size: 10,
                              color: isExam ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              result.sessionType.displayName,
                              style: TextStyle(
                                fontSize: 10,
                                color: isExam ? Colors.red : Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_formatDate(result.completedAt),
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 11)),
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

  Color _getProgressColor(double percentage) {
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