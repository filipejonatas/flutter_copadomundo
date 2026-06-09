import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
  AvatarOption(
    id: 'star',
    icon: PhosphorIconsRegular.star,
    color: Color(0xFFC6F135),
  ),
  AvatarOption(
    id: 'ball',
    icon: PhosphorIconsRegular.soccerBall,
    color: Color(0xFF00C896),
  ),
  AvatarOption(
    id: 'cup',
    icon: PhosphorIconsRegular.trophy,
    color: Color(0xFFD79222),
  ),
  AvatarOption(
    id: 'target',
    icon: PhosphorIconsRegular.crosshair,
    color: Color(0xFFFF3B30),
  ),
  AvatarOption(
    id: 'goal',
    icon: PhosphorIconsRegular.flag,
    color: Color(0xFF49A7FF),
  ),
  AvatarOption(
    id: 'voice',
    icon: PhosphorIconsRegular.megaphone,
    color: Color(0xFFB58CFF),
  ),
];

AvatarOption avatarById(String id) {
  return avatarOptions.firstWhere(
    (avatar) => avatar.id == id,
    orElse: () => avatarOptions.first,
  );
}
