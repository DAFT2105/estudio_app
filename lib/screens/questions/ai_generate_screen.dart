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
  File? _pendingCameraPhoto; // foto recién tomada, esperando "Aceptar" o "Tomar otra"
  int _imageQuestionCount = 10;
  QuestionDifficulty _imageDifficulty = QuestionDifficulty.medium;
  String _detectedGrade = 'primaria'; // grado detectado de los estudiantes

  // ── Estado general
  bool _isGenerating = false;
  bool _isLoadingGrade = false;
  List<AIGeneratedQuestion> _generatedQuestions = [];
  String? _errorMessage;
  String? _detectedTopic; // tema detectado por Gemini desde la imagen
  QuestionPurpose _purpose = QuestionPurpose.practice; // modo del lote a guardar

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
        // Contar combinaciones de (grado, nivel) — no solo el grado — y
        // tomar la más frecuente, para poder ser específicos con la IA
        // (ej: "primaria, 3er grado" en vez de solo "primaria").
        final counts = <String, int>{};
        final sample = <String, Student>{};
        for (final s in students) {
          final key = '${s.grade.toString().split('.').last}-${s.gradeLevel ?? 0}';
          counts[key] = (counts[key] ?? 0) + 1;
          sample[key] = s;
        }
        final mostCommonKey =
            counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        final mostCommonStudent = sample[mostCommonKey]!;

        setState(() => _detectedGrade = _gradeToSpanish(
            mostCommonStudent.grade, mostCommonStudent.gradeLevel));
      }
    } catch (_) {
      // Si falla, usar primaria por defecto
    } finally {
      setState(() => _isLoadingGrade = false);
    }
  }

  String _gradeToSpanish(StudentGrade grade, int? gradeLevel) {
    final levelSuffix = (grade.hasNumericLevel && gradeLevel != null)
        ? ', $gradeLevel° grado'
        : '';
    switch (grade) {
      case StudentGrade.preescolar:
        return 'preescolar (3-6 años)$levelSuffix';
      case StudentGrade.primaria:
        return 'primaria (6-12 años)$levelSuffix';
      case StudentGrade.secundaria:
        return 'secundaria (12-15 años)$levelSuffix';
      case StudentGrade.preparatoria:
        return 'preparatoria (15-18 años)$levelSuffix';
      case StudentGrade.universidad:
        return 'universidad (18+ años)$levelSuffix';
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Solo bloqueamos el back si hay preguntas generadas que aún no
      // se guardaron — después de guardar, _saveSelectedQuestions ya
      // hace su propio Navigator.pop(), así que no interfiere.
      canPop: _generatedQuestions.isEmpty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldLeave = await _confirmDiscardDialog(
          title: 'Regresar al lobby sin guardar los cambios',
          confirmLabel: 'Regresar al lobby',
        );
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
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
      ),
    );
  }

  Future<bool> _confirmDiscardDialog({String? title, String? confirmLabel}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? '¿Salir sin guardar?'),
        content: Text(
          'Tienes ${_generatedQuestions.length} pregunta${_generatedQuestions.length == 1 ? '' : 's'} generada${_generatedQuestions.length == 1 ? '' : 's'} sin guardar. '
          'Si continúas, se perderán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel ?? 'Salir sin guardar'),
          ),
        ],
      ),
    );
    return result ?? false;
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
              const SizedBox(height: 12),
              const Text('¿Para qué modo son estas preguntas?',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: QuestionPurpose.values.map((p) {
                  final isSelected = _purpose == p;
                  return ChoiceChip(
                    label: Text(p.displayName),
                    avatar: Icon(p.icon,
                        size: 16,
                        color: isSelected ? p.color : Colors.grey[600]),
                    showCheckmark: false,
                    selected: isSelected,
                    onSelected: (_) => setState(() => _purpose = p),
                    selectedColor: p.color.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? p.color : Colors.grey[700],
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
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
                onPressed: () async {
                  final shouldDiscard = await _confirmDiscardDialog();
                  if (shouldDiscard && mounted) {
                    setState(() {
                      _generatedQuestions = [];
                      _detectedTopic = null;
                    });
                  }
                },
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
    // Estado 1: ya hay una imagen aceptada (de cámara o galería) — preview final
    if (_selectedImage != null) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue, width: 2),
        ),
        child: Stack(
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
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Estado 2: foto recién tomada con la cámara, esperando confirmación
    if (_pendingCameraPhoto != null) {
      return Column(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _pendingCameraPhoto!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _retakePhoto,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tomar otra'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _acceptPhoto,
                  icon: const Icon(Icons.check),
                  label: const Text('Aceptar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Estado 3: nada elegido aún — dos opciones lado a lado
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: _pickFromGallery,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text('Toca para seleccionar imagen',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    'Foto de libro, pizarra o examen',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _takePhoto,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 36, color: AppTheme.primaryColor),
                  const SizedBox(height: 10),
                  Text('Tomar foto',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ],
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

  /// Galería — comportamiento de siempre, sin paso de confirmación
  /// (la propia galería ya te deja ver/elegir la foto antes de confirmar).
  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
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

  /// Cámara — abre directo, sin menú intermedio. La foto resultante queda
  /// "pendiente" hasta que el usuario la acepte o decida tomar otra.
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (picked != null) {
      setState(() {
        _pendingCameraPhoto = File(picked.path);
        _errorMessage = null;
      });
    }
  }

  void _retakePhoto() {
    setState(() => _pendingCameraPhoto = null);
    _takePhoto();
  }

  void _acceptPhoto() {
    setState(() {
      _selectedImage = _pendingCameraPhoto;
      _pendingCameraPhoto = null;
    });
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
      final result = await AIQuestionService.generateFromText(
        subjectName: widget.subject.name,
        topic: _topicController.text.trim(),
        count: _questionCount,
        difficulty: _difficulty,
        type: _questionType,
        area: widget.subject.area,
      );

      setState(() {
        _generatedQuestions = result.questions;
        _isGenerating = false;
      });
      _showValidationFeedback(result.corrected, result.discarded);
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
      final result = await AIQuestionService.generateFromImage(
        imageFile: _selectedImage!,
        subjectName: widget.subject.name,
        count: _imageQuestionCount,
        difficulty: _imageDifficulty,
        gradeLevel: _detectedGrade,
        area: widget.subject.area,
      );

      setState(() {
        _generatedQuestions = result.questions;
        _isGenerating = false;
      });
      _showValidationFeedback(result.corrected, result.discarded);
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

  /// Muestra un aviso si la app tuvo que corregir o descartar preguntas
  /// por inconsistencias detectadas entre el cálculo de la IA y la
  /// respuesta que marcó como correcta.
  void _showValidationFeedback(int corrected, int discarded) {
    if (corrected == 0 && discarded == 0) return;

    final parts = <String>[];
    if (corrected > 0) {
      parts.add(
          '$corrected pregunta${corrected == 1 ? '' : 's'} corregida${corrected == 1 ? '' : 's'} automáticamente');
    }
    if (discarded > 0) {
      parts.add(
          '$discarded descartada${discarded == 1 ? '' : 's'} por inconsistencias');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Revisión automática: ${parts.join(' y ')}. Aun así, revisa las preguntas antes de guardar.'),
        backgroundColor: Colors.orange[700],
        duration: const Duration(seconds: 5),
      ),
    );
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
          purpose: _purpose,
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