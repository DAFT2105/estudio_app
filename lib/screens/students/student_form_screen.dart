// lib/screens/students/student_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
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
    
    _nombresController.text = student.nombres;
    _apellidosController.text = student.apellidos;
    _emailController.text = student.email ?? '';
    _notesController.text = student.notes ?? '';
    
    _selectedGrade = student.grade;
    _selectedAvatar = student.avatar;
    _selectedBirthDate = student.birthDate;
  }

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
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

            // Nombres
            TextFormField(
              controller: _nombresController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombres *',
                hintText: 'Ej: María Elena',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Los nombres son requeridos';
                }
                if (value.trim().length < 2) {
                  return 'Debe tener al menos 2 caracteres';
                }
                if (value.length > 50) {
                  return 'No puede exceder 50 caracteres';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Apellidos (campo único — la primera palabra se usa como
            // "primer apellido" para generar el usuario de acceso)
            TextFormField(
              controller: _apellidosController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Apellidos *',
                hintText: 'Ej: Pérez García',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Los apellidos son requeridos';
                }
                if (value.trim().length < 2) {
                  return 'Debe tener al menos 2 caracteres';
                }
                if (value.length > 50) {
                  return 'No puede exceder 50 caracteres';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Email — OCULTO TEMPORALMENTE (Fase 5.3.1)
            // El estudiante ya no necesita correo propio: ingresa con su
            // `username` generado automáticamente. Se deja el código listo
            // para reactivar cuando se integre el correo institucional de
            // colegios a futuro — solo hay que descomentar este bloque.
            // ────────────────────────────────────────────────────────────
            // TextFormField(
            //   controller: _emailController,
            //   textInputAction: TextInputAction.next,
            //   keyboardType: TextInputType.emailAddress,
            //   decoration: const InputDecoration(
            //     labelText: 'Correo electrónico (opcional)',
            //     hintText: 'Déjalo vacío si el estudiante no tiene uno',
            //     prefixIcon: Icon(Icons.email_outlined),
            //   ),
            //   validator: (value) {
            //     if (value == null || value.trim().isEmpty) {
            //       return null; // opcional
            //     }
            //     if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            //       return 'Formato de email inválido';
            //     }
            //     return null;
            //   },
            // ),
            // Padding(
            //   padding: const EdgeInsets.only(top: 6, left: 4),
            //   child: Text(
            //     'El estudiante ingresará con un usuario generado automáticamente, '
            //     'no necesita correo propio.',
            //     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            //   ),
            // ),

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

      final nombres = _nombresController.text.trim();
      final apellidos = _apellidosController.text.trim();
      final email = _emailController.text.trim();

      if (isEditing) {
        // MODO EDICIÓN: Actualizar estudiante existente
        final updatedStudent = widget.studentToEdit!.copyWith(
          nombres: nombres,
          apellidos: apellidos,
          email: email.isEmpty ? null : email.toLowerCase(),
          grade: _selectedGrade,
          avatar: _selectedAvatar,
          birthDate: _selectedBirthDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          updatedAt: DateTime.now(),
        );

        final success = await studentProvider.updateStudent(updatedStudent, currentUser.id);

        if (success && mounted) {
          _showSnackBar('Estudiante "$nombres $apellidos" actualizado exitosamente');
          Navigator.pop(context);
        } else if (mounted) {
          _showErrorSnackBar(
              studentProvider.errorMessage ?? 'Error al actualizar estudiante');
        }
      } else {
        // MODO CREACIÓN: Crear nuevo estudiante
        final credentials = await studentProvider.createStudent(
          nombres: nombres,
          apellidos: apellidos,
          email: email.isEmpty ? null : email.toLowerCase(),
          parentId: currentUser.id,
          grade: _selectedGrade,
          avatar: _selectedAvatar,
          birthDate: _selectedBirthDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

        if (credentials != null && mounted) {
          await _showCredentialsDialog(
            studentName: '$nombres $apellidos',
            username: credentials.username,
            temporaryPassword: credentials.temporaryPassword,
          );
          if (mounted) Navigator.pop(context);
        } else if (mounted) {
          _showErrorSnackBar(
              studentProvider.errorMessage ?? 'Error al crear estudiante');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(
            'Error al ${isEditing ? "actualizar" : "crear"} estudiante: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// Muestra el usuario y la clave temporal generados — es la ÚNICA vez
  /// que la clave existe, así que no se puede cerrar el diálogo por accidente
  /// (barrierDismissible: false) y se ofrece copiar/compartir cada dato.
  Future<void> _showCredentialsDialog({
    required String studentName,
    required String username,
    required String temporaryPassword,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600]),
              const SizedBox(width: 8),
              const Expanded(child: Text('Estudiante creado')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comparte estos datos con $studentName para que pueda ingresar. '
                  'Esta clave temporal no se mostrará de nuevo.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
                _buildCredentialRow(
                  label: 'Usuario',
                  value: username,
                  icon: Icons.person,
                ),
                const SizedBox(height: 12),
                _buildCredentialRow(
                  label: 'Clave temporal',
                  value: temporaryPassword,
                  icon: Icons.key,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber[800], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Al ingresar por primera vez, el estudiante deberá crear su propia contraseña.',
                          style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: 'Hola $studentName, tus datos de acceso a EstudioApp son:\n\n'
                        'Usuario: $username\n'
                        'Clave temporal: $temporaryPassword\n\n'
                        'Al ingresar por primera vez deberás crear tu propia contraseña.',
                  ),
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Compartir'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Listo'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCredentialRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copiar',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copiado'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}