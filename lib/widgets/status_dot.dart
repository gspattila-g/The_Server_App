import 'package:flutter/material.dart';

class StatusDot extends StatelessWidget {
  final String status;
  final double size;

  const StatusDot({super.key, required this.status, this.size = 12});

  static Color colorFor(String status) {
    switch (status) {
      case 'online': return Colors.green;
      case 'busy':   return Colors.red;
      default:       return Colors.grey;
    }
  }

  static String labelFor(String status) {
    switch (status) {
      case 'online': return 'Online';
      case 'busy':   return 'Elfoglalt';
      default:       return 'Offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorFor(status),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
