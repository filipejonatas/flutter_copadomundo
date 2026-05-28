import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/avatar_option.dart';
import '../services/session_controller.dart';
import '../widgets/avatar_badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nickController;
  late String _selectedAvatarId;

  @override
  void initState() {
    super.initState();
    final user = widget.sessionController.currentUser!;
    _nickController = TextEditingController(text: user.nick);
    _selectedAvatarId = user.avatarId;
  }

  @override
  void dispose() {
    _nickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.sessionController.currentUser!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: widget.sessionController.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _UserSummary(user: user),
            const SizedBox(height: 20),
            Text('Nick no ranking', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _nickController,
              maxLength: 24,
              decoration: const InputDecoration(
                hintText: 'Como voce quer aparecer?',
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            Text('Imagem do nick', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: avatarOptions.map((avatar) {
                final isSelected = avatar.id == _selectedAvatarId;
                return ChoiceChip(
                  selected: isSelected,
                  onSelected: (_) =>
                      setState(() => _selectedAvatarId = avatar.id),
                  label: Icon(avatar.icon, color: avatar.color, size: 26),
                  showCheckmark: false,
                  padding: const EdgeInsets.all(10),
                  side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : const Color(0xFFD4DDD2),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: widget.sessionController.isLoading ? null : _save,
              icon: widget.sessionController.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(
                widget.sessionController.isLoading
                    ? 'Salvando...'
                    : 'Salvar perfil',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final nick = _nickController.text.trim();
    if (nick.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use um nick com pelo menos 3 letras.')),
      );
      return;
    }

    await widget.sessionController.updateProfile(
      nick: nick,
      avatarId: _selectedAvatarId,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Perfil atualizado.')));
    setState(() {});
  }
}

class _UserSummary extends StatelessWidget {
  const _UserSummary({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            AvatarBadge(avatarId: user.avatarId, radius: 34),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.nick, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(user.email, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
