import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? fallbackLetter;
  final double radius;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.fallbackLetter,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
          ? NetworkImage(imageUrl!)
          : null,
      onBackgroundImageError: imageUrl != null && imageUrl!.isNotEmpty
          ? (_, __) {}
          : null,
      child: imageUrl == null || imageUrl!.isEmpty
          ? Text(
              fallbackLetter?.isNotEmpty == true
                  ? fallbackLetter![0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: radius * 0.9,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            )
          : null,
    );
  }
}
