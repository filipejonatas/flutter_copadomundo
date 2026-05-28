import 'package:flutter/material.dart';

class AvatarOption {
  const AvatarOption({
    required this.id,
    required this.icon,
    required this.color,
  });

  final String id;
  final IconData icon;
  final Color color;
}

const avatarOptions = [
  AvatarOption(id: 'star', icon: Icons.star, color: Color(0xFFF6C44F)),
  AvatarOption(id: 'ball', icon: Icons.sports_soccer, color: Color(0xFF0E7C4F)),
  AvatarOption(id: 'cup', icon: Icons.emoji_events, color: Color(0xFFD79222)),
  AvatarOption(id: 'target', icon: Icons.gps_fixed, color: Color(0xFFC53B3B)),
  AvatarOption(id: 'goal', icon: Icons.sports, color: Color(0xFF3B66C5)),
  AvatarOption(id: 'voice', icon: Icons.campaign, color: Color(0xFF6E4CC5)),
];

AvatarOption avatarById(String id) {
  return avatarOptions.firstWhere(
    (avatar) => avatar.id == id,
    orElse: () => avatarOptions.first,
  );
}
