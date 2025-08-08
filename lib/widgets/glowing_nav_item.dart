import 'package:flutter/material.dart';

class GlowingNavItem extends StatelessWidget {
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const GlowingNavItem({
    super.key,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 40,
      splashColor: const Color(0xFF1E88FF).withOpacity(.25),
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? const Color(0xFF1E88FF) : Colors.white,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E88FF).withOpacity(.55),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1E88FF)
                : Colors.grey.withOpacity(.25),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 26,
          color: isSelected ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }
}