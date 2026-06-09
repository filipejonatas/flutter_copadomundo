import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../services/session_controller.dart';
import '../theme/app_theme.dart';

/// Circular logout action used consistently across authenticated screens.
class LogoutCircleButton extends StatelessWidget {
  const LogoutCircleButton({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Sair',
      onPressed: sessionController.isLoading ? null : sessionController.signOut,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceElevated,
        foregroundColor: AppColors.primaryAccent,
        disabledForegroundColor: AppColors.textSecondary,
        shape: const CircleBorder(),
        side: BorderSide(color: Colors.white.withValues(alpha: .08)),
      ),
      icon: PhosphorIcon(PhosphorIcons.signOut()),
    );
  }
}
