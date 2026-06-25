// lib/screens/admin/manage_users_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../utils/app_theme.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<User> _users = [];
  bool _isLoading = true;
  String? _error;
  UserRole? _filterRole;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final users = await authProvider.getUsers();
      // Orden: admins primero, luego padres, luego estudiantes; cada
      // grupo alfabético por nombre.
      users.sort((a, b) {
        final roleOrder = {UserRole.admin: 0, UserRole.parent: 1, UserRole.student: 2};
        final roleCompare = roleOrder[a.role]!.compareTo(roleOrder[b.role]!);
        if (roleCompare != 0) return roleCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar usuarios: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<User> get _filteredUsers {
    var result = _users;
    if (_filterRole != null) {
      result = result.where((u) => u.role == _filterRole).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((u) =>
              u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        backgroundColor: AppTheme.adminColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o correo...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(null, 'Todos'),
                const SizedBox(width: 8),
                _buildFilterChip(UserRole.admin, 'Admins'),
                const SizedBox(width: 8),
                _buildFilterChip(UserRole.parent, 'Padres'),
                const SizedBox(width: 8),
                _buildFilterChip(UserRole.student, 'Estudiantes'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(UserRole? role, String label) {
    final isSelected = _filterRole == role;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterRole = role),
      selectedColor: AppTheme.adminColor.withOpacity(0.2),
      checkmarkColor: AppTheme.adminColor,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadUsers, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final filtered = _filteredUsers;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No se encontraron usuarios', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: filtered.length,
        itemBuilder: (context, index) => _buildUserCard(filtered[index]),
      ),
    );
  }

  Widget _buildUserCard(User user) {
    final roleColor = _roleColor(user.role);
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final isSelf = user.id == currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.15),
          child: Icon(_roleIcon(user.role), color: roleColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!user.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text('Inactivo',
                    style: TextStyle(fontSize: 11, color: Colors.red[700])),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.username != null ? 'Usuario: ${user.username}' : user.email,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                user.role.displayName,
                style: TextStyle(fontSize: 11, color: roleColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        trailing: isSelf
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Tú', style: TextStyle(fontSize: 12)),
              )
            : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'toggle') _confirmToggleActive(user);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(user.isActive ? 'Desactivar cuenta' : 'Activar cuenta'),
                  ),
                ],
              ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _confirmToggleActive(User user) async {
    final willActivate = !user.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(willActivate ? 'Activar cuenta' : 'Desactivar cuenta'),
        content: Text(
          willActivate
              ? '¿Quieres reactivar la cuenta de ${user.name}? Podrá iniciar sesión nuevamente.'
              : '¿Quieres desactivar la cuenta de ${user.name}? No podrá iniciar sesión hasta que se reactive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: willActivate ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(willActivate ? 'Activar' : 'Desactivar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.toggleUserActive(user);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(willActivate
              ? 'Cuenta de ${user.name} activada'
              : 'Cuenta de ${user.name} desactivada'),
          backgroundColor: Colors.green,
        ),
      );
      _loadUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Error al actualizar la cuenta'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppTheme.adminColor;
      case UserRole.parent:
        return AppTheme.parentColor;
      case UserRole.student:
        return AppTheme.studentColor;
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.parent:
        return Icons.family_restroom;
      case UserRole.student:
        return Icons.school;
    }
  }
}