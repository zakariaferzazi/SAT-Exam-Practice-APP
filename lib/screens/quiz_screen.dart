import 'package:flutter/material.dart';
import 'dart:math';
import '../utils/question_service.dart';
import '../utils/progress_service.dart';
import '../utils/category_utils.dart';
import '../widgets/banner_ad_widget.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/ad_helper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class Quiz {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String category;
  bool isBookmarked;

  Quiz({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.category,
    this.isBookmarked = false,
  });

  // Create Quiz from JSON data
  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      question: json['question'],
      options: List<String>.from(json['options']),
      correctIndex: json['correctAnswer'],
      explanation: json['explanation'] ?? 'No explanation available',
      category: json['category'],
    );
  }
}

class QuizScreen extends StatefulWidget {
  final String? category;

  const QuizScreen({this.category, super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  late List<Quiz> _quizzes;
  int _currentQuiz = 0;
  int? _selectedOption;
  bool _showExplanation = false;
  int _score = 0;
  List<int?> _userAnswers = [];
  bool _quizFinished = false;
  bool _isLoading = true;
  List<String> _categories = [];
  String? _selectedCategory;

  // Animation controllers
  late AnimationController _cardAnimationController;
  late AnimationController _optionsAnimationController;
  late AnimationController _explanationAnimationController;
  late Animation<double> _cardAnimation;

  // Ad manager
  final RewardedInterstitialAdManager _rewardedInterstitialAdManager =
      RewardedInterstitialAdManager();
  bool _adShown = false;

  // Color scheme
  final Color _primaryColor = const Color(0xFF6200EE);
  final Color _secondaryColor = const Color(0xFF03DAC6);
  final Color _correctColor = const Color(0xFF4CAF50);
  final Color _incorrectColor = const Color(0xFFF44336);
  final Color _neutralColor = const Color(0xFFF5F5F5);
  final Color _bookmarkColor = const Color(0xFFFFB300);

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _optionsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _explanationAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _cardAnimation = CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeInOutBack,
    );

    _selectedCategory = widget.category;
    _loadQuizzes();
    _loadRewardedInterstitialAd();
  }

  void _loadRewardedInterstitialAd() {
    _rewardedInterstitialAdManager.loadAd(
      onUserEarnedReward: (reward) {
        // Handle reward if needed
      },
    );
  }

  Future<void> _loadQuizzes() async {
    setState(() {
      _isLoading = true;
    });

    // Load questions from JSON file
    await QuestionService.loadQuestions();

    // Get categories
    _categories = QuestionService.getCategories();

    // If no specific category was provided, use the first one or get random questions
    if (_selectedCategory == null && _categories.isNotEmpty) {
      _selectedCategory = _categories[0];
    }

    // Load questions based on category
    List<Map<String, dynamic>> questions;
    if (_selectedCategory != null) {
      questions =
          QuestionService.getRandomQuestionsByCategory(_selectedCategory!, 10);
    } else {
      questions = QuestionService.getRandomQuestions(10);
    }

    // Convert to Quiz objects
    _quizzes = questions.map((q) => Quiz.fromJson(q)).toList();

    if (_quizzes.isEmpty) {
      // Fallback if no questions found
      _quizzes = [
        Quiz(
          question: 'No questions available Because of What?',
          options: ['Because of the internet'],
          correctIndex: 0,
          explanation: 'Please try to fix internet connection in your device',
          category: 'Error',
        )
      ];
    }

    _userAnswers = List<int?>.filled(_quizzes.length, null);

    setState(() {
      _isLoading = false;
    });

    _resetQuiz();
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    _optionsAnimationController.dispose();
    _explanationAnimationController.dispose();
    _rewardedInterstitialAdManager.dispose();
    super.dispose();
  }

  void _resetQuiz() {
    setState(() {
      _currentQuiz = 0;
      _selectedOption = null;
      _showExplanation = false;
      _score = 0;
      _quizFinished = false;
      _adShown = false;
      _userAnswers = List<int?>.filled(_quizzes.length, null);
    });
    _startQuizAnimations();
  }

  void _startQuizAnimations() {
    _cardAnimationController.reset();
    _optionsAnimationController.reset();

    _cardAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _optionsAnimationController.forward();
    });
  }

  void _selectOption(int index) {
    if (_selectedOption != null) return;
    setState(() {
      _selectedOption = index;
      _userAnswers[_currentQuiz] = index;
      if (index == _quizzes[_currentQuiz].correctIndex) {
        _score++;
      }
    });

    // Wait a moment before showing explanation
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _showExplanation = true;
      });
      _explanationAnimationController.forward();
    });
  }

  Future<void> _nextQuiz() async {
    // Slide out current quiz
    _cardAnimationController.reverse();

    await Future.delayed(const Duration(milliseconds: 300));

    if (_currentQuiz < _quizzes.length - 1) {
      setState(() {
        _currentQuiz++;
        _selectedOption = null;
        _showExplanation = false;
        _explanationAnimationController.reset();
      });

      // Slide in next quiz
      _cardAnimationController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        _optionsAnimationController.forward();
      });
    } else {
      setState(() {
        _quizFinished = true;
        _adShown = false;
      });
      _cardAnimationController.forward();

      // Record progress for this quiz session
      if (_selectedCategory != null) {
        final scorePercent = _score / _quizzes.length;
        await ProgressService.completeItem(_selectedCategory!, scorePercent);
      }

      // Show rewarded interstitial ad when quiz finishes
      Future.delayed(const Duration(milliseconds: 500), () {
        _showRewardedInterstitialAd();
      });
    }
  }

  void _showRewardedInterstitialAd() {
    if (!_adShown && _rewardedInterstitialAdManager.isAdLoaded) {
      _rewardedInterstitialAdManager.showAd();
      _adShown = true;
      // Preload next ad
      _loadRewardedInterstitialAd();
    }
  }

  void _toggleBookmark() {
    setState(() {
      _quizzes[_currentQuiz].isBookmarked =
          !_quizzes[_currentQuiz].isBookmarked;
    });
  }

  Widget _buildProgressBar() {
    return Container(
      height: 10,
      width: double.infinity,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _quizzes.length,
        itemBuilder: (context, index) {
          bool isAnswered = _userAnswers[index] != null;
          bool isCurrent = index == _currentQuiz;

          return Container(
            width: MediaQuery.of(context).size.width / _quizzes.length,
            decoration: BoxDecoration(
              color: isAnswered
                  ? _primaryColor
                  : isCurrent
                      ? _secondaryColor
                      : Colors.grey.shade300,
              border: index < _quizzes.length - 1
                  ? Border(
                      right: BorderSide(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuizCard() {
    final quiz = _quizzes[_currentQuiz];
    final categoryColor = CategoryUtils.getCategoryColor(quiz.category);

    return AnimatedBuilder(
      animation: _cardAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(200 * (1 - _cardAnimation.value), 0),
          child: Opacity(
            opacity: _cardAnimation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [categoryColor, categoryColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Q${_currentQuiz + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 6),
                            CategoryUtils.getFontAwesomeIcon(
                              quiz.category,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: FaIcon(
                          quiz.isBookmarked
                              ? FontAwesomeIcons.solidBookmark
                              : FontAwesomeIcons.bookmark,
                          color:
                              quiz.isBookmarked ? _bookmarkColor : Colors.white,
                          size: 18,
                        ),
                        onPressed: _toggleBookmark,
                        tooltip:
                            quiz.isBookmarked ? 'Remove Bookmark' : 'Bookmark',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    quiz.question,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ..._buildOptionsList(quiz),
          if (_showExplanation) _buildExplanation(quiz),
        ],
      ),
    );
  }

  List<Widget> _buildOptionsList(Quiz quiz) {
    return List.generate(
      quiz.options.length,
      (i) => AnimatedBuilder(
        animation: _optionsAnimationController,
        builder: (context, child) {
          // Stagger the animations
          final delay = i * 0.2;
          final start = delay;
          final end = start + 0.8;

          final animValue = _optionsAnimationController.value;
          final opacity = animValue < start
              ? 0.0
              : animValue > end
                  ? 1.0
                  : (animValue - start) / (end - start);

          final slideOffset = 50.0 * (1.0 - opacity);

          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, slideOffset),
              child: child,
            ),
          );
        },
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: _buildOptionButton(i, quiz),
        ),
      ),
    );
  }

  Widget _buildOptionButton(int i, Quiz quiz) {
    final categoryColor = CategoryUtils.getCategoryColor(quiz.category);
    final isCorrect = i == quiz.correctIndex;
    final isSelected = _selectedOption == i;
    final isAnswered = _selectedOption != null;

    Color backgroundColor;
    Color textColor;
    Color borderColor;

    if (!isAnswered) {
      backgroundColor = _neutralColor;
      textColor = categoryColor;
      borderColor = categoryColor.withOpacity(0.3);
    } else if (isCorrect) {
      backgroundColor = _correctColor.withOpacity(isSelected ? 1.0 : 0.1);
      textColor = isSelected ? Colors.white : _correctColor;
      borderColor = _correctColor;
    } else if (isSelected) {
      backgroundColor = _incorrectColor;
      textColor = Colors.white;
      borderColor = _incorrectColor;
    } else {
      backgroundColor = _neutralColor;
      textColor = Colors.black87;
      borderColor = Colors.transparent;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          if (isAnswered && (isCorrect || isSelected))
            BoxShadow(
              color: (isCorrect ? _correctColor : _incorrectColor)
                  .withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAnswered ? null : () => _selectOption(i),
          borderRadius: BorderRadius.circular(12),
          splashColor: categoryColor.withOpacity(0.1),
          highlightColor: categoryColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isAnswered
                        ? (isCorrect
                            ? _correctColor
                            : (isSelected ? _incorrectColor : Colors.white))
                        : Colors.white,
                    border: Border.all(
                      color: isAnswered
                          ? (isCorrect
                              ? _correctColor
                              : (isSelected
                                  ? _incorrectColor
                                  : categoryColor.withOpacity(0.5)))
                          : categoryColor.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isAnswered
                        ? FaIcon(
                            isCorrect
                                ? FontAwesomeIcons.check
                                : (isSelected ? FontAwesomeIcons.xmark : null),
                            color: Colors.white,
                            size: 14,
                          )
                        : Text(
                            String.fromCharCode(65 + i), // A, B, C, D...
                            style: TextStyle(
                              color: categoryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    quiz.options[i],
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExplanation(Quiz quiz) {
    final categoryColor = CategoryUtils.getCategoryColor(quiz.category);

    return AnimatedBuilder(
      animation: _explanationAnimationController,
      builder: (context, child) {
        return Opacity(
          opacity: _explanationAnimationController.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _explanationAnimationController.value)),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: categoryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.lightbulb,
                      color: categoryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Explanation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  quiz.explanation,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _nextQuiz,
            style: ElevatedButton.styleFrom(
              backgroundColor: categoryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentQuiz < _quizzes.length - 1
                      ? 'Next Question'
                      : 'See Results',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                FaIcon(
                  _currentQuiz < _quizzes.length - 1
                      ? FontAwesomeIcons.arrowRight
                      : FontAwesomeIcons.chartSimple,
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsPage() {
    final categoryColor = CategoryUtils.getCategoryColor(_selectedCategory);
    int correct = _score;
    int total = _quizzes.length;
    double percent = (correct / total) * 100;

    String resultMessage;
    Color resultColor;
    IconData resultIcon;

    if (percent >= 85) {
      resultMessage = 'Outstanding!';
      resultColor = Colors.amber.shade600; // Gold
      resultIcon = FontAwesomeIcons.trophy;
    } else if (percent >= 70) {
      resultMessage = 'Great job!';
      resultColor = categoryColor;
      resultIcon = FontAwesomeIcons.solidStar;
    } else if (percent >= 50) {
      resultMessage = 'Good effort!';
      resultColor = Colors.blue.shade400;
      resultIcon = FontAwesomeIcons.thumbsUp;
    } else {
      resultMessage = 'Keep practicing!';
      resultColor = _incorrectColor;
      resultIcon = FontAwesomeIcons.arrowsRotate;
    }

    return AnimatedBuilder(
      animation: _cardAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _cardAnimation.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.8 + (0.2 * _cardAnimation.value),
            child: child,
          ),
        );
      },
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Confetti animation would be here if using a confetti package
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: resultColor.withOpacity(0.2),
                      ),
                      child: Center(
                        child: FaIcon(
                          resultIcon,
                          size: 50,
                          color: resultColor,
                        ),
                      )),
                  const SizedBox(height: 24),
                  Text(
                    resultMessage,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: categoryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: percent / 100),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutCubic,
                    builder: (context, double value, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 150,
                            height: 150,
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 12,
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                percent >= 70
                                    ? _correctColor
                                    : (percent >= 50
                                        ? Colors.blue.shade400
                                        : _incorrectColor),
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '${percent.toInt()}%',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$correct / $total',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _resetQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: categoryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.arrowsRotate, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Try Again',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      // Here you could implement a review incorrect answers feature
                      // For now, just restart the quiz
                      _resetQuiz();
                    },
                    child: Text(
                      'Review Answers',
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = CategoryUtils.getCategoryColor(_selectedCategory);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: categoryColor.withOpacity(0.9),
        title: Row(
          children: [
            Flexible(
              child: CategoryUtils.getFontAwesomeIcon(_selectedCategory,
                  size: 20, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Quiz',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
        actions: [
          Chip(
            avatar: CircleAvatar(
              backgroundColor: Colors.white,
              child: CategoryUtils.getFontAwesomeIcon(
                _selectedCategory,
                size: 14,
                color: categoryColor,
              ),
            ),
            label: Text(
              _selectedCategory ?? 'All',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: categoryColor,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.rotate,
                color: Colors.white, size: 18),
            onPressed: _loadQuizzes,
            tooltip: 'Load New Questions',
          ),
          PopupMenuButton<String>(
            icon: const FaIcon(FontAwesomeIcons.filter,
                color: Colors.white, size: 18),
            tooltip: 'Filter by Category',
            onSelected: (String category) {
              setState(() {
                _selectedCategory = category;
              });
              _loadQuizzes();
            },
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  enabled: false,
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Text(
                    'Select Category',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                ..._categories.map((String category) {
                  final isSelected = category == _selectedCategory;
                  final categoryColor =
                      CategoryUtils.getCategoryColor(category);

                  return PopupMenuItem<String>(
                    value: category,
                    height: 48,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? categoryColor
                                : categoryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: CategoryUtils.getFontAwesomeIcon(
                            category,
                            size: 14,
                            color: isSelected ? Colors.white : categoryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          category,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? categoryColor : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          FaIcon(
                            FontAwesomeIcons.check,
                            color: categoryColor,
                            size: 14,
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: categoryColor),
                        const SizedBox(height: 16),
                        const Text(
                          'Loading questions...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _quizFinished
                    ? _buildResultsPage()
                    : Column(
                        children: [
                          SizedBox(
                            height: 10,
                          ),
                          // Category selector
                          CategoryUtils.buildCategoryChipsList(
                            categories: _categories,
                            selectedCategory: _selectedCategory,
                            onCategorySelected: (category) {
                              setState(() {
                                _selectedCategory = category;
                              });
                              _loadQuizzes();
                            },
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          _buildProgressBar(),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 24.0, horizontal: 16),
                                child: _buildQuizCard(),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),

          // Banner Ad at the bottom
          const BannerAdWidget(),
        ],
      ),
    );
  }
}
