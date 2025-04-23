import 'package:ai_task/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:table_calendar/table_calendar.dart' as calendar;
import '../controllers/task_controller.dart';
import '../widgets/timeline_view.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final ScrollController _scrollController = ScrollController();
  bool _isListening = false;
  String _lastWords = '';
  bool _speechEnabled = false;
  final TaskController _taskController = Get.put(TaskController());

  // Calendar variables
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  calendar.CalendarFormat _calendarFormat = calendar.CalendarFormat.week;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _scrollToCurrentTime();
  }

  void _scrollToCurrentTime() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      final currentTimeSlot = (now.hour * 2) + (now.minute ~/ 30);
      final scrollPosition = currentTimeSlot * 70.0; // timeSlotHeight
      _scrollController.jumpTo(scrollPosition);
    });
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (error) => debugPrint('Speech recognition error: $error'),
        onStatus: (status) => debugPrint('Speech recognition status: $status'),
      );
      setState(() {});
    } catch (e) {
      debugPrint('Error initializing speech recognition: $e');
    }
  }

  void _startListening() async {
    if (!_speechEnabled) {
      Get.snackbar(
        'Error',
        'Speech recognition is not available',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return;
    }

    try {
      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: 'en_US',
      );
      setState(() {
        _isListening = true;
      });
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      Get.snackbar(
        'Error',
        'Failed to start speech recognition',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    }
  }

  void _stopListening() async {
    try {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
      });
      if (_lastWords.isNotEmpty) {
        _taskController.processVoiceCommand(_lastWords);
        setState(() {
          _lastWords = '';
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to stop speech recognition',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    }
  }

  String getWeekday(DateTime date) {
    return ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][date.weekday % 7];
  }

  final DateTime baseDate = DateTime.now();

  int selectedIndex = 365;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voice Task Manager',
              style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600),
            ),
            Obx(() => Text(
                  'Date: ${DateFormat('MMM d, y').format(_taskController.selectedDate.value)}',
                  style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400),
                )),
          ],
        ),
        backgroundColor: primaryColor,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Calendar widget
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: calendar.TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                startingDayOfWeek: calendar.StartingDayOfWeek.monday,
                calendarStyle: calendar.CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const calendar.HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _taskController.setSelectedDate(selectedDay);
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
              ),
            ),

            // Timeline view
            Expanded(
              child: Obx(() {
                if (_taskController.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                return TimelineView(
                  timeSlotHeight: 180,
                  scrollController: _scrollController,
                );
              }),
            ),

            // Listening indicator
            if (_isListening)
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastWords.isEmpty ? 'Listening...' : _lastWords,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: _isListening ? _stopListening : _startListening,
        tooltip: _isListening ? 'Stop listening' : 'Start listening',
        child: Icon(
          _isListening ? Icons.mic_off : Icons.mic,
          color: whiteColor,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
