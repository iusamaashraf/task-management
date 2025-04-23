import 'package:flutter/material.dart';

class TimeSlotDivisions extends StatelessWidget {
  const TimeSlotDivisions({
    super.key,
    required this.width,
  });
  final double width;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      width: width,
      color: Colors.black54,
    );
  }
}
