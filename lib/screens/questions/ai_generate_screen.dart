// lib/screens/questions/ai_generate_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/question.dart';
import '../../models/student.dart';
import '../../models/subject.dart';
import '../../providers/auth_provider.dart';
import '../../providers/question_provider.dart';
import '../../services/ai_question_service.dart';
import '../../services/student_service.dart';
import '../../utils/app_theme.dart';

class AIGenerateScreen extends StatefulWidget {
  final Subject subject;

  const AIGenerateScreen({super.key, required this.subject});

  @override
  State<AIGenerateScreen> createState() => _AIGenerateScreenState();
}

class _AIGenerateScreenState extends State<AIGenerateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Flujo A — Por texto (Groq)
  final _topicController = TextEditingController();
  int _questionCount = 10;
  QuestionDifficulty _difficulty = QuestionDifficulty.medium;
  QuestionType _questionType = QuestionType.multipleChoice;

  // ── Flujo B — Por imagen (Gemini)
  File? _selectedImage;
  int _imageQuestionCount = 10;
  QuestionDifficulty _imageDifficulty = QuestionDifficulty.medium;
  String _detectedGrade = 'primaria'; // grado detectado de los estudiantes

  // ── Estado general
  bool _isGenerating = false;
  bool _isLoadingGrade = false;
  List<AIGeneratedQuestion> _generatedQuestions = [];
  String? _errorMessage;
  String? _detectedTopic; // tema detectado por Gemini desde la imagen

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStudentGrade();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  /// Obtiene el grado más común de los estudiantes asignados a esta materia
  Future<void> _loadStudentGrade() async {
    setState(() => _isLoadingGrade = true);
    try {
      final studentService = context.read<StudentService>();
      final students =
          await studentService.getStudentsWithSubject(widget.subject.id);

      if (students.isNotEmpty) {
        // Contar grados y tomar el más frecuente
        final gradeCount = <StudentGrade, int>{};
        for (final s in students) {
          gradeCount[s.grade] = (gradeCount[s.grade] ?? 0) + 1;
        }
        final mostCommon = gradeCount.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;

        setState(() => _detectedGrade = _gradeToSpanish(mostCommon));
      }
    } catch (_) {
      // Si falla, usar primaria por defecto
    } finally {
      setState(() => _isLoadingGrade = false);
    }
  }

  String _gradeToSpanish(StudentGrade grade) {
    switch (grade) {
      case StudentGrade.preescolar:
        return 'preescolar (3-6 años)';
      case StudentGrade.primaria:
        return 'primaria (6-12 años)';
      case StudentGrade.secundaria:
        return 'secundaria (12-15 años)';
      case StudentGrade.preparatoria:
        return 'preparatoria (15-18 años)';
      case StudentGrade.universidad:
        return 'universidad (18+ años)';
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar con IA'),
        backgroundColor: widget.subject.color.color,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: _generatedQuestions.isEmpty
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(icon: Icon(Icons.edit_note), text: 'Por texto'),
                  Tab(icon: Icon(Icons.image), text: 'Por imagen'),
                ],
              )
            : null,
      ),
      body: _generatedQuestions.isNotEmpty
          ? _buildReviewScreen()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTextTab(),
                _buildImageTab(),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB A — Por texto (Groq)
  // ─────────────────────────────────────────────

  Widget _buildTextTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIBadge(
            icon: Icons.bolt,
            label: 'Groq + Llama 3.3 70B',
            subtitle: '~2 segundos de respuesta',
            color: Colors.orange,
          ),
          const SizedBox(height: 20),
          _buildInfoCard(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _topicController,
            decoration: InputDecoration(
              labelText: 'Tema o descripción *',
              hintText:
                  'Ej: Factorización de polinomios, Segunda Guerra Mundial...',
              prefixIcon: const Icon(Icons.topic),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _buildCountSelector(
            value: _questionCount,
            onChanged: (v) => setState(() => _questionCount = v),
          ),
          const SizedBox(height: 16),
          _buildDifficultySelector(
            selected: _difficulty,
            onChanged: (d) => setState(() => _difficulty = d),
          ),
          const SizedBox(height: 16),
          _buildTypeSelector(),
          const SizedBox(height: 24),
          _buildGenerateButton(
            label: 'Generar con Groq',
            icon: Icons.auto_awesome,
            color: Colors.orange,
            onTap: _generateFromText,
          ),
          if (_errorMessage != null) _buildError(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB B — Por imagen (Gemini)
  // ─────────────────────────────────────────────

  Widget _buildImageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIBadge(
            icon: Icons.auto_awesome,
            label: 'Gemini 2.5 Flash',
            subtitle: '~5 segundos · Analiza imágenes',
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(),
          const SizedBox(height: 12),

          // Grado detectado
          _buildGradeIndicator(),
          const SizedBox(height: 16),

          // Selector de imagen
          _buildImagePicker(),
          const SizedBox(height: 16),

          // Cantidad
          _buildCountSelector(
            value: _imageQuestionCount,
            onChanged: (v) => setState(() => _imageQuestionCount = v),
          ),
          const SizedBox(height: 16),

          // Dificultad — nuevo en tab imagen
          _buildDifficultySelector(
            selected: _imageDifficulty,
            onChanged: (d) => setState(() => _imageDifficulty = d),
          ),
          const SizedBox(height: 24),

          // Botón generar
          _buildGenerateButton(
            label: 'Analizar con Gemini',
            icon: Icons.image_search,
            color: Colors.blue,
            onTap: _selectedImage != null ? _generateFromImage : null,
          ),

          if (_errorMessage != null) _buildError(),
        ],
      ),
    );
  }

  Widget _buildGradeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.school, color: Colors.green[700], size: 18),
          const SizedBox(width: 8),
          _isLoadingGrade
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Expanded(
                  child: Text(
                    'Nivel detectado: $_detectedGrade',
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // PANTALLA DE REVISIÓN
  // ─────────────────────────────────────────────

  Widget _buildReviewScreen() {
    final selectedCount =
        _generatedQuestions.where((q) => q.selected).length;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: widget.subject.color.color.withOpacity(0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: widget.subject.color.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_generatedQuestions.length} preguntas generadas',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              if (_detectedTopic != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Tema identificado: $_detectedTopic',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Selecciona las que quieres guardar',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),

        // Lista de preguntas
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _generatedQuestions.length,
            itemBuilder: (context, index) {
              final q = _generatedQuestions[index];
              return _buildQuestionReviewCard(q, index);
            },
          ),
        ),

        // Barra inferior
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _generatedQuestions = [];
                  _detectedTopic = null;
                }),
                child: const Text('← Volver'),
              ),
              const Spacer(),
              Text(
                '$selectedCount seleccionadas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.subject.color.color,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed:
                    selectedCount > 0 && !_isGenerating
                        ? _saveSelectedQuestions
                        : null,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text('Guardar $selectedCount'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.subject.color.color,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionReviewCard(AIGeneratedQuestion q, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => q.selected = !q.selected),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: q.selected,
                onChanged: (v) => setState(() => q.selected = v ?? false),
                activeColor: widget.subject.color.color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.subject.color.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: widget.subject.color.color,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildMiniChip(q.type.displayName, q.type.color),
                        const SizedBox(width: 6),
                        _buildMiniChip(
                            q.difficulty.displayName, q.difficulty.color),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      q.text,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (q.options.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...q.options.asMap().entries.map((entry) {
                        final letter = String.fromCharCode(65 + entry.key);
                        final isCorrect = entry.value == q.correctAnswer;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              Text(
                                '$letter)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isCorrect
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isCorrect
                                      ? Colors.green[700]
                                      : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isCorrect
                                        ? Colors.green[700]
                                        : Colors.grey[700],
                                    fontWeight: isCorrect
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isCorrect)
                                Icon(Icons.check_circle,
                                    size: 14, color: Colors.green[700]),
                            ],
                          ),
                        );
                      }),
                    ],
                    if (q.explanation != null &&
                        q.explanation!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline,
                                size: 14, color: Colors.blue[600]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                q.explanation!,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.blue[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // WIDGETS AUXILIARES
  // ─────────────────────────────────────────────

  Widget _buildAIBadge({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              Text(subtitle,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.subject.color.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(widget.subject.icon.icon, color: widget.subject.color.color),
          const SizedBox(width: 10),
          Text(
            widget.subject.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: widget.subject.color.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountSelector({
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Cantidad de preguntas',
                style: TextStyle(fontWeight: FontWeight.w500)),
            Text('$value preguntas',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.subject.color.color)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 20,
          divisions: 19,
          activeColor: widget.subject.color.color,
          label: value.toString(),
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  Widget _buildDifficultySelector({
    required QuestionDifficulty selected,
    required ValueChanged<QuestionDifficulty> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dificultad',
            style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: QuestionDifficulty.values.map((d) {
            final isSelected = selected == d;
            return ChoiceChip(
              label: Text(d.displayName),
              selected: isSelected,
              onSelected: (_) => onChanged(d),
              selectedColor: d.color.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? d.color : Colors.grey[700],
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo de pregunta',
            style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: QuestionType.values.map((t) {
            final isSelected = _questionType == t;
            return ChoiceChip(
              label: Text(t.displayName),
              selected: isSelected,
              onSelected: (_) => setState(() => _questionType = t),
              selectedColor: widget.subject.color.color.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected
                    ? widget.subject.color.color
                    : Colors.grey[700],
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedImage != null ? Colors.blue : Colors.grey[300]!,
            width: _selectedImage != null ? 2 : 1,
          ),
        ),
        child: _selectedImage != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('Toca para seleccionar imagen',
                      style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text(
                    'Foto de libro, pizarra o examen',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGenerateButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : onTap,
        icon: _isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(_isGenerating ? 'Generando...' : label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[700], fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ACCIONES
  // ─────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Seleccionar de galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _errorMessage = null;
      });
    }
  }

  Future<void> _generateFromText() async {
    if (_topicController.text.trim().isEmpty) {
      setState(
          () => _errorMessage = 'Escribe un tema para generar preguntas');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final questions = await AIQuestionService.generateFromText(
        subjectName: widget.subject.name,
        topic: _topicController.text.trim(),
        count: _questionCount,
        difficulty: _difficulty,
        type: _questionType,
      );

      setState(() {
        _generatedQuestions = questions;
        _isGenerating = false;
      });
    } on AIException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inesperado: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _generateFromImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final questions = await AIQuestionService.generateFromImage(
        imageFile: _selectedImage!,
        subjectName: widget.subject.name,
        count: _imageQuestionCount,
        difficulty: _imageDifficulty,
        gradeLevel: _detectedGrade,
      );

      setState(() {
        _generatedQuestions = questions;
        _isGenerating = false;
      });
    } on AIException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inesperado: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _saveSelectedQuestions() async {
    final selected = _generatedQuestions.where((q) => q.selected).toList();
    if (selected.isEmpty) return;

    setState(() => _isGenerating = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final questionProvider = context.read<QuestionProvider>();
      final createdBy = authProvider.currentUser!.id;

      int savedCount = 0;
      for (final q in selected) {
        final success = await questionProvider.createQuestion(
          subjectId: widget.subject.id,
          createdBy: createdBy,
          text: q.text,
          type: q.type,
          options: q.options,
          correctAnswer: q.correctAnswer,
          explanation: q.explanation,
          topic: q.topic,
          difficulty: q.difficulty,
        );
        if (success) savedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$savedCount preguntas guardadas exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al guardar: $e';
        _isGenerating = false;
      });
    }
  }
}