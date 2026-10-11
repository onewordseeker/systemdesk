import 'package:flutter/material.dart';

/// Warning pill shown in the sidebar account card when the build is not pointed at the
/// production API (see kIsTestMode).
class TestModeBadge extends StatelessWidget {
  const TestModeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF3B2F00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFACC15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 11, color: ink),
          SizedBox(width: 2),
          Text(
            'TEST',
            style: TextStyle(
              color: ink,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
