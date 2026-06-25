// lib/screens/student/practice_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subject_provider.dart';
import '../../providers/question_provider.dart';
import '../../providers/question_set_provider.dart';
import '../../models/question.dart';
import '../../models/subject.dart';
import '../../utils/app_theme.dart';
import 'practice_config_screen.dart';
import 'question_set_chooser_screen.dart';

class PracticeSelectionScreen extends StatefulWidget {
  const PracticeSelectionScreen({super.key});

  @override
  State<PracticeSelectionScreen> createState() => _PracticeSelectionScreenState();
}

class _PracticeSelectionScreenState extends State<PracticeSelectionScreen> {
  
  // Mapa que guarda subjectId → cantidad de preguntas
  Map<String, int> _questionCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final subjectProvider = context.read<SubjectProvider>();
    final questionProvider = context.read<QuestionProvider>();
    final currentUser = authProvider.currentUser!;

    // Cargar materias del estudiante directamente — no necesitamos loadStudents
    await subjectProvider.loadSubjects(
      currentUser.id,
      currentUser.role.toString().split('.').last,
    );

    if (!mounted) return;

    // assignedSubjects viene directo de currentUser — sin query a students
    final assignedSubjects = subjectProvider.subjects.where((subject) {
      return currentUser.assignedSubjects?.contains(subject.id) ?? false;
    }).toList();

    // Cargar conteo de preguntas para cada materia UNA SOLA VEZ
    final Map<String, int> counts = {};
    for (final subject in assignedSubjects) {
      await questionProvider.loadQuestionsBySubject(subject.id);
      counts[subject.id] = questionProvider.questions.length;
    }

    if (!mounted) return;
    setState(() {
      _questionCounts = counts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo Práctica'),
        backgroundColor: AppTheme.studentColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<SubjectProvider>(
              builder: (context, subjectProvider, child) {
                final currentUser =
                    context.read<AuthProvider>().currentUser!;

                final assignedSubjects =
                    subjectProvider.subjects.where((subject) {
                  return currentUser.assignedSubjects?.contains(subject.id) ?? false;
                }).toList();

                if (assignedSubjects.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildSubjectsList(assignedSubjects);
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
            Icon(Icons.school_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No tienes materias asignadas',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Contacta a tu tutor para que te asigne materias',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectsList(List<Subject> subjects) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        ...subjects.map((subject) => _buildSubjectCard(subject)),
      ],
    );
  }

  Widget _buildHeader() {
    return Card(
      color: AppTheme.studentColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.studentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.fitness_center,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modo Práctica',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.studentColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Practica sin límite de tiempo y ve las respuestas al instante',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(Subject subject) {
    // Leer del mapa precargado — sin llamadas durante el build
    final questionCount = _questionCounts[subject.id] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToPracticeConfig(subject),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: subject.color.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(subject.icon.icon,
                        color: subject.color.color, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subject.description,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.studentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.quiz, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '$questionCount preguntas disponibles',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subject.formattedDuration.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      subject.formattedDuration,
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPracticeConfig(Subject subject) async {
    final setProvider = context.read<QuestionSetProvider>();
    await setProvider.loadSetsBySubject(subject.id, purpose: QuestionPurpose.practice);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => setProvider.sets.isEmpty
            ? PracticeConfigScreen(subject: subject)
            : QuestionSetChooserScreen(
                subject: subject,
                purpose: QuestionPurpose.practice,
              ),
      ),
    );
  }
}