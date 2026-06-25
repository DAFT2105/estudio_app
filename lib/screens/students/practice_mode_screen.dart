// lib/screens/student/practice_mode_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/subject.dart';
import '../../models/question.dart';
import '../../models/practice_result.dart';
import '../../providers/auth_provider.dart';
import '../../providers/result_provider.dart';
import '../../utils/app_theme.dart';

class PracticeModeScreen extends StatefulWidget {
  final Subject subject;
  final List<Question> questions;

  const PracticeModeScreen({
    super.key,
    required this.subject,
    required this.questions,
  });

  @override
  State<PracticeModeScreen> createState() => _PracticeModeScreenState();
}

class _PracticeModeScreenState extends State<PracticeModeScreen> {
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  bool _isAnswerChecked = false;
  bool _isCorrect = false;
  int _correctAnswers = 0;
  late DateTime _startTime; // Para calcular duración
  final TextEditingController _shortAnswerController = TextEditingController();

  Question get _currentQuestion => widget.questions[_currentQuestionIndex];
  bool get _isLastQuestion =>
      _currentQuestionIndex == widget.questions.length - 1;
  double get _progress =>
      (_currentQuestionIndex + 1) / widget.questions.length;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  @override
  void dispose() {
    _shortAnswerController.dispose();
    super.dispose();
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
            Expanded(
              child: _isAnswerChecked
                  ? _buildAnswerFeedback()
                  : _buildQuestionView(),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(widget.subject.name),
      backgroundColor: widget.subject.color.color,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          _onWillPop();
        },
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              '${_currentQuestionIndex + 1}/${widget.questions.length}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return LinearProgressIndicator(
      value: _progress,
      backgroundColor: Colors.grey[200],
      valueColor:
          AlwaysStoppedAnimation<Color>(widget.subject.color.color),
      minHeight: 6,
    );
  }

  Widget _buildQuestionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildQuestionCard(),
          const SizedBox(height: 24),
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
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        _currentQuestion.type.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_currentQuestion.type.icon,
                          size: 14,
                          color: _currentQuestion.type.color),
                      const SizedBox(width: 4),
                      Text(
                        _currentQuestion.type.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: _currentQuestion.type.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _currentQuestion.difficulty.color
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart,
                          size: 14,
                          color: _currentQuestion.difficulty.color),
                      const SizedBox(width: 4),
                      Text(
                        _currentQuestion.difficulty.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: _currentQuestion.difficulty.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
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
              enabled: !_isAnswerChecked,
              decoration: const InputDecoration(
                hintText: 'Tu respuesta aquí...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _selectedAnswer = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(String option, String prefix) {
    final isSelected = _selectedAnswer == option;
    final color = widget.subject.color.color;

    return InkWell(
      onTap: () => setState(() => _selectedAnswer = option),
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

  Widget _buildAnswerFeedback() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Resultado visual
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _isCorrect
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              border: Border.all(
                color: _isCorrect ? Colors.green : Colors.red,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _isCorrect ? Icons.check_circle : Icons.cancel,
                  size: 56,
                  color: _isCorrect ? Colors.green : Colors.red,
                ),
                const SizedBox(height: 12),
                Text(
                  _isCorrect ? '¡Correcto!' : 'Incorrecto',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _isCorrect ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Respuesta correcta (si falló)
          if (!_isCorrect)
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Respuesta correcta:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                          Text(_currentQuestion.correctAnswer),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Explicación
          if (_currentQuestion.explanation != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Explicación',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[600],
                              )),
                          const SizedBox(height: 4),
                          Text(_currentQuestion.explanation!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _selectedAnswer == null && !_isAnswerChecked
              ? null
              : _handleButtonPress,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.subject.color.color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_isAnswerChecked
                  ? (_isLastQuestion ? Icons.flag : Icons.arrow_forward)
                  : Icons.check_circle_outline),
              const SizedBox(width: 8),
              Text(
                _isAnswerChecked
                    ? (_isLastQuestion
                        ? 'Ver Resultados'
                        : 'Siguiente Pregunta')
                    : 'Verificar Respuesta',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleButtonPress() {
    if (!_isAnswerChecked) {
      // Verificar respuesta
      final correct = _currentQuestion.isCorrect(_selectedAnswer!);
      setState(() {
        _isAnswerChecked = true;
        _isCorrect = correct;
        if (correct) _correctAnswers++;
      });
    } else {
      // Avanzar
      if (_isLastQuestion) {
        _showResults();
      } else {
        setState(() {
          _currentQuestionIndex++;
          _selectedAnswer = null;
          _isAnswerChecked = false;
          _isCorrect = false;
          _shortAnswerController.clear();
        });
      }
    }
  }

  /// Mostrar resultados finales y guardar en historial
  Future<void> _showResults() async {
    final durationSeconds =
        DateTime.now().difference(_startTime).inSeconds;
    final percentage =
        (_correctAnswers / widget.questions.length * 100).round();

    // Guardar resultado en el historial
    final authProvider = context.read<AuthProvider>();
    final resultProvider = context.read<ResultProvider>();
    final user = authProvider.currentUser!;

    final result = PracticeResult(
      id: 'result_${DateTime.now().millisecondsSinceEpoch}',
      studentId: user.id,
      subjectId: widget.subject.id,
      subjectName: widget.subject.name,
      totalQuestions: widget.questions.length,
      correctAnswers: _correctAnswers,
      completedAt: DateTime.now(),
      durationSeconds: durationSeconds,
      sessionType: SessionType.practice,
    );

    await resultProvider.saveResult(result, parentId: user.parentId);;

    if (!mounted) return;

    final rating = result.rating;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(rating.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            const Text('¡Práctica Completada!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: widget.subject.color.color,
              ),
            ),
            Text(
              rating.displayName,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '$_correctAnswers de ${widget.questions.length} correctas',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _correctAnswers / widget.questions.length,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                  widget.subject.color.color),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context); // Volver a configuración
            },
            child: const Text('Nueva Práctica'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context); // Volver a configuración
              Navigator.pop(context); // Volver a selección
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.subject.color.color,
            ),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir de la práctica?'),
        content: const Text('Tu progreso no se guardará.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (shouldPop == true && mounted) {
      Navigator.of(context).pop();
      return false;
    }
    return false;
  }
}