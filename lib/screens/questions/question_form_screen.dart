// lib/screens/questions/question_form_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/question_provider.dart';
import '../../providers/subject_provider.dart';
import '../../models/question.dart';
import '../../models/subject.dart';
import '../../utils/app_theme.dart';

class QuestionFormScreen extends StatefulWidget {
  final Question? questionToEdit;
  final String? subjectId; // Materia preseleccionada
  
  const QuestionFormScreen({
    super.key,
    this.questionToEdit,
    this.subjectId,
  });

  @override
  State<QuestionFormScreen> createState() => _QuestionFormScreenState();
}

class _QuestionFormScreenState extends State<QuestionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _explanationController = TextEditingController();
  final _topicController = TextEditingController();
  
  // Controladores para opciones
  final List<TextEditingController> _optionControllers = [];
  
  Subject? _selectedSubject;
  QuestionType _selectedType = QuestionType.multipleChoice;
  QuestionDifficulty _selectedDifficulty = QuestionDifficulty.medium;
  int _correctOptionIndex = 0;
  String _correctAnswer = '';
  bool _isLoading = false;

  bool get isEditing => widget.questionToEdit != null;

  @override
  void initState() {
    super.initState();
    
    // Inicializar opciones para opción múltiple
    for (int i = 0; i < 4; i++) {
      _optionControllers.add(TextEditingController());
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final subjectProvider = context.read<SubjectProvider>();
    
    if (subjectProvider.activeSubjects.isEmpty) {
      final authProvider = context.read<AuthProvider>();
      await subjectProvider.loadSubjects(
        authProvider.currentUser!.id,
        authProvider.currentUser!.role.toString().split('.').last,
      );
    }

    if (isEditing) {
      _loadQuestionData();
    } else if (widget.subjectId != null) {
      _selectedSubject = subjectProvider.getSubjectById(widget.subjectId!);
    } else if (subjectProvider.activeSubjects.isNotEmpty) {
      _selectedSubject = subjectProvider.activeSubjects.first;
    }
    
    setState(() {});
  }

  void _loadQuestionData() {
    final question = widget.questionToEdit!;
    final subjectProvider = context.read<SubjectProvider>();
    
    _textController.text = question.text;
    _explanationController.text = question.explanation ?? '';
    _topicController.text = question.topic ?? '';
    
    _selectedType = question.type;
    _selectedDifficulty = question.difficulty;
    _selectedSubject = subjectProvider.getSubjectById(question.subjectId);
    
    // Cargar opciones según tipo
    if (question.type == QuestionType.multipleChoice) {
      for (int i = 0; i < question.options.length && i < _optionControllers.length; i++) {
        _optionControllers[i].text = question.options[i];
      }
      _correctOptionIndex = question.options.indexOf(question.correctAnswer);
    } else {
      _correctAnswer = question.correctAnswer;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _explanationController.dispose();
    _topicController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Pregunta' : 'Nueva Pregunta'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveQuestion,
            child: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
      body: _selectedSubject == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubjectSelector(),
                    const SizedBox(height: 24),
                    _buildQuestionTypeSelector(),
                    const SizedBox(height: 24),
                    _buildQuestionTextSection(),
                    const SizedBox(height: 24),
                    _buildAnswerSection(),
                    const SizedBox(height: 24),
                    _buildDetailsSection(),
                    const SizedBox(height: 32),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

Widget _buildSubjectSelector() {
  return Consumer<SubjectProvider>(
    builder: (context, subjectProvider, child) {
      if (subjectProvider.activeSubjects.isEmpty) {
        return const SizedBox.shrink();
      }

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.book, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Materia',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Subject>(
                value: _selectedSubject,
                decoration: InputDecoration(
                  labelText: 'Selecciona la materia',
                  prefixIcon: Icon(
                    _selectedSubject?.icon.icon ?? Icons.subject,
                    color: _selectedSubject?.color.color,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: subjectProvider.activeSubjects.map((subject) {
                  return DropdownMenuItem(
                    value: subject,
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // CAMBIADO
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: subject.color.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            subject.icon.icon,
                            color: subject.color.color,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // CAMBIADO: Sin Expanded, con constrains
                        Flexible(
                          child: Text(
                            subject.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (subject) {
                  setState(() => _selectedSubject = subject);
                },
                validator: (value) {
                  if (value == null) {
                    return 'Debes seleccionar una materia';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildQuestionTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Tipo de Pregunta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...QuestionType.values.map((type) {
              return RadioListTile<QuestionType>(
                value: type,
                groupValue: _selectedType,
                title: Row(
                  children: [
                    Icon(type.icon, color: type.color, size: 20),
                    const SizedBox(width: 8),
                    Text(type.displayName),
                  ],
                ),
                activeColor: type.color,
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                    if (value == QuestionType.trueFalse) {
                      _correctAnswer = 'Verdadero';
                    }
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionTextSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.question_answer, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Pregunta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _textController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Texto de la pregunta *',
                hintText: '¿Cuál es la capital de Francia?',
                prefixIcon: Icon(Icons.help_outline),
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El texto de la pregunta es requerido';
                }
                if (value.trim().length < 10) {
                  return 'La pregunta debe tener al menos 10 caracteres';
                }
                if (value.length > 500) {
                  return 'La pregunta no puede exceder 500 caracteres';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerSection() {
    switch (_selectedType) {
      case QuestionType.multipleChoice:
        return _buildMultipleChoiceOptions();
      case QuestionType.trueFalse:
        return _buildTrueFalseOptions();
      case QuestionType.shortAnswer:
        return _buildShortAnswerField();
    }
  }

Widget _buildMultipleChoiceOptions() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list, color: QuestionType.multipleChoice.color),
              const SizedBox(width: 8),
              Text(
                'Opciones de Respuesta',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: QuestionType.multipleChoice.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Marca la opción correcta',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 16),
          
          for (int index = 0; index < _optionControllers.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Fila superior: Radio + Letra + Label
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<int>(
                        value: index,
                        groupValue: _correctOptionIndex,
                        onChanged: (value) {
                          setState(() => _correctOptionIndex = value!);
                        },
                        activeColor: Colors.green,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _correctOptionIndex == index 
                              ? Colors.green[100] 
                              : Colors.grey[100],
                          border: Border.all(
                            color: _correctOptionIndex == index 
                                ? Colors.green 
                                : Colors.grey[300]!,
                            width: _correctOptionIndex == index ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _correctOptionIndex == index 
                                  ? Colors.green[700] 
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Opción ${String.fromCharCode(65 + index)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Campo de texto debajo
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: TextFormField(
                      controller: _optionControllers[index],
                      decoration: InputDecoration(
                        hintText: 'Escribe la opción...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        filled: _correctOptionIndex == index,
                        fillColor: _correctOptionIndex == index 
                            ? Colors.green[50] 
                            : null,
                      ),
                      validator: (value) {
                        if (index < 2 && (value == null || value.trim().isEmpty)) {
                          return 'Mínimo 2 opciones requeridas';
                        }
                        return null;
                      },
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

  Widget _buildTrueFalseOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: QuestionType.trueFalse.color),
                const SizedBox(width: 8),
                Text(
                  'Respuesta Correcta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: QuestionType.trueFalse.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RadioListTile<String>(
              value: 'Verdadero',
              groupValue: _correctAnswer,
              title: const Text('Verdadero'),
              activeColor: Colors.green,
              onChanged: (value) {
                setState(() => _correctAnswer = value!);
              },
            ),
            RadioListTile<String>(
              value: 'Falso',
              groupValue: _correctAnswer,
              title: const Text('Falso'),
              activeColor: Colors.red,
              onChanged: (value) {
                setState(() => _correctAnswer = value!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortAnswerField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: QuestionType.shortAnswer.color),
                const SizedBox(width: 8),
                Text(
                  'Respuesta Correcta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: QuestionType.shortAnswer.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _correctAnswer,
              decoration: const InputDecoration(
                labelText: 'Respuesta esperada *',
                hintText: 'París',
                prefixIcon: Icon(Icons.check),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _correctAnswer = value,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Debes especificar la respuesta correcta';
                }
                if (value.length > 100) {
                  return 'La respuesta no puede exceder 100 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Nota: La comparación no distingue mayúsculas/minúsculas',
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Detalles Adicionales',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Dificultad
            DropdownButtonFormField<QuestionDifficulty>(
              value: _selectedDifficulty,
              decoration: const InputDecoration(
                labelText: 'Dificultad',
                prefixIcon: Icon(Icons.signal_cellular_alt),
                border: OutlineInputBorder(),
              ),
              items: QuestionDifficulty.values.map((difficulty) {
                return DropdownMenuItem(
                  value: difficulty,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: difficulty.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(difficulty.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedDifficulty = value!);
              },
            ),
            
            const SizedBox(height: 16),
            
            // Tema
            TextFormField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Tema / Categoría',
                hintText: 'Ej: Capitales de Europa',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value != null && value.length > 100) {
                  return 'El tema no puede exceder 100 caracteres';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Explicación
            TextFormField(
              controller: _explanationController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Explicación (opcional)',
                hintText: 'Explica por qué esta es la respuesta correcta...',
                prefixIcon: Icon(Icons.lightbulb_outline),
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value != null && value.length > 500) {
                  return 'La explicación no puede exceder 500 caracteres';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveQuestion,
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedSubject?.color.color ?? AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_selectedType.icon),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Actualizar Pregunta' : 'Crear Pregunta',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _selectedDifficulty.displayName,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final questionProvider = context.read<QuestionProvider>();
      
      // Preparar opciones y respuesta según tipo
      List<String> options = [];
      String correctAnswer = '';
      
      if (_selectedType == QuestionType.multipleChoice) {
        options = _optionControllers
            .map((c) => c.text.trim())
            .where((text) => text.isNotEmpty)
            .toList();
        
        if (options.length < 2) {
          throw Exception('Debes proporcionar al menos 2 opciones');
        }
        
        correctAnswer = options[_correctOptionIndex];
      } else if (_selectedType == QuestionType.trueFalse) {
        options = ['Verdadero', 'Falso'];
        correctAnswer = _correctAnswer;
      } else {
        correctAnswer = _correctAnswer.trim();
      }

      bool success;
      String action;

      if (isEditing) {
        final updatedQuestion = widget.questionToEdit!.copyWith(
          subjectId: _selectedSubject!.id,
          text: _textController.text.trim(),
          type: _selectedType,
          options: options,
          correctAnswer: correctAnswer,
          explanation: _explanationController.text.trim().isEmpty 
              ? null 
              : _explanationController.text.trim(),
          topic: _topicController.text.trim().isEmpty 
              ? null 
              : _topicController.text.trim(),
          difficulty: _selectedDifficulty,
          updatedAt: DateTime.now(),
        );

        success = await questionProvider.updateQuestion(updatedQuestion);
        action = 'actualizada';
      } else {
        success = await questionProvider.createQuestion(
          subjectId: _selectedSubject!.id,
          createdBy: authProvider.currentUser!.id,
          text: _textController.text.trim(),
          type: _selectedType,
          options: options,
          correctAnswer: correctAnswer,
          explanation: _explanationController.text.trim().isEmpty 
              ? null 
              : _explanationController.text.trim(),
          topic: _topicController.text.trim().isEmpty 
              ? null 
              : _topicController.text.trim(),
          difficulty: _selectedDifficulty,
        );
        action = 'creada';
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(_selectedType.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pregunta $action exitosamente en ${_selectedSubject!.name}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}