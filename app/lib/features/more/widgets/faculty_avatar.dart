import 'package:flutter/material.dart';
import '../../../models/faculty.dart';

class FacultyAvatar extends StatelessWidget {
  const FacultyAvatar({
    super.key,
    required this.faculty,
    this.size = 48,
  });

  final Faculty faculty;
  final double size;

  Widget _buildInitialsAvatar(String name) {
    final initials = name
        .split(' ')
        .where((s) => s.isNotEmpty && s.toLowerCase() != 'dr.' && s.toLowerCase() != 'mr.' && s.toLowerCase() != 'ms.')
        .map((s) => s[0])
        .take(2)
        .join('')
        .toUpperCase();

    final displayInitials = initials.isNotEmpty
        ? initials
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF), // Soft Blue
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        displayInitials,
        style: TextStyle(
          color: const Color(0xFF2563EB), // Royal Blue
          fontWeight: FontWeight.bold,
          fontSize: size * 0.38,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl = faculty.imgUrl.trim();
    final hasImage = imgUrl.isNotEmpty && 
        (imgUrl.startsWith('http://') || imgUrl.startsWith('https://'));

    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          imgUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: size,
              height: size,
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialsAvatar(faculty.name);
          },
        ),
      );
    } else {
      return _buildInitialsAvatar(faculty.name);
    }
  }
}
