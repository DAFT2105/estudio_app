// lib/screens/student/exam_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subject_provider.dart';
import '../../providers/question_provider.dart';
import '../../models/subject.dart';
import '../../utils/app_theme.dart';
import 'exam_config_screen.dart';

class ExamSelectionScreen extends StatefulWidget {
  const ExamSelectionScreen({super.key});

  @override
  State<ExamSelectionScreen> createState() => _ExamSelectionScreenState();
}

class _ExamSelectionScreenState extends State<ExamSelectionScreen> {
  Map<String, int> _questionCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
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
    final assignedSubjects = subjectProvider.subjects.where((s) =>
        currentUser.assignedSubjects?.contains(s.id) ?? false).toList();

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
        title: const Text('Modo Examen'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<SubjectProvider>(
              builder: (context, subjectProvider, _) {
                final currentUser =
                    context.read<AuthProvider>().currentUser!;

                final assignedSubjects = subjectProvider.subjects
                    .where((s) => currentUser.assignedSubjects?.contains(s.id) ?? false)
                    .toList();

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
            Icon(Icons.school_outlined,
                size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text('No tienes materias asignadas',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('Contacta a tu tutor para que te asigne materias',
                style:
                    TextStyle(color: Colors.grey[600], fontSize: 16),
                textAlign: TextAlign.center),
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
        ...subjects.map((s) => _buildSubjectCard(s)),
      ],
    );
  }

  Widget _buildHeader() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[700],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.timer,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Modo Examen',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[800])),
                  const SizedBox(height: 4),
                  Text(
                    'Tiempo limitado • Sin respuestas hasta el final',
                    style: TextStyle(color: Colors.red[600]),
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
    final questionCount = _questionCounts[subject.id] ?? 0;
    final hasQuestions = questionCount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: hasQuestions
            ? () => _navigateToExamConfig(subject)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: subject.color.color.withOpacity(
                      hasQuestions ? 0.1 : 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(subject.icon.icon,
                    color: subject.color.color
                        .withOpacity(hasQuestions ? 1.0 : 0.4),
                    size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: hasQuestions
                              ? Colors.black
                              : Colors.grey[400],
                        )),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.quiz,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          hasQuestions
                              ? '$questionCount preguntas'
                              : 'Sin preguntas',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasQuestions
                      ? Colors.red[700]
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasQuestions ? Icons.timer : Icons.block,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToExamConfig(Subject subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExamConfigScreen(subject: subject),
      ),
    );
  }
}