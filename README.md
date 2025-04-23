# Voice Task Manager

A Flutter application that allows users to manage tasks using voice commands, powered by Google's Gemini AI.

![App Screenshot](screenshots/app_screenshot.png)

## Features

- **Voice Command Task Management**: Create, update, and delete tasks using natural language voice commands
- **Calendar Integration**: View and manage tasks by date with an intuitive calendar interface
- **Timeline View**: Visualize tasks throughout the day in a timeline format
- **Smart Task Processing**: Uses Gemini AI to interpret voice commands and extract task details
- **Real-time Updates**: UI automatically updates when tasks are modified

## Voice Command Examples

- "Create a meeting with John tomorrow at 2 PM"
- "Update the project deadline to next Friday"
- "Delete all tasks for today"
- "Mark the presentation task as completed"

## Technical Architecture

### State Management

This app uses **GetX** for state management, chosen for its simplicity and powerful features:

- **Reactive State**: Automatic UI updates when data changes
- **Dependency Injection**: Easy service management
- **Route Management**: Simplified navigation
- **Snackbars and Dialogs**: Built-in UI feedback

### MVVM Architecture

The app follows the Model-View-ViewModel (MVVM) pattern:

- **Model**: Data structures and business logic
- **View**: UI components (screens and widgets)
- **ViewModel**: State management and business logic

### LLM Integration

The app integrates with Google's Gemini AI to process voice commands:

1. Voice input is converted to text using the device's speech recognition
2. Text is sent to Gemini AI for natural language processing
3. Gemini AI extracts task details (title, description, date, time)
4. The app performs the appropriate action based on the extracted information

## Setup Instructions

### Prerequisites

- Flutter SDK (2.0.0 or higher)
- Dart SDK (2.12.0 or higher)
- Android Studio / VS Code with Flutter extensions
- Google Cloud account with Gemini API access

### Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/voice-task-manager.git
   cd voice-task-manager
   ```

2. Install dependencies:
   ```
   flutter pub get
   ```

3. Create a `.env` file in the root directory with your Gemini API key:
   ```
   GEMINI_API_KEY=your_api_key_here
   ```

4. Run the app:
   ```
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                  # App entry point
├── models/                    # Data models
│   └── task.dart              # Task model
├── services/                  # Services
│   ├── config_service.dart    # Environment configuration
│   ├── gemini_service.dart    # Gemini AI integration
│   └── task_service.dart      # Task data operations
├── viewmodels/                # ViewModels
│   └── task_view_model.dart   # Task state management
├── screens/                   # UI screens
│   └── home_screen.dart       # Main app screen
└── widgets/                   # Reusable UI components
    └── timeline_view.dart     # Timeline visualization
```

## How the LLM Integration Works

1. **Voice Input**: The app captures voice input using the device's speech recognition
2. **Text Processing**: The text is sent to Gemini AI with a prompt that instructs it to extract task details
3. **Response Parsing**: The app parses the structured response from Gemini AI
4. **Action Execution**: Based on the extracted information, the app performs the appropriate action:
   - Creating a new task
   - Updating an existing task
   - Deleting a task
   - Bulk operations

## Future Enhancements

- Task categories and tags
- Recurring tasks
- Task reminders and notifications
- Data synchronization across devices
- Offline support
- Multiple language support

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Google Gemini AI for natural language processing
- Flutter team for the amazing framework
- GetX for state management
