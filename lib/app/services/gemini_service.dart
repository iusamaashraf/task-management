import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  late final GenerativeModel _model;

  factory GeminiService() {
    return _instance;
  }

  GeminiService._internal() {
    try {
      _model = GenerativeModel(
        model: 'gemini-1.5-pro',
        apiKey: ConfigService.geminiApiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
      );
    } catch (e) {
      debugPrint('Error initializing Gemini model: $e');
      // Fallback to a simpler model if the pro version is not available
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: ConfigService.geminiApiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> processVoiceCommand(String command) async {
    try {
      debugPrint('Processing command: $command');

      final prompt = '''
Parse the following voice command and extract task information. Return a JSON object with the following structure:
{
  "action": "create" | "update" | "delete",
  "title": "task title to find",
  "newTitle": "new title if renaming",
  "description": "task description",
  "date": "YYYY-MM-DD",
  "time": "HH:mm"
}

Rules:
1. For create action:
   - Extract title and description from the command
   - If no description is given, use "No description provided"
   - Always include a description field
   - Get scheduled time from the command and convert it to 24-hour format
2. For update action:
   - Extract the task title to find and any new information to update
   - Keep existing description if no new one is provided
   - Handle multiple update types:
     a. Title update: "Rename task X to Y" or "Change task X title to Y"
     b. Description update: "Update description of task X to Y" or "Change task X description to Y"
     c. Time update: "Change time of task X to Y" or "Reschedule task X to Y"
     d. Date update: "Change date of task X to Y" or "Move task X to Y"
     e. Combined updates: "Update task X title to Y and time to Z"
3. For delete action:
   - Detect **common spoken phrases and slang** that imply deletion:
     "delete", "remove", "get rid of", "cancel", "drop", "kill", "trash", "clear", "erase", "forget", "scrap", "call off", "stop", "cut", "undo", "eliminate"
   - Handle different types of deletions:
     a. Single task deletion: "delete task X"
     b. Bulk deletion by date: "delete all tasks for today/tomorrow/next week"
     c. Bulk deletion by time range: "delete all tasks between X and Y"
     d. Bulk deletion by status: "delete all completed tasks"
     e. Bulk deletion by category: "delete all work tasks"
   - For bulk deletions, return special fields:
     {
       "action": "delete",
       "bulkDelete": true,
       "deleteType": "date|range|status|category",
       "date": "YYYY-MM-DD",  // for date-based deletion
       "startDate": "YYYY-MM-DD",  // for range-based deletion
       "endDate": "YYYY-MM-DD",  // for range-based deletion
       "status": "completed|pending",  // for status-based deletion
       "category": "work|personal",  // for category-based deletion
       "title": null  // null for bulk deletions
     }
   - For date-based operations:
     - When "today" is mentioned, use the current date from DateTime.now()
     - When "tomorrow" is mentioned, use DateTime.now().add(Duration(days: 1))
     - When "next week" is mentioned, use DateTime.now().add(Duration(days: 7))
     - When "last week" is mentioned, use DateTime.now().subtract(Duration(days: 7))
     - When "this month" is mentioned, use the first day of current month
     - When "last month" is mentioned, use the first day of previous month
   - Only extract the title of the task to delete for single task deletion
   - Ignore extra words or noise around the command
   - Examples:
     - "Hey can you get rid of the morning alarm task" → { "action": "delete", "title": "morning alarm" }
     - "I don't want that meeting anymore, trash it" → { "action": "delete", "title": "meeting" }
     - "Delete all tasks for today" → { "action": "delete", "bulkDelete": true, "deleteType": "date", "date": "2025-04-23" }
     - "Remove all tasks between Monday and Friday" → { "action": "delete", "bulkDelete": true, "deleteType": "range", "startDate": "2025-04-22", "endDate": "2025-04-26" }
     - "Clear all completed tasks" → { "action": "delete", "bulkDelete": true, "deleteType": "status", "status": "completed" }
     - "Delete all work related tasks" → { "action": "delete", "bulkDelete": true, "deleteType": "category", "category": "work" }
4. For time:
   - Convert 12-hour format to 24-hour format (e.g., "8:50 PM" -> "20:50")
   - Always return time in 24-hour format "HH:mm"
   - Handle relative times: "in 2 hours", "tomorrow at 3pm", "next week at 10am"
5. For date:
   - Convert natural language dates to "YYYY-MM-DD" format
   - Handle relative dates: "tomorrow", "next Monday", "in 3 days"
   - Handle date ranges: "between X and Y"
6. If a specific time is mentioned in the command, you MUST extract it and return it in the "time" field. If not mentioned, omit the "time" field entirely. DO NOT use current time unless clearly requested.
7. For renaming a task, use "newTitle" field with the new name

Examples:
1. Create:
   - "Create a task titled Team Meeting at 8:50 PM on December 5th, 2025"
   - "Schedule a new task called Project Review tomorrow at 3pm"
2. Update:
   - "Rename the task Team Meeting to Project Review"
   - "Move Team Meeting to next Monday at 2pm"
   - "Update Team Meeting title to Project Review and change time to 3pm"
3. Delete:
   - "Delete the task Team Meeting"
   - "Remove Project Review task"
   - "Forget about the gym session"
   - "Trash the thing for groceries"
   - "Delete all tasks for today"
   - "Remove everything scheduled for next week"
   - "Clear all completed tasks from last month"
   - "Delete all work tasks"
   - "Remove all tasks between Monday and Friday"

Voice command: $command
''';

      debugPrint('Sending prompt to Gemini: $prompt');
      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;

      if (responseText == null) {
        throw Exception('Failed to get response from Gemini');
      }

      debugPrint('Raw Gemini response: $responseText');

      final jsonStr = responseText.substring(
        responseText.indexOf('{'),
        responseText.lastIndexOf('}') + 1,
      );

      debugPrint('Extracted JSON: $jsonStr');

      final Map<String, dynamic> raw = jsonDecode(jsonStr);
      final Map<String, dynamic> result = {};

      raw.forEach((key, value) {
        if (key == 'date' && value is String) {
          try {
            result[key] = DateTime.parse(value);
          } catch (e) {
            debugPrint('Error parsing date: $e');
            result[key] = DateTime.now();
          }
        } else if (key == 'time' && value is String) {
          try {
            final timeParts = value.split(':');
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            result[key] = TimeOfDay(hour: hour, minute: minute);
            debugPrint('Successfully parsed time: $hour:$minute');
          } catch (e) {
            debugPrint('Error parsing time: $e');
            result[key] = TimeOfDay.now();
          }
        } else {
          result[key] = value;
        }
      });

      if (!result.containsKey('time')) {
        debugPrint(
            '⚠️ Warning: No time extracted from the voice command. Task may be created with default or current time.');
      }

      if (result.containsKey('date') && result.containsKey('time')) {
        final date = result['date'] as DateTime;
        final time = result['time'] as TimeOfDay;

        final scheduledTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        result['scheduledTime'] = scheduledTime;
        debugPrint('Created scheduled time: $scheduledTime');
      }

      debugPrint('Final parsed result: $result');

      if (!result.containsKey('action')) {
        throw Exception('Missing required field: action');
      }

      return result;
    } catch (e) {
      debugPrint('Error processing voice command: $e');
      rethrow;
    }
  }

  Future<String> processCommand(String command) async {
    try {
      final content = [Content.text(command)];
      final response = await _model.generateContent(content);
      return response.text ?? 'No response from AI';
    } catch (e) {
      return 'Error processing command: $e';
    }
  }

  static Future<String> generateResponse(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${ConfigService.geminiApiKey}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        throw Exception('Failed to generate response: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error calling Gemini API: $e');
    }
  }
}
