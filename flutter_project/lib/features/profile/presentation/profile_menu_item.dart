import 'package:flutter/material.dart';

/// Novas opções podem ser incluídas sem modificar o cabeçalho do perfil.
class ProfileMenuItem {
  const ProfileMenuItem(
      {required this.title,
      required this.icon,
      required this.onTap,
      this.subtitle});
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final String? subtitle;
}
