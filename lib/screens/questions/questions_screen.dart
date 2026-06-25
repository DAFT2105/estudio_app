// lib/screens/questions/questions_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/question_provider.dart';
import '../../providers/subject_provider.dart';
import '../../models/question.dart';
import '../../models/subject.dart';
import '../../utils/app_theme.dart';
import 'ai_generate_screen.dart';
import 'question_form_screen.dart';

class QuestionsScreen extends StatefulWidget {
  final String? subjectId;

  const QuestionsScreen({
    super.key,
    this.subjectId,
  });

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  final _searchController = TextEditingController();
  Subject? _selectedSubject;
  QuestionType? _filterType;
  QuestionDifficulty? _filterDifficulty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final subjectProvider = context.read<SubjectProvider>();
    final questionProvider = context.read<QuestionProvider>();

    final userId = authProvider.currentUser!.id;
    final userRole = authProvider.currentUser!.role.toString().split('.').last;

    await subjectProvider.loadSubjects(userId, userRole);

    if (widget.subjectId != null) {
      _selectedSubject = subjectProvider.getSubjectById(widget.subjectId!);
      await questionProvider.loadQuestionsBySubject(widget.subjectId!);
    } else if (subjectProvider.activeSubjects.isNotEmpty) {
      _selectedSubject = subjectProvider.activeSubjects.first;
      await questionProvider.loadQuestionsBySubject(_selectedSubject!.id);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Banco de Preguntas'),
      actions: [
        Consumer<QuestionProvider>(
          builder: (context, questionProvider, child) {
            if (questionProvider.stats != null) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Chip(
                    label: Text('${questionProvider.stats!.totalQuestions}'),
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    labelStyle: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer2<SubjectProvider, QuestionProvider>(
      builder: (context, subjectProvider, questionProvider, child) {
        if (subjectProvider.activeSubjects.isEmpty) {
          return _buildNoSubjectsState();
        }

        return Column(
          children: [
            _buildSubjectSelector(subjectProvider),
            _buildSearchBar(questionProvider),
            _buildFilters(),
            _buildStatsSection(questionProvider),
            Expanded(
              child: _buildQuestionsList(questionProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoSubjectsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Necesitas crear materias primero',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Las preguntas se organizan por materia',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Ir a Materias'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelector(SubjectProvider subjectProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _selectedSubject?.color.color.withOpacity(0.1) ?? Colors.grey[100]!,
            _selectedSubject?.color.color.withOpacity(0.05) ?? Colors.grey[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedSubject?.color.color.withOpacity(0.3) ??
              Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _selectedSubject?.color.color.withOpacity(0.2) ??
                  Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _selectedSubject?.icon.icon ?? Icons.book,
              color: _selectedSubject?.color.color ?? Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Materia:',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                DropdownButton<Subject>(
                  value: _selectedSubject,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _selectedSubject?.color.color ?? AppTheme.primaryColor,
                  ),
                  items: subjectProvider.activeSubjects.map((subject) {
                    return DropdownMenuItem(
                      value: subject,
                      child: Row(
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
                          Expanded(
                            child: Text(
                              subject.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (subject) async {
                    if (subject != null) {
                      setState(() {
                        _selectedSubject = subject;
                        _filterType = null;
                        _filterDifficulty = null;
                      });
                      final questionProvider = context.read<QuestionProvider>();
                      await questionProvider.loadQuestionsBySubject(subject.id);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(QuestionProvider questionProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar preguntas...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    if (_selectedSubject != null) {
                      questionProvider.clearSearch(_selectedSubject!.id);
                    }
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (query) {
          setState(() {});
          if (query.isNotEmpty && _selectedSubject != null) {
            questionProvider.searchQuestions(query, _selectedSubject!.id);
          } else if (_selectedSubject != null) {
            questionProvider.clearSearch(_selectedSubject!.id);
          }
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<QuestionType?>(
              value: _filterType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Tipo',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                ...QuestionType.values.map((type) => DropdownMenuItem(
                      value: type,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(type.icon, size: 16, color: type.color),
                          const SizedBox(width: 4),
                          // ← FIX: Flexible evita overflow cuando el texto es largo
                          Flexible(
                            child: Text(
                              type.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
              onChanged: (value) async {
                setState(() => _filterType = value);
                if (_selectedSubject != null) {
                  if (value == null) {
                    await context
                        .read<QuestionProvider>()
                        .loadQuestionsBySubject(_selectedSubject!.id);
                  } else {
                    await context
                        .read<QuestionProvider>()
                        .filterByType(_selectedSubject!.id, value);
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<QuestionDifficulty?>(
              value: _filterDifficulty,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Dificultad',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                ...QuestionDifficulty.values.map((diff) => DropdownMenuItem(
                      value: diff,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: diff.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              diff.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
              onChanged: (value) async {
                setState(() => _filterDifficulty = value);
                if (_selectedSubject != null) {
                  if (value == null) {
                    await context
                        .read<QuestionProvider>()
                        .loadQuestionsBySubject(_selectedSubject!.id);
                  } else {
                    await context
                        .read<QuestionProvider>()
                        .filterByDifficulty(_selectedSubject!.id, value);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(QuestionProvider questionProvider) {
    if (questionProvider.stats == null) return const SizedBox.shrink();

    final stats = questionProvider.stats!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _selectedSubject?.color.color.withOpacity(0.1) ??
                AppTheme.primaryColor.withOpacity(0.1),
            _selectedSubject?.color.color.withOpacity(0.05) ??
                AppTheme.secondaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', stats.totalQuestions.toString(), Icons.quiz),
          _buildStatItem('Temas', stats.uniqueTopics.toString(), Icons.category),
          _buildStatItem(
            'Opción M.',
            stats.questionsByType[QuestionType.multipleChoice]?.toString() ?? '0',
            Icons.list,
          ),
          _buildStatItem(
            'V/F',
            stats.questionsByType[QuestionType.trueFalse]?.toString() ?? '0',
            Icons.check_circle_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: _selectedSubject?.color.color ?? AppTheme.primaryColor,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _selectedSubject?.color.color ?? AppTheme.primaryColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuestionsList(QuestionProvider questionProvider) {
    switch (questionProvider.status) {
      case QuestionStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case QuestionStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                questionProvider.errorMessage ?? 'Error desconocido',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadData(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        );

      case QuestionStatus.empty:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                questionProvider.searchQuery.isNotEmpty
                    ? 'No se encontraron preguntas'
                    : 'No hay preguntas en esta materia',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                questionProvider.searchQuery.isNotEmpty
                    ? 'Prueba con otros términos'
                    : 'Crea tu primera pregunta',
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (questionProvider.searchQuery.isEmpty) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _navigateToCreateQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear Primera Pregunta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _selectedSubject?.color.color ?? AppTheme.primaryColor,
                  ),
                ),
              ],
            ],
          ),
        );

      case QuestionStatus.loaded:
        return RefreshIndicator(
          onRefresh: () async => _loadData(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: questionProvider.questions.length,
            itemBuilder: (context, index) {
              final question = questionProvider.questions[index];
              return _buildQuestionCard(question);
            },
          ),
        );
    }
  }

  Widget _buildQuestionCard(Question question) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: question.type.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            question.type.icon,
            color: question.type.color,
            size: 20,
          ),
        ),
        title: Text(
          question.text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildInfoChip(
                question.type.displayName,
                question.type.icon,
                question.type.color,
              ),
              _buildInfoChip(
                question.difficulty.displayName,
                Icons.signal_cellular_alt,
                question.difficulty.color,
              ),
              question.purpose != null
                  ? _buildInfoChip(
                      question.purpose!.displayName,
                      question.purpose!.icon,
                      question.purpose!.color,
                    )
                  : _buildInfoChip(
                      'Ambos modos', Icons.all_inclusive, Colors.grey),
              if (question.topic != null && question.topic!.isNotEmpty)
                _buildInfoChip(question.topic!, Icons.category, Colors.grey),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (question.options.isNotEmpty) ...[
                  const Text(
                    'Opciones:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...question.options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isCorrect = option == question.correctAnswer;
                    final letter = String.fromCharCode(65 + index);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? Colors.green[100]
                                  : Colors.grey[100],
                              border: Border.all(
                                color: isCorrect
                                    ? Colors.green
                                    : Colors.grey[300]!,
                                width: isCorrect ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                letter,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCorrect
                                      ? Colors.green[800]
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                color: isCorrect
                                    ? Colors.green[800]
                                    : Colors.grey[800],
                                fontWeight: isCorrect
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isCorrect)
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 18),
                        ],
                      ),
                    );
                  }),
                ],
                if (question.explanation != null &&
                    question.explanation!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: Colors.blue[600], size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            question.explanation!,
                            style: TextStyle(
                                color: Colors.blue[800], fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _navigateToEditQuestion(question),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Editar'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _confirmDeleteQuestion(question),
                      icon: const Icon(Icons.delete, size: 16,
                          color: Colors.red),
                      label: const Text('Eliminar',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

Widget? _buildFloatingActionButton() {
  if (_selectedSubject == null) return null;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FloatingActionButton.extended(
        heroTag: 'ai',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AIGenerateScreen(subject: _selectedSubject!),
          ),
        ).then((_) => _loadData()),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Generar con IA'),
        backgroundColor: Colors.orange,
      ),
      const SizedBox(height: 12),
      FloatingActionButton(
        heroTag: 'add',
        onPressed: _navigateToCreateQuestion,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    ],
  );
}

  void _navigateToCreateQuestion() {
    if (_selectedSubject == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            QuestionFormScreen(subjectId: _selectedSubject!.id),
      ),
    ).then((_) => _loadData());
  }

  void _navigateToEditQuestion(Question question) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionFormScreen(
          subjectId: question.subjectId,
          questionToEdit: question,
        ),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _confirmDeleteQuestion(Question question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Pregunta'),
        content: Text(
            '¿Estás seguro de eliminar "${question.text}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final questionProvider = context.read<QuestionProvider>();
      final success = await questionProvider.deleteQuestion(question.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Pregunta eliminada exitosamente'
                : 'Error al eliminar la pregunta'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}