// lib/screens/student/practice_config_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/question_provider.dart';
import '../../models/subject.dart';
import '../../models/question.dart';
import '../../utils/app_theme.dart';
import 'practice_mode_screen.dart';

class PracticeConfigScreen extends StatefulWidget {
  final Subject subject;
  
  const PracticeConfigScreen({
    super.key,
    required this.subject,
  });

  @override
  State<PracticeConfigScreen> createState() => _PracticeConfigScreenState();
}

class _PracticeConfigScreenState extends State<PracticeConfigScreen> {
  int _questionCount = 10;
  QuestionDifficulty? _selectedDifficulty;
  String? _selectedTopic;
  bool _isLoading = true;
  int _availableQuestions = 0;
  List<String> _availableTopics = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQuestions();
    });
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    
    final questionProvider = context.read<QuestionProvider>();
    await questionProvider.loadQuestionsBySubject(widget.subject.id);

    // Solo preguntas que aplican a Práctica (las legacy sin modo definido
    // cuentan para ambos — ver Question.appliesTo)
    final practiceQuestions = questionProvider.questions
        .where((q) => q.appliesTo(QuestionPurpose.practice))
        .toList();
    
    setState(() {
      _availableQuestions = practiceQuestions.length;
      _availableTopics = practiceQuestions
          .where((q) => q.topic != null && q.topic!.isNotEmpty)
          .map((q) => q.topic!)
          .toSet()
          .toList()
        ..sort();
      
      // CORREGIDO: Ajustar valor inicial según preguntas disponibles
      if (_availableQuestions > 0) {
        _questionCount = _availableQuestions >= 10 ? 10 : _availableQuestions;
      }
      
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Práctica'),
        backgroundColor: widget.subject.color.color,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availableQuestions == 0
              ? _buildNoQuestionsState()
              : _buildConfigForm(),
      bottomNavigationBar: _isLoading || _availableQuestions == 0
          ? null
          : _buildStartButton(),
    );
  }

  Widget _buildNoQuestionsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No hay preguntas disponibles',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tu tutor aún no ha agregado preguntas para esta materia',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSubjectHeader(),
        const SizedBox(height: 24),
        _buildQuestionCountSection(),
        const SizedBox(height: 16),
        _buildDifficultySection(),
        const SizedBox(height: 16),
        if (_availableTopics.isNotEmpty) ...[
          _buildTopicSection(),
          const SizedBox(height: 16),
        ],
        _buildSummaryCard(),
      ],
    );
  }

  Widget _buildSubjectHeader() {
    return Card(
      color: widget.subject.color.color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: widget.subject.color.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.subject.icon.icon,
                color: widget.subject.color.color,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.subject.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_availableQuestions preguntas disponibles',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCountSection() {
    // CORREGIDO: Calcular min y max correctamente
    final int minQuestions = _availableQuestions >= 5 ? 5 : _availableQuestions;
    final int maxQuestions = _availableQuestions > 50 ? 50 : _availableQuestions;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.format_list_numbered, color: AppTheme.studentColor),
                const SizedBox(width: 8),
                const Text(
                  'Cantidad de Preguntas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _questionCount.toDouble().clamp(
                      minQuestions.toDouble(),
                      maxQuestions.toDouble(),
                    ),
                    min: minQuestions.toDouble(),
                    max: maxQuestions.toDouble(),
                    divisions: maxQuestions > minQuestions ? (maxQuestions - minQuestions) : 1,
                    label: _questionCount.toString(),
                    activeColor: widget.subject.color.color,
                    onChanged: (value) {
                      setState(() {
                        _questionCount = value.round();
                      });
                    },
                  ),
                ),
                Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.subject.color.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_questionCount',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.subject.color.color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.signal_cellular_alt, color: AppTheme.studentColor),
                const SizedBox(width: 8),
                const Text(
                  'Dificultad',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDifficultyChip('Todas', null),
                ...QuestionDifficulty.values.map((diff) {
                  return _buildDifficultyChip(diff.displayName, diff);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(String label, QuestionDifficulty? difficulty) {
    final isSelected = _selectedDifficulty == difficulty;
    final color = difficulty?.color ?? Colors.grey;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (difficulty != null)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          if (difficulty != null) const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedDifficulty = selected ? difficulty : null;
        });
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
    );
  }

  Widget _buildTopicSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: AppTheme.studentColor),
                const SizedBox(width: 8),
                const Text(
                  'Tema',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTopicChip('Todos', null),
                ..._availableTopics.map((topic) {
                  return _buildTopicChip(topic, topic);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicChip(String label, String? topic) {
    final isSelected = _selectedTopic == topic;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedTopic = selected ? topic : null;
        });
      },
      selectedColor: widget.subject.color.color.withOpacity(0.2),
      checkmarkColor: widget.subject.color.color,
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Resumen de Práctica',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(Icons.quiz, '$_questionCount preguntas'),
            if (_selectedDifficulty != null)
              _buildSummaryRow(
                Icons.signal_cellular_alt,
                'Dificultad: ${_selectedDifficulty!.displayName}',
              ),
            if (_selectedTopic != null)
              _buildSummaryRow(Icons.category, 'Tema: $_selectedTopic'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.blue[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verás la respuesta correcta después de cada pregunta',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _startPractice,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.subject.color.color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow, size: 28),
              SizedBox(width: 8),
              Text(
                'Comenzar Práctica',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startPractice() async {
    final questionProvider = context.read<QuestionProvider>();
    
    // Obtener preguntas según configuración
    final questions = await questionProvider.getRandomQuestions(
      subjectId: widget.subject.id,
      count: _questionCount,
      difficulty: _selectedDifficulty,
      topic: _selectedTopic,
      purpose: QuestionPurpose.practice,
    );

    if (questions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron preguntas con esos filtros'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PracticeModeScreen(
            subject: widget.subject,
            questions: questions,
          ),
        ),
      );
    }
  }
}