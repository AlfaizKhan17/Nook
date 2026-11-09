import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'my_post_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await _auth.getCurrentProfile();
      if (mounted) setState(() => _profile = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final name = (_profile?['name'] ?? 'Student').toString();
    final email = (_profile?['email'] ?? _auth.currentUser?.email ?? '').toString();
    final phone = (_profile?['phone'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 105),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(28)),
          child: Column(children: [
            Container(
              width: 78, height: 78,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2)),
              child: Center(child: Text(initial, style: TextStyle(fontSize: 30, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600))),
            ),
            const SizedBox(height: 11),
            Text(name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 3),
            Text(email, style: Theme.of(context).textTheme.bodyMedium),
            if (phone.isNotEmpty) Text('☎ $phone', style: Theme.of(context).textTheme.bodyMedium),
          ]),
        ),
        const SizedBox(height: 18),
        _tile(Icons.edit_outlined, 'Edit Profile', () => _showEdit(name, phone)),
        const SizedBox(height: 10),
        _tile(Icons.inventory_2_outlined, 'My Posts', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPostsScreen()))),
        const SizedBox(height: 10),
        _tile(Icons.help_outline_rounded, 'Help & Support', () {}),
        const SizedBox(height: 10),
        Card(child: ListTile(leading: const Icon(Icons.dark_mode_outlined), title: const Text('Dark mode'), subtitle: const Text('Use a darker appearance'), trailing: ValueListenableBuilder<ThemeMode>(valueListenable: AppThemeController.mode, builder: (context, mode, _) => Switch(value: mode == ThemeMode.dark, onChanged: (enabled) => AppThemeController.setMode(enabled ? ThemeMode.dark : ThemeMode.light))),)),
        const SizedBox(height: 10),
        _tile(Icons.logout_rounded, 'Logout', _logout, danger: true),
      ]),
    );

    if (widget.embedded) {
      return SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
              child: Row(children: [
                Expanded(child: Text('Profile', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28))),
                IconButton(onPressed: () => _showEdit(name, phone), icon: const Icon(Icons.settings_outlined)),
              ])),
          Expanded(child: content),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Profile')),
      body: content,
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap, {bool danger = false}) => Card(
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon, color: danger ? AppColors.lost : Theme.of(context).colorScheme.onSurface),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: danger ? AppColors.lost : Theme.of(context).colorScheme.onSurface)),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );

  Future<void> _showEdit(String name, String phone) async {
    final nameC = TextEditingController(text: name);
    final phoneC = TextEditingController(text: phone);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Phone')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            try {
              await _auth.updateProfile(name: nameC.text.trim(), phone: phoneC.text.trim());
              if (!mounted) return;
              Navigator.pop(context);
              _load();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
            }
          }, child: const Text('Save')),
        ],
      ),
    );
    nameC.dispose(); phoneC.dispose();
  }
}
