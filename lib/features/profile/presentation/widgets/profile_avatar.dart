import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 30,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Theme.of(context).colorScheme.primary;
    final fgColor = foregroundColor ?? Colors.white;
    final normalizedImageUrl = _absoluteImageUrl(imageUrl);

    if (normalizedImageUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor.withOpacity(0.12),
        backgroundImage: NetworkImage(normalizedImageUrl),
        onBackgroundImageError: (_, _) {},
        child: const SizedBox.shrink(),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: fgColor,
          fontSize: radius * 0.62,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String? _absoluteImageUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final url = value.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final path = url.startsWith('/') ? url : '/storage/$url';
    return 'https://store.creativehabib.com$path';
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    return parts.take(2).map((part) => part.characters.first.toUpperCase()).join();
  }
}
