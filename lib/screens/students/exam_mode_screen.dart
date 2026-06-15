// lib/screens/student/exam_mode_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/subject.dart';
import '../../models/question.dart';
import '../../models/practice_result.dart';
import '../../providers/auth_provider.dart';
import '../../providers/result_provider.dart';
import '../../utils/app_theme.dart';

class ExamModeScreen extends StatefulWidget {
  final Subject subject;
  final List<Question> questions;
  final int timeLimitMinutes; // Tiempo límite en minutos

  const ExamModeScreen({
    super.key,
    required this.subject,
    required this.questions,
    required this.timeLimitMinutes,
  });

  @override
  State<ExamModeScreen> createState() => _ExamModeScreenState();
}

class _ExamModeScreenState extends State<ExamModeScreen> {
  int _currentQuestionIndex = 0;
  // Guarda la respuesta seleccionada por pregunta
  final Map<int, String> _selectedAnswers = {};
  late DateTime _startTime;

  // Timer
  late int _remainingSeconds;
  Timer? _timer;
  bool _timeExpired = false;

  // Short answer controller
  final TextEditingController _shortAnswerController = TextEditingController();

  Question get _currentQuestion => widget.questions[_currentQuestionIndex];
  bool get _isLastQuestion =>
      _currentQuestionIndex == widget.questions.length - 1;
  double get _progress =>
      (_currentQuestionIndex + 1) / widget.questions.length;
  String? get _currentAnswer => _selectedAnswers[_currentQuestionIndex];

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _remainingSeconds = widget.timeLimitMinutes * 60;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shortAnswerController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timeExpired = true;
          timer.cancel();
          _finishExam(timeExpired: true);
        }
      });
    });
  }

  String get _timerDisplay {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color get _timerColor {
    if (_remainingSeconds <= 60) return Colors.red;
    if (_remainingSeconds <= 180) return Colors.orange;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildProgressBar(),
            Expanded(child: _buildQuestionView()),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: widget.subject.color.color,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => _onWillPop(),
      ),
      title: Column(
        children: [
          Text(
            widget.subject.name,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            'Pregunta ${_currentQuestionIndex + 1} de ${widget.questions.length}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        // Timer
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer, color: _timerColor, size: 18),
              const SizedBox(width: 4),
              Text(
                _timerDisplay,
                style: TextStyle(
                  color: _timerColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return LinearProgressIndicator(
      value: _progress,
      backgroundColor: Colors.grey[200],
      valueColor: AlwaysStoppedAnimation<Color>(widget.subject.color.color),
      minHeight: 6,
    );
  }

  Widget _buildQuestionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de examen
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Modo Examen — No verás las respuestas hasta el final',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tarjeta de pregunta
          _buildQuestionCard(),
          const SizedBox(height: 24),

          // Opciones de respuesta
          _buildAnswerOptions(),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tipo y dificultad
            Row(
              children: [
                _buildTag(
                  _currentQuestion.type.displayName,
                  _currentQuestion.type.color,
                  _currentQuestion.type.icon,
                ),
                const SizedBox(width: 8),
                _buildTag(
                  _currentQuestion.difficulty.displayName,
                  _currentQuestion.difficulty.color,
                  Icons.bar_chart,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _currentQuestion.text,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
            ),
            if (_currentQuestion.topic != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.label_outline,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _currentQuestion.topic!,
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerOptions() {
    switch (_currentQuestion.type) {
      case QuestionType.multipleChoice:
        return _buildMultipleChoiceOptions();
      case QuestionType.trueFalse:
        return _buildTrueFalseOptions();
      case QuestionType.shortAnswer:
        return _buildShortAnswerOption();
    }
  }

  Widget _buildMultipleChoiceOptions() {
    return Column(
      children: List.generate(_currentQuestion.options.length, (index) {
        final option = _currentQuestion.options[index];
        final letter = String.fromCharCode(65 + index);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildOptionButton(option, letter),
        );
      }),
    );
  }

  Widget _buildTrueFalseOptions() {
    return Row(
      children: [
        Expanded(child: _buildOptionButton('Verdadero', '✓')),
        const SizedBox(width: 12),
        Expanded(child: _buildOptionButton('Falso', '✗')),
      ],
    );
  }

  Widget _buildShortAnswerOption() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Escribe tu respuesta:',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _shortAnswerController,
              decoration: const InputDecoration(
                hintText: 'Tu respuesta aquí...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _selectedAnswers[_currentQuestionIndex] = value;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(String option, String prefix) {
    final isSelected = _currentAnswer == option;
    final color = widget.subject.color.color;

    return InkWell(
      onTap: () => setState(() {
        _selectedAnswers[_currentQuestionIndex] = option;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.grey[200],
              ),
              child: Center(
                child: Text(
                  prefix,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color : Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final answered = _selectedAnswers.length;
    final total = widget.questions.length;
    final canGoBack = _currentQuestionIndex > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Contador de respondidas
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '$answered/$total respondidas',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Botón atrás
                if (canGoBack)
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Anterior'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: widget.subject.color.color),
                        foregroundColor: widget.subject.color.color,
                      ),
                    ),
                  ),
                if (canGoBack) const SizedBox(width: 12),

                // Botón siguiente / finalizar
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isLastQuestion
                        ? () => _confirmFinish()
                        : _goNext,
                    icon: Icon(
                        _isLastQuestion ? Icons.flag : Icons.arrow_forward),
                    label: Text(
                      _isLastQuestion ? 'Finalizar Examen' : 'Siguiente',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isLastQuestion
                          ? Colors.green
                          : widget.subject.color.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  void _goNext() {
    // Limpiar controller de texto si aplica
    _shortAnswerController.clear();
    if (_selectedAnswers.containsKey(_currentQuestionIndex + 1)) {
      _shortAnswerController.text =
          _selectedAnswers[_currentQuestionIndex + 1] ?? '';
    }
    setState(() => _currentQuestionIndex++);
  }

  void _goBack() {
    _shortAnswerController.clear();
    if (_selectedAnswers.containsKey(_currentQuestionIndex - 1)) {
      _shortAnswerController.text =
          _selectedAnswers[_currentQuestionIndex - 1] ?? '';
    }
    setState(() => _currentQuestionIndex--);
  }

  void _confirmFinish() {
    final unanswered =
        widget.questions.length - _selectedAnswers.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.flag, color: Colors.green),
            SizedBox(width: 8),
            Text('Finalizar Examen'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Has respondido ${_selectedAnswers.length} de ${widget.questions.length} preguntas.'),
            if (unanswered > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '$unanswered sin responder',
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text('¿Seguro que quieres finalizar?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Revisar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _finishExam();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishExam({bool timeExpired = false}) async {
    _timer?.cancel();

    final durationSeconds =
        DateTime.now().difference(_startTime).inSeconds;

    // Calcular respuestas correctas
    int correctCount = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      final answer = _selectedAnswers[i];
      if (answer != null && widget.questions[i].isCorrect(answer)) {
        correctCount++;
      }
    }

    final percentage =
        (correctCount / widget.questions.length * 100).round();

    // Guardar resultado
    final authProvider = context.read<AuthProvider>();
    final resultProvider = context.read<ResultProvider>();
    final user = authProvider.currentUser!;

    final result = PracticeResult(
      id: 'exam_${DateTime.now().millisecondsSinceEpoch}',
      studentId: user.id,
      subjectId: widget.subject.id,
      subjectName: widget.subject.name,
      totalQuestions: widget.questions.length,
      correctAnswers: correctCount,
      completedAt: DateTime.now(),
      durationSeconds: durationSeconds,
      sessionType: SessionType.exam,
    );

   await resultProvider.saveResult(result, parentId: user.parentId);
    // Mostrar resultado final con desglose
    _showExamResults(
      result: result,
      percentage: percentage,
      correctCount: correctCount,
      timeExpired: timeExpired,
    );
  }

  void _showExamResults({
    required PracticeResult result,
    required int percentage,
    required int correctCount,
    required bool timeExpired,
  }) {
    final rating = result.rating;
    final color = percentage >= 70 ? Colors.green : Colors.red;
    final minutes = result.durationSeconds ~/ 60;
    final seconds = result.durationSeconds % 60;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Column(
          children: [
            Text(rating.emoji,
                style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 4),
            Text(
              timeExpired ? '¡Tiempo Agotado!' : '¡Examen Completado!',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Porcentaje grande
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              rating.displayName,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: correctCount / widget.questions.length,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),

            // Desglose
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildResultStat(
                  '$correctCount',
                  'Correctas',
                  Colors.green,
                  Icons.check_circle,
                ),
                _buildResultStat(
                  '${widget.questions.length - correctCount}',
                  'Incorrectas',
                  Colors.red,
                  Icons.cancel,
                ),
                _buildResultStat(
                  '${minutes}m ${seconds}s',
                  'Tiempo',
                  Colors.blue,
                  Icons.timer,
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context); // Volver a config
              Navigator.pop(context); // Volver a selección
            },
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: const Text('Ver Resultados'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStat(
      String value, String label, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir del examen?'),
        content:
            const Text('Tu progreso no se guardará si sales ahora.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar examen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (shouldPop == true && mounted) {
      _timer?.cancel();
      Navigator.of(context).pop();
      return false;
    }
    return false;
  }
}