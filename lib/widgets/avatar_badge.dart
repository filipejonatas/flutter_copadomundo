import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/avatar_option.dart';
import '../theme/app_theme.dart';

/// Circular user avatar badge based on a selected Phosphor icon.
class AvatarBadge extends StatelessWidget {
  const AvatarBadge({
    super.key,
    required this.avatarId,
    this.photoUrl,
    this.radius = 22,
  });

  final String avatarId;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatar = avatarById(avatarId);
    final imageUrl = photoUrl?.trim();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceElevated,
        foregroundImage: NetworkImage(imageUrl),
        child: PhosphorIcon(avatar.icon, color: avatar.color, size: radius),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceElevated,
      child: PhosphorIcon(avatar.icon, color: avatar.color, size: radius),
    );
  }
}
