// lib/screens/students/student_form_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../models/student.dart';
import '../../utils/app_theme.dart';

class StudentFormScreen extends StatefulWidget {
  final Student? studentToEdit; // Opcional para modo edición
  
  const StudentFormScreen({
    super.key,
    this.studentToEdit,
  });

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  
  StudentGrade _selectedGrade = StudentGrade.primaria;
  StudentAvatar _selectedAvatar = StudentAvatar.student1;
  DateTime? _selectedBirthDate;
  bool _isLoading = false;

  // Getter para determinar si estamos editando
  bool get isEditing => widget.studentToEdit != null;

  @override
  void initState() {
    super.initState();
    // Si estamos editando, precargar datos
    if (isEditing) {
      _loadStudentData();
    }
  }

  // Método para precargar datos en modo edición
  void _loadStudentData() {
    final student = widget.studentToEdit!;
    
    _nameController.text = student.name;
    _emailController.text = student.email;
    _notesController.text = student.notes ?? '';
    
    _selectedGrade = student.grade;
    _selectedAvatar = student.avatar;
    _selectedBirthDate = student.birthDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Estudiante' : 'Nuevo Estudiante'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveStudent,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              _buildAvatarSection(),
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
                Icon(Icons.person_outline, color: AppTheme.parentColor),
                const SizedBox(width: 8),
                Text(
                  'Información Personal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.parentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Nombre completo
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre completo *',
                hintText: 'Ej: María Elena Pérez',
                prefixIcon: Icon(Icons.person),
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
            
            // Email
            TextFormField(
              controller: _emailController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico *',
                hintText: 'estudiante@email.com',
                prefixIcon: Icon(Icons.email),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El email es requerido';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Formato de email inválido';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Fecha de nacimiento
            InkWell(
              onTap: _selectBirthDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha de nacimiento',
                  prefixIcon: Icon(Icons.cake),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _selectedBirthDate != null
                      ? '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}'
                      : 'Seleccionar fecha',
                  style: TextStyle(
                    color: _selectedBirthDate != null ? null : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.face, color: AppTheme.parentColor),
                const SizedBox(width: 8),
                Text(
                  'Avatar y Grado',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.parentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Selector de avatar
            Text('Avatar', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: StudentAvatar.values.length,
              itemBuilder: (context, index) {
                final avatar = StudentAvatar.values[index];
                final isSelected = _selectedAvatar == avatar;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAvatar = avatar),
                  child: Container(
                    decoration: BoxDecoration(
                      color: avatar.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.parentColor : Colors.grey[300]!,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: Icon(
                      avatar.icon,
                      color: isSelected ? AppTheme.parentColor : Colors.grey[600],
                      size: 24,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Selector de grado
            DropdownButtonFormField<StudentGrade>(
              value: _selectedGrade,
              decoration: const InputDecoration(
                labelText: 'Grado escolar',
                prefixIcon: Icon(Icons.school),
              ),
              items: StudentGrade.values.map((grade) {
                return DropdownMenuItem(
                  value: grade,
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: grade.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            grade.shortName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: grade.color,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(grade.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedGrade = value);
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
                Icon(Icons.notes, color: AppTheme.parentColor),
                const SizedBox(width: 8),
                Text(
                  'Información Adicional',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.parentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Notas
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas adicionales',
                hintText: 'Información relevante sobre el estudiante...',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value != null && value.length > 200) {
                  return 'Las notas no pueden exceder 200 caracteres';
                }
                return null;
              },
            ),
            
            if (_selectedBirthDate != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Edad calculada: ${_calculateAge(_selectedBirthDate!)} años',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        onPressed: _isLoading ? null : _saveStudent,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.parentColor,
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
                      color: _selectedAvatar.backgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _selectedAvatar.icon,
                      color: _selectedGrade.color,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Actualizar Estudiante' : 'Crear Estudiante',
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
                      _selectedGrade.shortName,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(now.year - 10),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      helpText: 'Seleccionar fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final studentProvider = context.read<StudentProvider>();
      final currentUser = authProvider.currentUser!;

      bool success;
      String action;

      if (isEditing) {
        // MODO EDICIÓN: Actualizar estudiante existente
        final updatedStudent = widget.studentToEdit!.copyWith(
          name: _nameController.text.trim(),
          email: _emailController.text.trim().toLowerCase(),
          grade: _selectedGrade,
          avatar: _selectedAvatar,
          birthDate: _selectedBirthDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          updatedAt: DateTime.now(),
        );

        success = await studentProvider.updateStudent(updatedStudent, currentUser.id);
        action = 'actualizado';
      } else {
        // MODO CREACIÓN: Crear nuevo estudiante
        success = await studentProvider.createStudent(
          name: _nameController.text.trim(),
          email: _emailController.text.trim().toLowerCase(),
          parentId: currentUser.id,
          grade: _selectedGrade,
          avatar: _selectedAvatar,
          birthDate: _selectedBirthDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        action = 'creado';
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
                    color: _selectedAvatar.backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _selectedAvatar.icon,
                    color: _selectedGrade.color,
                    size: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estudiante "${_nameController.text.trim()}" $action exitosamente',
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
            content: Text('Error al ${isEditing ? "actualizar" : "crear"} estudiante: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}