import 'dart:async';
import 'package:flutter/material.dart';
import 'package:satexam/screens/home_screen.dart';
import 'package:satexam/screens/quiz_screen.dart';
import '../utils/question_service.dart';
import '../utils/progress_service.dart';
import '../utils/category_utils.dart';
import '../utils/ad_helper.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../widgets/banner_ad_widget.dart';

import '../main.dart';

class ExamQuestion {
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final String category;

  ExamQuestion(this.question, this.options, this.correctAnswerIndex,
      {this.explanation = '', this.category = 'General'});

  // Create from JSON
  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    return ExamQuestion(
      json['question'],
      List<String>.from(json['options']),
      json['correctAnswer'],
      explanation: json['explanation'] ?? '',
      category: json['category'],
    );
  }
}

class MockExamScreen extends StatefulWidget {
  @override
  _MockExamScreenState createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen>
    with SingleTickerProviderStateMixin {
  // Exam data
  List<ExamQuestion> questions = [];
  bool _isLoading = true;

  // Timer variables
  int _totalTimeInSeconds = 60 * 60; // 60 minutes
  int _timeRemaining = 60 * 60;
  late Timer _timer;
  bool _examStarted = false;
  bool _examCompleted = false;

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  // Current question index and answers
  int _currentQuestionIndex = 0;
  List<int?> _userAnswers = [];

  // Ad managers
  final RewardedInterstitialAdManager _rewardedInterstitialAdManager =
      RewardedInterstitialAdManager();
  bool _adShown = false;

  @override
  void initState() {
    super.initState();
    _loadExamQuestions();

    // Load a rewarded interstitial ad
    _loadRewardedInterstitialAd();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );

    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  Future<void> _loadExamQuestions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load questions from JSON file
      await QuestionService.loadQuestions();

      // Get random questions from all categories for a comprehensive exam
      final examQuestions = QuestionService.getRandomQuestions(50);

      // Convert to ExamQuestion objects
      questions = examQuestions.map((q) => ExamQuestion.fromJson(q)).toList();

      // Fallback if no questions were loaded
      if (questions.isEmpty) {
        questions = [
          ExamQuestion(
            'No questions available. Please check your connection and try again.',
            ['OK'],
            0,
            explanation: 'The app could not load any questions.',
            category: 'General',
          )
        ];
      }

      _userAnswers = List.filled(questions.length, null);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Handle any exceptions
      questions = [
        ExamQuestion(
          'Error loading questions: ${e.toString()}',
          ['OK'],
          0,
          explanation: 'Please check your connection and try again.',
          category: 'General',
        )
      ];
      _userAnswers = List.filled(questions.length, null);

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadRewardedInterstitialAd() {
    _rewardedInterstitialAdManager.loadAd(
      onUserEarnedReward: (reward) => _handleReward(reward),
    );
  }

  @override
  void dispose() {
    if (_examStarted && !_examCompleted) {
      _timer.cancel();
    }
    _animationController.dispose();
    _rewardedInterstitialAdManager.dispose();
    super.dispose();
  }

  void _startExam() {
    setState(() {
      _examStarted = true;
      _startTimer();
      _animationController.forward();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
        } else {
          _timer.cancel();
          _examCompleted = true;
          _showResults();
        }
      });
    });
  }

  void _selectAnswer(int answerIndex) {
    // Safety check to prevent out of bounds access
    if (questions.isEmpty ||
        _currentQuestionIndex >= questions.length ||
        _currentQuestionIndex >= _userAnswers.length) {
      return;
    }

    setState(() {
      _userAnswers[_currentQuestionIndex] = answerIndex;
    });
  }

  void _nextQuestion() {
    // Safety check to prevent out of bounds access
    if (questions.isEmpty) {
      return;
    }

    if (_currentQuestionIndex < questions.length - 1) {
      setState(() {
        _animationController.reset();
        _currentQuestionIndex++;
        _animationController.forward();
      });
    } else {
      _finishExam();
    }
  }

  void _previousQuestion() {
    // Safety check to prevent out of bounds access
    if (questions.isEmpty) {
      return;
    }

    if (_currentQuestionIndex > 0) {
      setState(() {
        _animationController.reset();
        _currentQuestionIndex--;
        _animationController.forward();
      });
    }
  }

  void _finishExam() {
    if (_examStarted && !_examCompleted) {
      _timer.cancel();
    }

    setState(() {
      _examCompleted = true;
    });

    _showResults();
  }

  Future<void> _showResults() async {
    try {
      // Safety check - make sure we have questions to show results for
      if (questions.isEmpty) {
        setState(() {
          _examCompleted = false;
          _examStarted = false;
        });

        // Show an error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No questions available to show results'),
            duration: Duration(seconds: 3),
          ),
        );

        return;
      }

      // Record a mock exam completion
      final score = _calculateScore() / questions.length;
      await ProgressService.recordActivity(
        title: 'Mock Exam',
        type: 'exam',
        detail: 'Completed with ${(score * 100).toInt()}% score',
        score: score,
      );

      // Add study time
      int minutesSpent = (_totalTimeInSeconds - _timeRemaining) ~/ 60;
      await ProgressService.addStudyTime(minutesSpent);

      if (!mounted) return;

      // Show a rewarded interstitial ad if available
      _showRewardedInterstitialAd();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ExamResultsScreen(
            questions: questions,
            userAnswers: _userAnswers,
            timeUsed: _totalTimeInSeconds - _timeRemaining,
            totalTime: _totalTimeInSeconds,
            onReturnToExam: () {
              // Reset the exam
              setState(() {
                _currentQuestionIndex = 0;
                _userAnswers = List.filled(questions.length, null);
                _timeRemaining = _totalTimeInSeconds;
                _examStarted = false;
                _examCompleted = false;
                _adShown = false;
              });

              // Load a new interstitial ad for next time
              _loadRewardedInterstitialAd();
            },
          ),
        ),
      );
    } catch (e) {
      // Handle any errors
      setState(() {
        _examCompleted = false;
        _examStarted = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error showing results: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showRewardedInterstitialAd() {
    if (!_adShown && _rewardedInterstitialAdManager.isAdLoaded) {
      _rewardedInterstitialAdManager.showAd(
        onUserEarnedReward: (reward) => _handleReward(reward),
      );
      _adShown = true;
      // Preload next ad
      _loadRewardedInterstitialAd();
    }
  }

  int _calculateScore() {
    if (questions.isEmpty) return 0;

    int correctAnswers = 0;
    for (int i = 0; i < questions.length; i++) {
      if (i < _userAnswers.length &&
          _userAnswers[i] != null &&
          _userAnswers[i] == questions[i].correctAnswerIndex) {
        correctAnswers++;
      }
    }
    return correctAnswers;
  }

  String _formatTime(int timeInSeconds) {
    int minutes = timeInSeconds ~/ 60;
    int seconds = timeInSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _handleReward(RewardItem reward) async {
    // Add study time as a reward for completing the exam
    await ProgressService.addStudyTime(reward.amount.toInt());

    // Show a confirmation message
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('You earned ${reward.amount.toInt()} minutes of study time!'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: _examStarted && !_examCompleted
          ? AppBar(
              title: const Text('Mock Exam'),
              leading: IconButton(
                icon: const FaIcon(FontAwesomeIcons.xmark),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Quit Exam?'),
                        content: const Text(
                            'Your progress will be lost. Are you sure you want to quit?'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const MainNavigation()),
                              );
                            },
                            child: const Text('QUIT'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              actions: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.stopwatch,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(_timeRemaining),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : AppBar(
              title: const Text('Mock Exam'),
              actions: [
                if (!_isLoading)
                  TextButton.icon(
                    icon: const FaIcon(
                      FontAwesomeIcons.arrowsRotate,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'New Exam',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: _loadExamQuestions,
                  ),
              ],
            ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading exam questions...'),
                      ],
                    ),
                  )
                : _examStarted
                    ? _examCompleted
                        ? Container() // This should never show as we navigate to results page
                        : Column(
                            children: [
                              // Progress indicator
                              LinearProgressIndicator(
                                value: (_currentQuestionIndex + 1) /
                                    questions.length,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.indigo.shade600),
                              ),

                              // Question counter
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      'Answered: ${_userAnswers.where((a) => a != null).length} of ${questions.length}',
                                      style: TextStyle(
                                          color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              ),

                              // Current question
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: AnimatedBuilder(
                                    animation: _animationController,
                                    builder: (context, child) {
                                      return FadeTransition(
                                        opacity: _progressAnimation,
                                        child: Transform.translate(
                                          offset: Offset(
                                              0,
                                              20 *
                                                  (1 -
                                                      _progressAnimation
                                                          .value)), // Slide up
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _buildExamQuestionCard(),
                                  ),
                                ),
                              ),

                              // Navigation buttons
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _currentQuestionIndex > 0
                                          ? _previousQuestion
                                          : null,
                                      icon: const FaIcon(
                                          FontAwesomeIcons.arrowLeft,
                                          size: 16),
                                      label: const Text('Previous'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _currentQuestionIndex <
                                              questions.length - 1
                                          ? _nextQuestion
                                          : _finishExam,
                                      icon: FaIcon(
                                          _currentQuestionIndex <
                                                  questions.length - 1
                                              ? FontAwesomeIcons.arrowRight
                                              : FontAwesomeIcons.check,
                                          size: 16),
                                      label: Text(_currentQuestionIndex <
                                              questions.length - 1
                                          ? 'Next'
                                          : 'Finish'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        backgroundColor: Colors.indigo.shade600,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Banner Ad when answering questions
                              const BannerAdWidget(),
                            ],
                          )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.stopwatch,
                                size: 70,
                                color: Colors.indigo,
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'SAT Mock Exam',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${questions.length} questions • ${_totalTimeInSeconds ~/ 60} minutes',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 32),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'This mock exam simulates the actual SAT certification exam. Answer all questions within the time limit to see your score.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                              ElevatedButton.icon(
                                onPressed: _startExam,
                                icon: const FaIcon(FontAwesomeIcons.play),
                                label: const Text('START EXAM'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 16),
                                  backgroundColor: Colors.indigo.shade600,
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
          // Banner Ad at the bottom (only on welcome screen)
          if (!_examStarted && !_examCompleted) const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildExamQuestionCard() {
    // Safety check - if questions is empty or index is out of bounds
    if (questions.isEmpty || _currentQuestionIndex >= questions.length) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'No questions available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadExamQuestions,
                icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 16),
                label: const Text('Reload Questions'),
              ),
            ],
          ),
        ),
      );
    }

    final question = questions[_currentQuestionIndex];
    final categoryColor = CategoryUtils.getCategoryColor(question.category);
    final categoryIcon = CategoryUtils.getCategoryIcon(question.category);

    // Ensure options list is not empty
    final optionsList = question.options.isNotEmpty
        ? question.options
        : ['No options available'];

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _progressAnimation.value,
          child: Opacity(
            opacity: _progressAnimation.value,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category label
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: categoryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CategoryUtils.getFontAwesomeIcon(
                                question.category,
                                size: 16,
                                color: categoryColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                question.category,
                                style: TextStyle(
                                  color: categoryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Question
                    Text(
                      question.question,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...List.generate(
                      optionsList.length,
                      (index) {
                        // Protect against index out of bounds
                        final isSelected =
                            _userAnswers.length > _currentQuestionIndex &&
                                _userAnswers[_currentQuestionIndex] == index;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _selectAnswer(index),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.indigo.shade600
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: isSelected
                                    ? Colors.indigo.shade50
                                    : Colors.white,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.indigo.shade600
                                            : Colors.grey.shade400,
                                        width: 2,
                                      ),
                                      color: isSelected
                                          ? Colors.indigo.shade600
                                          : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Center(
                                            child: FaIcon(
                                              FontAwesomeIcons.check,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      optionsList[index],
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isSelected
                                            ? Colors.indigo.shade800
                                            : Colors.grey.shade800,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ExamResultsScreen extends StatefulWidget {
  final List<ExamQuestion> questions;
  final List<int?> userAnswers;
  final int timeUsed;
  final int totalTime;
  final VoidCallback onReturnToExam;

  const ExamResultsScreen({
    Key? key,
    required this.questions,
    required this.userAnswers,
    required this.timeUsed,
    required this.totalTime,
    required this.onReturnToExam,
  }) : super(key: key);

  @override
  _ExamResultsScreenState createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.arrowLeft),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onReturnToExam();
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Exam Results',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildResultSummary(context),
                    const SizedBox(height: 24),
                    Text(
                      'Question Review',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: widget.questions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const FaIcon(
                                    FontAwesomeIcons.circleExclamation,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No questions to review',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Try taking another exam',
                                    style: TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: widget.questions.length,
                              itemBuilder: (context, index) {
                                if (index >= widget.questions.length) {
                                  return const SizedBox
                                      .shrink(); // Safety check
                                }

                                final bool hasUserAnswer =
                                    index < widget.userAnswers.length &&
                                        widget.userAnswers[index] != null;
                                final bool isCorrect = hasUserAnswer &&
                                    widget.userAnswers[index] ==
                                        widget.questions[index]
                                            .correctAnswerIndex;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: hasUserAnswer
                                          ? (isCorrect
                                              ? Colors.green.shade300
                                              : Colors.red.shade300)
                                          : Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: hasUserAnswer
                                                  ? (isCorrect
                                                      ? Colors.green.shade100
                                                      : Colors.red.shade100)
                                                  : Colors.grey.shade100,
                                              child: FaIcon(
                                                hasUserAnswer
                                                    ? (isCorrect
                                                        ? FontAwesomeIcons.check
                                                        : FontAwesomeIcons
                                                            .xmark)
                                                    : FontAwesomeIcons.question,
                                                color: hasUserAnswer
                                                    ? (isCorrect
                                                        ? Colors.green
                                                        : Colors.red)
                                                    : Colors.grey,
                                                size: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Question ${index + 1}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          widget.questions[index].question,
                                          style: const TextStyle(fontSize: 15),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: hasUserAnswer
                                                ? (isCorrect
                                                    ? Colors.green.shade50
                                                    : Colors.red.shade50)
                                                : Colors.grey.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                hasUserAnswer
                                                    ? 'Your answer: ${widget.questions[index].options[widget.userAnswers[index]!]}'
                                                    : 'Not answered',
                                                style: TextStyle(
                                                  color: hasUserAnswer
                                                      ? (isCorrect
                                                          ? Colors
                                                              .green.shade700
                                                          : Colors.red.shade700)
                                                      : Colors.grey.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (!isCorrect ||
                                                  !hasUserAnswer) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Correct answer: ${widget.questions[index].options[widget.questions[index].correctAnswerIndex]}',
                                                  style: TextStyle(
                                                    color:
                                                        Colors.green.shade700,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onReturnToExam();
                },
                icon: const FaIcon(FontAwesomeIcons.arrowsRotate),
                label: const Text('Take New Exam'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSummary(BuildContext context) {
    int score = _calculateScore();
    int totalQuestions = widget.questions.isEmpty
        ? 1
        : widget.questions.length; // Prevent division by zero
    double percentage = (score / totalQuestions) * 100;
    bool passed = percentage >= 70;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: passed ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: passed ? Colors.green.shade200 : Colors.red.shade200,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(
                passed
                    ? FontAwesomeIcons.circleCheck
                    : FontAwesomeIcons.circleXmark,
                color: passed ? Colors.green : Colors.red,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                passed ? 'PASSED' : 'FAILED',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: passed ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildResultItem('Score', '$score/$totalQuestions'),
              _buildDivider(),
              _buildResultItem(
                  'Percentage', '${percentage.toStringAsFixed(1)}%'),
              _buildDivider(),
              _buildResultItem('Time Used', _formatTime(widget.timeUsed)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildResultItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  int _calculateScore() {
    if (widget.questions.isEmpty) return 0;

    int correctAnswers = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      if (i < widget.userAnswers.length &&
          widget.userAnswers[i] != null &&
          widget.userAnswers[i] == widget.questions[i].correctAnswerIndex) {
        correctAnswers++;
      }
    }
    return correctAnswers;
  }

  String _formatTime(int timeInSeconds) {
    int minutes = timeInSeconds ~/ 60;
    int seconds = timeInSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
