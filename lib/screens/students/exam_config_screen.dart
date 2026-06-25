// lib/screens/student/exam_config_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/question_provider.dart';
import '../../models/subject.dart';
import '../../models/question.dart';
import '../../utils/app_theme.dart';
import 'exam_mode_screen.dart';

class ExamConfigScreen extends StatefulWidget {
  final Subject subject;

  const ExamConfigScreen({
    super.key,
    required this.subject,
  });

  @override
  State<ExamConfigScreen> createState() => _ExamConfigScreenState();
}

class _ExamConfigScreenState extends State<ExamConfigScreen> {
  int _questionCount = 10;
  QuestionDifficulty? _selectedDifficulty;
  String? _selectedTopic;
  bool _isLoading = true;
  int _availableQuestions = 0;
  List<String> _availableTopics = [];
  int _timeLimitMinutes = 20; // Por defecto 20 minutos

  // Opciones de tiempo predefinidas
  final List<Map<String, dynamic>> _timeOptions = [
    {'minutes': 10, 'label': '10 min', 'subtitle': 'Rápido'},
    {'minutes': 20, 'label': '20 min', 'subtitle': 'Estándar'},
    {'minutes': 30, 'label': '30 min', 'subtitle': 'Extendido'},
    {'minutes': 45, 'label': '45 min', 'subtitle': 'Largo'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuestions());
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    final questionProvider = context.read<QuestionProvider>();
    await questionProvider.loadQuestionsBySubject(widget.subject.id);

    // Solo preguntas que aplican a Examen (las legacy sin modo definido
    // cuentan para ambos — ver Question.appliesTo)
    final examQuestions = questionProvider.questions
        .where((q) => q.appliesTo(QuestionPurpose.exam))
        .toList();

    setState(() {
      _availableQuestions = examQuestions.length;
      _availableTopics = examQuestions
          .where((q) => q.topic != null && q.topic!.isNotEmpty)
          .map((q) => q.topic!)
          .toSet()
          .toList()
        ..sort();
      if (_availableQuestions > 0) {
        _questionCount =
            _availableQuestions >= 10 ? 10 : _availableQuestions;
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Examen'),
        backgroundColor: widget.subject.color.color,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availableQuestions == 0
              ? _buildNoQuestionsState()
              : _buildConfigForm(),
      bottomNavigationBar:
          _isLoading || _availableQuestions == 0 ? null : _buildStartButton(),
    );
  }

  Widget _buildNoQuestionsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No hay preguntas disponibles',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tu tutor aún no ha agregado preguntas para esta materia',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
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
        const SizedBox(height: 20),
        _buildTimeLimitSection(),
        const SizedBox(height: 16),
        _buildQuestionCountSection(),
        const SizedBox(height: 16),
        _buildDifficultySection(),
        if (_availableTopics.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildTopicSection(),
        ],
        const SizedBox(height: 16),
        _buildSummaryCard(),
      ],
    );
  }

  Widget _buildSubjectHeader() {
    return Card(
      color: widget.subject.color.color.withOpacity(0.08),
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
              child: Icon(widget.subject.icon.icon,
                  color: widget.subject.color.color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.subject.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('$_availableQuestions preguntas disponibles',
                      style: TextStyle(
                          color: Colors.grey[700], fontSize: 13)),
                ],
              ),
            ),
            // Chip de EXAMEN
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, color: Colors.red, size: 14),
                  SizedBox(width: 4),
                  Text('EXAMEN',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeLimitSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer, color: Colors.red[600]),
                const SizedBox(width: 8),
                const Text('Tiempo Límite',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.1,
              children: _timeOptions.map((option) {
                final isSelected =
                    _timeLimitMinutes == option['minutes'];
                return GestureDetector(
                  onTap: () => setState(
                      () => _timeLimitMinutes = option['minutes']),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Colors.red
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? Colors.red.withOpacity(0.08)
                          : Colors.white,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          option['label'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isSelected
                                ? Colors.red
                                : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          option['subtitle'],
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? Colors.red[400]
                                : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCountSection() {
    final int minQ =
        _availableQuestions >= 5 ? 5 : _availableQuestions;
    final int maxQ =
        _availableQuestions > 50 ? 50 : _availableQuestions;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.format_list_numbered,
                    color: AppTheme.studentColor),
                const SizedBox(width: 8),
                const Text('Cantidad de Preguntas',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _questionCount.toDouble().clamp(
                        minQ.toDouble(), maxQ.toDouble()),
                    min: minQ.toDouble(),
                    max: maxQ.toDouble(),
                    divisions: maxQ > minQ ? (maxQ - minQ) : 1,
                    label: _questionCount.toString(),
                    activeColor: widget.subject.color.color,
                    onChanged: (value) =>
                        setState(() => _questionCount = value.round()),
                  ),
                ),
                Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        widget.subject.color.color.withOpacity(0.1),
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
                Icon(Icons.signal_cellular_alt,
                    color: AppTheme.studentColor),
                const SizedBox(width: 8),
                const Text('Dificultad',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDifficultyChip('Todas', null),
                ...QuestionDifficulty.values.map((d) =>
                    _buildDifficultyChip(d.displayName, d)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(
      String label, QuestionDifficulty? difficulty) {
    final isSelected = _selectedDifficulty == difficulty;
    final color = difficulty?.color ?? Colors.grey;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (difficulty != null) ...[
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (s) => setState(
          () => _selectedDifficulty = s ? difficulty : null),
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
                const Text('Tema',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTopicChip('Todos', null),
                ..._availableTopics
                    .map((t) => _buildTopicChip(t, t)),
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
      onSelected: (s) =>
          setState(() => _selectedTopic = s ? topic : null),
      selectedColor:
          widget.subject.color.color.withOpacity(0.2),
      checkmarkColor: widget.subject.color.color,
    );
  }

  Widget _buildSummaryCard() {
    // Tiempo por pregunta estimado
    final secPerQuestion =
        (_timeLimitMinutes * 60) ~/ _questionCount;
    final minPP = secPerQuestion ~/ 60;
    final secPP = secPerQuestion % 60;
    final timePerQuestion =
        minPP > 0 ? '${minPP}m ${secPP}s' : '${secPP}s';

    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.red[700]),
                const SizedBox(width: 8),
                Text('Resumen del Examen',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[900])),
              ],
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
                Icons.quiz, '$_questionCount preguntas'),
            _buildSummaryRow(
                Icons.timer, '$_timeLimitMinutes minutos'),
            _buildSummaryRow(
                Icons.speed, '~$timePerQuestion por pregunta'),
            if (_selectedDifficulty != null)
              _buildSummaryRow(Icons.signal_cellular_alt,
                  'Dificultad: ${_selectedDifficulty!.displayName}'),
            if (_selectedTopic != null)
              _buildSummaryRow(
                  Icons.category, 'Tema: $_selectedTopic'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: Colors.red[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No verás las respuestas hasta finalizar el examen',
                      style: TextStyle(
                          fontSize: 12, color: Colors.red[900]),
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
          Icon(icon, size: 16, color: Colors.red[700]),
          const SizedBox(width: 8),
          Text(text,
              style:
                  TextStyle(fontSize: 14, color: Colors.red[900])),
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
              color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: _startExam,
          icon: const Icon(Icons.timer, size: 24),
          label: const Text('Comenzar Examen',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Future<void> _startExam() async {
    final questionProvider = context.read<QuestionProvider>();
    final questions = await questionProvider.getRandomQuestions(
      subjectId: widget.subject.id,
      count: _questionCount,
      difficulty: _selectedDifficulty,
      topic: _selectedTopic,
      purpose: QuestionPurpose.exam,
    );

    if (questions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('No se encontraron preguntas con esos filtros'),
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
          builder: (context) => ExamModeScreen(
            subject: widget.subject,
            questions: questions,
            timeLimitMinutes: _timeLimitMinutes,
          ),
        ),
      );
    }
  }
}