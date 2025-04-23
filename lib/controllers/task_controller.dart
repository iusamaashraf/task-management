import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/gemini_service.dart';
import 'package:intl/intl.dart';

class TaskController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GeminiService _geminiService = GeminiService();

  final RxList<TaskModel> tasks = <TaskModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;
  final Rx<TimeOfDay?> selectedTimeSlot = Rx<TimeOfDay?>(null);

  @override
  void onInit() {
    super.onInit();
    fetchTasks();
  }

  Future<void> fetchTasks() async {
    try {
      isLoading.value = true;

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfToday =
          DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      final QuerySnapshot snapshot = await _firestore
          .collection('tasks')
          .where('scheduledTime', isGreaterThanOrEqualTo: startOfToday)
          .where('scheduledTime', isLessThanOrEqualTo: endOfToday)
          .get();

      tasks.value = snapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc as DocumentSnapshot))
          .toList();

      tasks.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    } catch (e) {
      error.value = 'Failed to fetch tasks: $e';
      debugPrint('Error fetching tasks: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addTask(TaskModel task) async {
    try {
      final DocumentReference docRef =
          await _firestore.collection('tasks').add(task.toMap());
      final newTask = task.copyWith(id: docRef.id);
      tasks.add(newTask);
      tasks.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    } catch (e) {
      error.value = 'Failed to add task: $e';
    }
  }

  Future<void> updateTask(TaskModel task) async {
    try {
      if (task.id == null) return;

      await _firestore.collection('tasks').doc(task.id).update(task.toMap());

      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        tasks[index] = task;
        tasks.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      }
    } catch (e) {
      error.value = 'Failed to update task: $e';
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();
      tasks.removeWhere((task) => task.id == taskId);
    } catch (e) {
      error.value = 'Failed to delete task: $e';
    }
  }

  void setSelectedDate(DateTime date) {
    selectedDate.value = date;
    filterTasksByDate(date);
  }

  void filterTasksByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    _firestore.collection('tasks').get().then((snapshot) {
      final allTasks = snapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc as DocumentSnapshot))
          .toList();

      tasks.value = allTasks.where((task) {
        return task.scheduledTime
                .isAfter(startOfDay.subtract(Duration(seconds: 1))) &&
            task.scheduledTime.isBefore(endOfDay.add(Duration(seconds: 1)));
      }).toList();

      tasks.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    });
  }

  void setSelectedTimeSlot(TimeOfDay time) {
    selectedTimeSlot.value = time;
  }

  Future<void> processVoiceCommand(String command) async {
    try {
      debugPrint('Processing voice command: $command');
      final response = await _geminiService.processVoiceCommand(command);
      debugPrint('Gemini response: $response');

      switch (response['action']) {
        case 'create':
          DateTime scheduledTime;
          if (response.containsKey('scheduledTime') &&
              response['scheduledTime'] is DateTime) {
            scheduledTime = response['scheduledTime'] as DateTime;
          } else {
            final baseDate = selectedDate.value;

            if (response['time'] is TimeOfDay) {
              final time = response['time'] as TimeOfDay;

              final date = response['date'] is DateTime
                  ? response['date'] as DateTime
                  : baseDate;

              scheduledTime = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
            } else {
              final now = DateTime.now();
              scheduledTime = DateTime(
                baseDate.year,
                baseDate.month,
                baseDate.day,
                now.hour,
                now.minute,
              );
            }
          }

          debugPrint('Final Scheduled Time to be used: $scheduledTime');

          final task = TaskModel(
            title: response['title']?.toString() ?? 'Untitled Task',
            description: response['description']?.toString() ??
                'No description provided',
            isCompleted: false,
            createdAt: DateTime.now(),
            scheduledTime: scheduledTime,
          );

          debugPrint(
              'Creating task with scheduled time: ${task.scheduledTime}');
          await addTask(task);
          Get.snackbar(
            'Success',
            'Task "${task.title}" created successfully for ${DateFormat('h:mm a').format(task.scheduledTime)} on ${DateFormat('MMM d, y').format(task.scheduledTime)}',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Get.theme.colorScheme.primary,
            colorText: Get.theme.colorScheme.onPrimary,
          );
          break;

        case 'update':
          if (response['title'] != null) {
            final taskTitle = response['title'].toString();
            debugPrint('Looking for task with title: $taskTitle');
            final existingTask = tasks.firstWhereOrNull(
                (t) => t.title.toLowerCase() == taskTitle.toLowerCase());

            if (existingTask != null && existingTask.id != null) {
              debugPrint('Found existing task: ${existingTask.title}');
              debugPrint('Update data: ${response.toString()}');

              DateTime taskDate;
              if (response['date'] is DateTime) {
                taskDate = response['date'] as DateTime;
              } else {
                taskDate = selectedDate.value;
              }

              TimeOfDay taskTime;
              if (response['time'] is TimeOfDay) {
                taskTime = response['time'] as TimeOfDay;
              } else if (response['time'] is String) {
                final timeStr = response['time'] as String;
                final timeParts = timeStr.split(':');
                taskTime = TimeOfDay(
                  hour: int.parse(timeParts[0]),
                  minute: int.parse(timeParts[1]),
                );
              } else {
                taskTime = TimeOfDay(
                  hour: existingTask.scheduledTime.hour,
                  minute: existingTask.scheduledTime.minute,
                );
              }

              final scheduledTime = DateTime(
                taskDate.year,
                taskDate.month,
                taskDate.day,
                taskTime.hour,
                taskTime.minute,
              );

              final updatedTask = existingTask.copyWith(
                title: response['newTitle']?.toString() ?? existingTask.title,
                description: response['description']?.toString() ??
                    existingTask.description,
                scheduledTime: scheduledTime,
              );

              debugPrint(
                  'Updated task: ${updatedTask.title} at ${updatedTask.scheduledTime}');

              await updateTask(updatedTask);
              Get.snackbar(
                'Success',
                'Task "${updatedTask.title}" updated successfully',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Get.theme.colorScheme.primary,
                colorText: Get.theme.colorScheme.onPrimary,
              );
            } else {
              debugPrint('Task not found: $taskTitle');
              Get.snackbar(
                'Error',
                'Task "$taskTitle" not found',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Get.theme.colorScheme.error,
                colorText: Get.theme.colorScheme.onError,
              );
            }
          }
          break;

        case 'delete':
          if (response['title'] != null) {
            final taskToDelete = tasks.firstWhereOrNull((t) =>
                t.title.toLowerCase() ==
                response['title'].toString().toLowerCase());
            if (taskToDelete != null && taskToDelete.id != null) {
              await deleteTask(taskToDelete.id!);
              Get.snackbar(
                'Success',
                'Task "${taskToDelete.title}" deleted successfully',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Get.theme.colorScheme.primary,
                colorText: Get.theme.colorScheme.onPrimary,
              );
            } else {
              Get.snackbar(
                'Error',
                'Task not found',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Get.theme.colorScheme.error,
                colorText: Get.theme.colorScheme.onError,
              );
            }
          }

          break;
      }

      selectedTimeSlot.value = null;
    } catch (e) {
      error.value = 'Failed to process voice command: $e';
      debugPrint('Error processing voice command: $e');
      Get.snackbar(
        'Error',
        'Failed to process voice command: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    }
  }
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
