import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

String getInitials(String? fullName) {
  if (fullName == null || fullName.trim().isEmpty) return '?';
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return parts[0][0].toUpperCase();
}

Widget buildAvatarHelper(
  String? fullName,
  String? avatarUrl, {
  double radius = 40,
  double fontSize = 16,
}) {
  if (avatarUrl != null && avatarUrl.isNotEmpty) {
    if (avatarUrl.startsWith('assets/')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF1E293B),
        backgroundImage: AssetImage(avatarUrl),
      );
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF1E293B),
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
  } else {
    final initials = getInitials(fullName);
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.cyan.shade800,
      child: Text(
        initials,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
