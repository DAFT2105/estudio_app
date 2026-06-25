// lib/screens/students/question_set_chooser_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/question_provider.dart';
import '../../providers/question_set_provider.dart';
import '../../models/question.dart';
import '../../models/question_set.dart';
import '../../models/subject.dart';
import '../../utils/app_theme.dart';
import 'practice_config_screen.dart';
import 'practice_mode_screen.dart';
import 'exam_config_screen.dart';
import 'exam_mode_screen.dart';

/// Punto de entrada al tomar Práctica o Examen de una materia: elegir entre
/// el modo aleatorio de siempre, o uno de los grupos fijos armados por el
/// padre (QuestionSet). Solo se muestra cuando hay al menos un grupo
/// disponible — si no hay ninguno, se salta directo al modo aleatorio.
class QuestionSetChooserScreen extends StatefulWidget {
  final Subject subject;
  final QuestionPurpose purpose;

  const QuestionSetChooserScreen({
    super.key,
    required this.subject,
    required this.purpose,
  });

  @override
  State<QuestionSetChooserScreen> createState() =>
      _QuestionSetChooserScreenState();
}

class _QuestionSetChooserScreenState extends State<QuestionSetChooserScreen> {
  bool _isLoading = true;

  bool get _isExam => widget.purpose == QuestionPurpose.exam;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final setProvider = context.read<QuestionSetProvider>();
    final questionProvider = context.read<QuestionProvider>();
    await Future.wait([
      setProvider.loadSetsBySubject(widget.subject.id, purpose: widget.purpose),
      questionProvider.loadQuestionsBySubject(widget.subject.id),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.subject.color.color;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isExam ? 'Examen' : 'Práctica'),
        backgroundColor: color,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<QuestionSetProvider>(
              builder: (context, setProvider, child) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '¿Cómo quieres practicar ${widget.subject.name}?',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildRandomOption(color),
                    if (setProvider.sets.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Armados por tu padre/madre',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      ...setProvider.sets.map(_buildSetOption),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _buildRandomOption(Color color) {
    return InkWell(
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _isExam
              ? ExamConfigScreen(subject: widget.subject)
              : PracticeConfigScreen(subject: widget.subject),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shuffle, color: Colors.white),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aleatorio', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Preguntas al azar de toda la materia',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildSetOption(QuestionSet set) {
    final color = widget.purpose.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _startSet(set),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.purpose.icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(set.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${set.questionCount} preguntas',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startSet(QuestionSet set) async {
    final questionProvider = context.read<QuestionProvider>();
    final setProvider = context.read<QuestionSetProvider>();
    final questions = setProvider.resolveQuestions(set, questionProvider.questions);

    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron cargar las preguntas de este grupo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isExam) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PracticeModeScreen(
            subject: widget.subject,
            questions: questions,
          ),
        ),
      );
      return;
    }

    // Examen — preguntar el tiempo límite antes de arrancar
    final timeLimit = await _pickTimeLimit();
    if (timeLimit == null || !mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ExamModeScreen(
          subject: widget.subject,
          questions: questions,
          timeLimitMinutes: timeLimit,
        ),
      ),
    );
  }

  Future<int?> _pickTimeLimit() async {
    const options = [
      {'minutes': 10, 'label': '10 min', 'subtitle': 'Rápido'},
      {'minutes': 20, 'label': '20 min', 'subtitle': 'Estándar'},
      {'minutes': 30, 'label': '30 min', 'subtitle': 'Extendido'},
      {'minutes': 45, 'label': '45 min', 'subtitle': 'Largo'},
    ];

    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cuánto tiempo para este examen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
            return ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(opt['label'] as String),
              subtitle: Text(opt['subtitle'] as String),
              onTap: () => Navigator.pop(context, opt['minutes'] as int),
            );
          }).toList(),
        ),
      ),
    );
  }
}