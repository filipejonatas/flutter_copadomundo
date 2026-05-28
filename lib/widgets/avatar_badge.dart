import 'package:flutter/material.dart';

import '../models/avatar_option.dart';

class AvatarBadge extends StatelessWidget {
  const AvatarBadge({super.key, required this.avatarId, this.radius = 22});

  final String avatarId;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatar = avatarById(avatarId);

    return CircleAvatar(
      radius: radius,
      backgroundColor: avatar.color.withValues(alpha: .18),
      child: Icon(avatar.icon, color: avatar.color, size: radius),
    );
  }
}
