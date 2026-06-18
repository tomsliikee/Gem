import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x224285F4),
            blurRadius: 25,
            spreadRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          'assets/icon.png',
          fit: BoxFit.cover,
          cacheWidth: 240, // Optimize image memory 
          cacheHeight: 240,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Failed to load app logo: $error\n$stackTrace');
            return Container(
              color: Colors.white10,
              child: const Center(
                child: Icon(
                  Icons.auto_awesome,
                  size: 60,
                  color: Color(0xFF4285F4),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
