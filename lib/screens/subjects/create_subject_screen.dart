// lib/screens/subjects/create_subject_screen.dart
// MODIFICADO: Ahora funciona para crear Y editar materias

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subject_provider.dart';
import '../../models/subject.dart';
import '../../utils/app_theme.dart';

class CreateSubjectScreen extends StatefulWidget {
  final Subject? subjectToEdit; // NUEVO: Opcional para modo edición
  
  const CreateSubjectScreen({
    super.key,
    this.subjectToEdit, // NUEVO parámetro
  });

  @override
  State<CreateSubjectScreen> createState() => _CreateSubjectScreenState();
}

class _CreateSubjectScreenState extends State<CreateSubjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  
  SubjectColor _selectedColor = SubjectColor.blue;
  SubjectIcon _selectedIcon = SubjectIcon.book;
  String _selectedDifficulty = 'Medio';
  TimeUnit _selectedTimeUnit = TimeUnit.hours;
  bool _isLoading = false;

  final List<String> _difficulties = ['Fácil', 'Medio', 'Difícil'];

  // NUEVO: Getter para determinar si estamos editando
  bool get isEditing => widget.subjectToEdit != null;

  @override
  void initState() {
    super.initState();
    // NUEVO: Si estamos editando, precargar datos
    if (isEditing) {
      _loadSubjectData();
    }
  }

  // NUEVO: Método para precargar datos en modo edición
  void _loadSubjectData() {
    final subject = widget.subjectToEdit!;
    
    _nameController.text = subject.name;
    _descriptionController.text = subject.description;
    _durationController.text = subject.estimatedDuration?.toString() ?? '';
    
    _selectedColor = subject.color;
    _selectedIcon = subject.icon;
    _selectedDifficulty = subject.difficulty ?? 'Medio';
    _selectedTimeUnit = subject.timeUnit ?? TimeUnit.hours;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // MODIFICADO: Título dinámico
        title: Text(isEditing ? 'Editar Materia' : 'Nueva Materia'),
        actions: [
          Consumer<SubjectProvider>(
            builder: (context, subjectProvider, child) {
              return TextButton(
                onPressed: _isLoading ? null : _saveSubject,
                child: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              _buildAppearanceSection(),
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

  Widget _buildBasicInfoSection() {
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
                  'Información Básica',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Nombre de la materia
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre de la materia *',
                hintText: 'Ej: Matemáticas Básicas',
                prefixIcon: Icon(Icons.subject),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es requerido';
                }
                if (value.trim().length < 3) {
                  return 'El nombre debe tener al menos 3 caracteres';
                }
                if (value.length > 50) {
                  return 'El nombre no puede exceder 50 caracteres';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Descripción
            TextFormField(
              controller: _descriptionController,
              textInputAction: TextInputAction.next,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción *',
                hintText: 'Describe el contenido y objetivos de la materia...',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La descripción es requerida';
                }
                if (value.trim().length < 10) {
                  return 'La descripción debe tener al menos 10 caracteres';
                }
                if (value.length > 200) {
                  return 'La descripción no puede exceder 200 caracteres';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Apariencia',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Selector de color
            Text(
              'Color',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: SubjectColor.values.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey[300]!,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Selector de icono
            Text(
              'Icono',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: SubjectIcon.values.length,
              itemBuilder: (context, index) {
                final icon = SubjectIcon.values[index];
                final isSelected = _selectedIcon == icon;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = icon;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? _selectedColor.color.withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? _selectedColor.color : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      icon.icon,
                      color: isSelected ? _selectedColor.color : Colors.grey[600],
                      size: 24,
                    ),
                  ),
                );
              },
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
                Icon(Icons.settings, color: AppTheme.primaryColor),
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
            
            Row(
              children: [
                // Duración estimada
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Duración estimada',
                      hintText: '50',
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final duration = int.tryParse(value);
                        if (duration == null || duration <= 0) {
                          return 'Ingresa un número válido';
                        }
                        if (_selectedTimeUnit == TimeUnit.hours && duration > 500) {
                          return 'Máximo 500 horas';
                        }
                        if (_selectedTimeUnit == TimeUnit.minutes && duration > 30000) {
                          return 'Máximo 30,000 minutos';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Selector de unidad
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<TimeUnit>(
                    value: _selectedTimeUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unidad',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    items: TimeUnit.values.map((unit) {
                      return DropdownMenuItem(
                        value: unit,
                        child: Text(unit.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedTimeUnit = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Dificultad
            DropdownButtonFormField<String>(
              value: _selectedDifficulty,
              decoration: const InputDecoration(
                labelText: 'Dificultad',
                prefixIcon: Icon(Icons.signal_cellular_alt),
              ),
              items: _difficulties.map((difficulty) {
                return DropdownMenuItem(
                  value: difficulty,
                  child: Text(difficulty),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedDifficulty = value;
                  });
                }
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
        onPressed: _isLoading ? null : _saveSubject,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _selectedColor.color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _selectedIcon.icon,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // MODIFICADO: Texto dinámico del botón
                  Text(
                    isEditing ? 'Actualizar Materia' : 'Crear Materia',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_durationController.text.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_durationController.text}${_selectedTimeUnit.shortName}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  // MODIFICADO: Lógica unificada para crear/editar
  Future<void> _saveSubject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final subjectProvider = context.read<SubjectProvider>();
      
      final currentUser = authProvider.currentUser!;
      final duration = _durationController.text.isNotEmpty 
          ? int.tryParse(_durationController.text)
          : null;

      bool success;
      String action;

      if (isEditing) {
        // MODO EDICIÓN: Actualizar materia existente
        final updatedSubject = widget.subjectToEdit!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          color: _selectedColor,
          icon: _selectedIcon,
          estimatedDuration: duration,
          timeUnit: duration != null ? _selectedTimeUnit : null,
          difficulty: _selectedDifficulty,
          updatedAt: DateTime.now(),
        );

        success = await subjectProvider.updateSubject(
          updatedSubject,
          currentUser.id,
          currentUser.role.toString().split('.').last,
        );
        action = 'actualizada';
      } else {
        // MODO CREACIÓN: Crear nueva materia
        success = await subjectProvider.createSubject(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          createdBy: currentUser.id,
          userRole: currentUser.role.toString().split('.').last,
          color: _selectedColor,
          icon: _selectedIcon,
          estimatedDuration: duration,
          timeUnit: duration != null ? _selectedTimeUnit : null,
          difficulty: _selectedDifficulty,
        );
        action = 'creada';
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _selectedColor.color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _selectedIcon.icon,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Materia "${_nameController.text.trim()}" $action exitosamente' +
                    (duration != null ? ' (${duration}${_selectedTimeUnit.shortName})' : ''),
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
            content: Text('Error al ${isEditing ? "actualizar" : "crear"} materia: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}