// lib/screens/questions/question_sets_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/question_provider.dart';
import '../../providers/question_set_provider.dart';
import '../../models/question.dart';
import '../../models/question_set.dart';
import '../../models/subject.dart';
import '../../utils/app_theme.dart';

/// Lista los Exámenes/Prácticas armados a mano (QuestionSet) de una materia.
/// El padre puede ver el detalle (preguntas incluidas) y eliminarlos.
class QuestionSetsScreen extends StatefulWidget {
  final Subject subject;

  const QuestionSetsScreen({super.key, required this.subject});

  @override
  State<QuestionSetsScreen> createState() => _QuestionSetsScreenState();
}

class _QuestionSetsScreenState extends State<QuestionSetsScreen> {
  QuestionPurpose? _filterPurpose;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final setProvider = context.read<QuestionSetProvider>();
    final questionProvider = context.read<QuestionProvider>();
    await Future.wait([
      setProvider.loadSetsBySubject(widget.subject.id),
      questionProvider.loadQuestionsBySubject(widget.subject.id),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Armados — ${widget.subject.name}'),
        backgroundColor: widget.subject.color.color,
      ),
      body: Column(
        children: [
          _buildFilterRow(),
          Expanded(
            child: Consumer<QuestionSetProvider>(
              builder: (context, setProvider, child) {
                if (setProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sets = _filterPurpose == null
                    ? setProvider.sets
                    : setProvider.sets
                        .where((s) => s.purpose == _filterPurpose)
                        .toList();

                if (sets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 56, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'Aún no has armado ningún examen o práctica fijo.\n'
                            'Ve al Banco de Preguntas, filtra por modo y selecciona las preguntas que quieras agrupar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sets.length,
                    itemBuilder: (context, index) => _buildSetCard(sets[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildChip(null, 'Todos'),
          const SizedBox(width: 8),
          ...QuestionPurpose.values.map((p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildChip(p, p.displayName, icon: p.icon),
              )),
        ],
      ),
    );
  }

  Widget _buildChip(QuestionPurpose? purpose, String label, {IconData? icon}) {
    final isSelected = _filterPurpose == purpose;
    final color = purpose?.color ?? AppTheme.primaryColor;
    return ChoiceChip(
      label: Text(label),
      avatar: icon != null
          ? Icon(icon, size: 16, color: isSelected ? color : Colors.grey[600])
          : null,
      showCheckmark: false,
      selected: isSelected,
      onSelected: (_) => setState(() => _filterPurpose = purpose),
      selectedColor: color.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildSetCard(QuestionSet set) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: set.purpose.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(set.purpose.icon, color: set.purpose.color, size: 20),
        ),
        title: Text(set.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            children: [
              _buildMiniChip(set.purpose.displayName, set.purpose.color),
              _buildMiniChip('${set.questionCount} preguntas', Colors.grey[600]!),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(set),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (set.description != null && set.description!.isNotEmpty) ...[
                  Text(set.description!, style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 12),
                ],
                Consumer<QuestionProvider>(
                  builder: (context, questionProvider, child) {
                    final setProvider = context.read<QuestionSetProvider>();
                    final questions = setProvider.resolveQuestions(
                      set,
                      questionProvider.questions,
                    );

                    if (questions.isEmpty) {
                      return Text(
                        'No se pudieron cargar las preguntas (puede que alguna haya sido eliminada).',
                        style: TextStyle(color: Colors.orange[700], fontSize: 12),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: questions
                          .asMap()
                          .entries
                          .map((entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '${entry.key + 1}. ${entry.value.text}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Future<void> _confirmDelete(QuestionSet set) async {
    final authProvider = context.read<AuthProvider>();
    final setProvider = context.read<QuestionSetProvider>();
    final canEdit = setProvider.canEditSet(
      set,
      authProvider.currentUser!.id,
      authProvider.currentUser!.role.toString().split('.').last,
    );

    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permiso para eliminar este grupo')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text('¿Eliminar "${set.title}"? Esto no afecta a las preguntas individuales, solo este grupo armado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await setProvider.deleteSet(set.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Grupo eliminado' : 'Error al eliminar'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}