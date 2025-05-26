import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class QuestionService {
  static Map<String, dynamic>? _questionData;
  static List<String> _categories = [];
  // Load questions from GitHub URL
  static Future<void> loadQuestions() async {
    if (_questionData != null) return; // Already loaded

    // GitHub raw content URL for your JSON file
    // Replace with your actual GitHub raw content URL
    final String gitHubUrl =
        'https://raw.githubusercontent.com/zakariaferzazi/questions-answers/refs/heads/master/SATEXAM.json';

    try {
      // Make HTTP request to fetch the JSON
      final http.Response response = await http.get(Uri.parse(gitHubUrl));

      if (response.statusCode == 200) {
        // Successfully got the data
        final Map<String, dynamic> data = json.decode(response.body);
        _questionData = data;

        // Extract categories
        if (data.containsKey('categorized_questions')) {
          _categories = List<String>.from(data['categorized_questions'].keys);
        }
      }
    } catch (e) {
      print('Error loading questions: $e');
      _questionData = {"categorized_questions": {}};
      _categories = [];
    }
  }

  // Get all available categories
  static List<String> getCategories() {
    return _categories;
  }

  // Get questions for a specific category
  static List<Map<String, dynamic>> getQuestionsByCategory(String category) {
    if (_questionData == null ||
        !_questionData!.containsKey('categorized_questions')) {
      return [];
    }

    final categoryQuestions = _questionData!['categorized_questions'][category];
    if (categoryQuestions == null) {
      return [];
    }

    return List<Map<String, dynamic>>.from(categoryQuestions);
  }

  // Get all questions across all categories
  static List<Map<String, dynamic>> getAllQuestions() {
    List<Map<String, dynamic>> allQuestions = [];

    if (_questionData == null ||
        !_questionData!.containsKey('categorized_questions')) {
      return [];
    }

    _questionData!['categorized_questions'].forEach((category, questions) {
      allQuestions.addAll(List<Map<String, dynamic>>.from(questions));
    });

    return allQuestions;
  }

  // Get random questions from all categories
  static List<Map<String, dynamic>> getRandomQuestions(int count) {
    final allQuestions = getAllQuestions();
    if (allQuestions.isEmpty) {
      return [];
    }

    // Shuffle the questions
    allQuestions.shuffle();

    // Return the requested number or all if count is greater than available questions
    return allQuestions
        .take(count < allQuestions.length ? count : allQuestions.length)
        .toList();
  }

  // Get random questions from a specific category
  static List<Map<String, dynamic>> getRandomQuestionsByCategory(
      String category, int count) {
    final categoryQuestions = getQuestionsByCategory(category);
    if (categoryQuestions.isEmpty) {
      return [];
    }

    // Shuffle the questions
    categoryQuestions.shuffle();

    // Return the requested number or all if count is greater
    return categoryQuestions
        .take(
            count < categoryQuestions.length ? count : categoryQuestions.length)
        .toList();
  }
}
