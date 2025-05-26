import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'question_service.dart';

class ProgressService {
  // Keys for storing progress data
  static const String _keyOverallProgress = 'overall_progress';
  static const String _keyCompletedItems = 'completed_items';
  static const String _keyAccuracy = 'accuracy';
  static const String _keyStudyTime = 'study_time';
  static const String _keySectionProgress = 'section_progress';
  static const String _keyLastActivity = 'last_activity';

  // Initialize default progress data for new users
  static Future<void> initializeProgressData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load questions first to get categories
    await QuestionService.loadQuestions();
    final categories = QuestionService.getCategories();

    // Check if data already exists
    if (!prefs.containsKey(_keyOverallProgress)) {
      // Set default overall progress (0%)
      await prefs.setDouble(_keyOverallProgress, 0.0);

      // Set default completed items (0)
      await prefs.setInt(_keyCompletedItems, 0);

      // Set default accuracy (0%)
      await prefs.setDouble(_keyAccuracy, 0.0);

      // Set default study time (0 minutes)
      await prefs.setInt(_keyStudyTime, 0);

      // Initialize section progress
      final Map<String, Map<String, dynamic>> sectionProgress = {};
      for (var category in categories) {
        final questionCount =
            QuestionService.getQuestionsByCategory(category).length;
        sectionProgress[category] = {
          'progress': 0.0,
          'completed': 0,
          'total': questionCount,
        };
      }

      // Save section progress
      await prefs.setString(_keySectionProgress, jsonEncode(sectionProgress));

      // Initialize last activity
      await prefs.setString(
          _keyLastActivity,
          jsonEncode({
            'title': 'Welcome',
            'type': 'intro',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'detail': 'First login',
            'score': null,
          }));
    }
  }

  // Get overall progress percentage
  static Future<double> getOverallProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyOverallProgress) ?? 0.0;
  }

  // Update overall progress percentage
  static Future<void> updateOverallProgress(double progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyOverallProgress, progress);
  }

  // Get number of completed items
  static Future<int> getCompletedItems() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCompletedItems) ?? 0;
  }

  // Update number of completed items
  static Future<void> updateCompletedItems(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCompletedItems, count);
  }

  // Get accuracy percentage
  static Future<double> getAccuracy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyAccuracy) ?? 0.0;
  }

  // Update accuracy percentage
  static Future<void> updateAccuracy(double accuracy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyAccuracy, accuracy);
  }

  // Get study time in minutes
  static Future<int> getStudyTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStudyTime) ?? 0;
  }

  // Add study time in minutes
  static Future<void> addStudyTime(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final currentTime = prefs.getInt(_keyStudyTime) ?? 0;
    await prefs.setInt(_keyStudyTime, currentTime + minutes);
  }

  // Get all section progress data
  static Future<Map<String, dynamic>> getSectionProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keySectionProgress);
    if (data != null) {
      return jsonDecode(data);
    }
    return {};
  }

  // Get available categories
  static Future<List<String>> getCategories() async {
    await QuestionService.loadQuestions();
    return QuestionService.getCategories();
  }

  // Update progress for a specific section
  static Future<void> updateSectionProgress(
      String section, double progress, int completed) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keySectionProgress);

    if (data != null) {
      final Map<String, dynamic> sectionData = jsonDecode(data);

      if (sectionData.containsKey(section)) {
        sectionData[section]['progress'] = progress;
        sectionData[section]['completed'] = completed;
        await prefs.setString(_keySectionProgress, jsonEncode(sectionData));

        // Also update overall progress based on all sections
        double totalProgress = 0;
        int totalCompleted = 0;

        sectionData.forEach((key, value) {
          totalProgress += value['progress'] as double;
          totalCompleted += value['completed'] as int;
        });

        totalProgress = totalProgress / sectionData.length;
        await updateOverallProgress(totalProgress);
        await updateCompletedItems(totalCompleted);
      }
    }
  }

  // Get last activity data
  static Future<Map<String, dynamic>> getLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyLastActivity);
    if (data != null) {
      return jsonDecode(data);
    }
    return {};
  }

  // Record a new activity
  static Future<void> recordActivity({
    required String title,
    required String type,
    required String detail,
    double? score,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final activity = {
      'title': title,
      'type': type,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'detail': detail,
      'score': score,
    };

    await prefs.setString(_keyLastActivity, jsonEncode(activity));

    // If this is a scored activity, update the accuracy
    if (score != null) {
      final currentAccuracy = await getAccuracy();
      final newAccuracy = (currentAccuracy + score) / 2; // Simple average
      await updateAccuracy(newAccuracy);
    }
  }

  // Complete an item in a section
  static Future<void> completeItem(String section, double scorePercent) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keySectionProgress);

    if (data != null) {
      final Map<String, dynamic> sectionData = jsonDecode(data);

      if (sectionData.containsKey(section)) {
        final sectionInfo = sectionData[section];
        final int completed = sectionInfo['completed'] as int;
        final int total = sectionInfo['total'] as int;

        if (completed < total) {
          // Update completed count
          sectionInfo['completed'] = completed + 1;

          // Calculate new progress percentage
          final double progress = (completed + 1) / total;
          sectionInfo['progress'] = progress;

          // Save updated section data
          await prefs.setString(_keySectionProgress, jsonEncode(sectionData));

          // Record activity
          await recordActivity(
            title: section,
            type: 'quiz',
            detail: 'Completed item ${completed + 1} of $total',
            score: scorePercent,
          );

          // Add study time (5-15 minutes per item)
          await addStudyTime(10);

          // Update overall progress
          double totalProgress = 0;
          int totalCompleted = 0;

          sectionData.forEach((key, value) {
            totalProgress += value['progress'] as double;
            totalCompleted += value['completed'] as int;
          });

          totalProgress = totalProgress / sectionData.length;
          await updateOverallProgress(totalProgress);
          await updateCompletedItems(totalCompleted);
        }
      }
    }
  }

  // Reset progress data (for testing)
  static Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOverallProgress);
    await prefs.remove(_keyCompletedItems);
    await prefs.remove(_keyAccuracy);
    await prefs.remove(_keyStudyTime);
    await prefs.remove(_keySectionProgress);
    await prefs.remove(_keyLastActivity);

    // Re-initialize with default values
    await initializeProgressData();
  }

  // Get categories as sections
  static List<String> get sections => QuestionService.getCategories();
}
