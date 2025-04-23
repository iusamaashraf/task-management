import 'package:ai_task/global/constants/colors.dart';
import 'package:ai_task/global/widgets/time_slot_divisions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/controllers/task_controller.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class TimelineView extends StatelessWidget {
  final double timeSlotHeight;
  final ScrollController scrollController;
  final TaskController controller = Get.find<TaskController>();

  TimelineView({
    super.key,
    this.timeSlotHeight = 70.0,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: 24 * 2,
      itemBuilder: (context, index) {
        final hour = index ~/ 2;
        final minute = (index % 2) * 30;
        final timeSlot = DateTime(2025, 1, 1, hour, minute);
        final timeString = DateFormat('hh:mm a').format(timeSlot);

        return Obx(() {
          // Find tasks for this time slot
          final tasksInSlot = controller.tasks.where((task) {
            final taskHour = task.scheduledTime.hour;
            final taskMinute = task.scheduledTime.minute;
            return taskHour == hour &&
                (taskMinute >= minute && taskMinute < minute + 30);
          }).toList();

          return SizedBox(
            height: timeSlotHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time label
                SizedBox(
                  width: 110,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          timeString,
                          style: GoogleFonts.dmSans(
                            color: Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 10),
                        TimeSlotDivisions(width: 30),
                        SizedBox(height: 20),
                        TimeSlotDivisions(width: 50),
                        SizedBox(height: 25),
                        TimeSlotDivisions(width: 15),
                        SizedBox(height: 20),
                        TimeSlotDivisions(width: 35),
                        SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),

                // Tasks area
                Expanded(
                  child: tasksInSlot.isEmpty
                      ? Container()
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          scrollDirection: Axis.horizontal,
                          itemCount: tasksInSlot.length,
                          itemBuilder: (context, taskIndex) {
                            final task = tasksInSlot[taskIndex];

                            final random = Random(task.title.hashCode);
                            final color = brightColors[
                                random.nextInt(brightColors.length)];
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                width: MediaQuery.sizeOf(context).width * .7,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 1,
                                    ),
                                  ],
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: GoogleFonts.dmSans(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: color,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (task.description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        task.description,
                                        style: GoogleFonts.dmSans(
                                            fontSize: 14,
                                            color: color,
                                            fontWeight: FontWeight.w400),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}
