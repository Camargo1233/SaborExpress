import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double? width;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: AppColors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    return SizedBox(
      width: width ?? 280,
      height: 52,
      child: icon == null
          ? ElevatedButton(
              style: style,
              onPressed: onPressed,
              child: Text(
                text,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            )
          : ElevatedButton.icon(
              style: style,
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(
                text,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
    );
  }
}
