import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'quiz_screen.dart';
import 'flashcards_screen.dart';
import 'mock_exam_screen.dart';
import 'progress_screen.dart';
import '../utils/user_preferences.dart';
import '../utils/progress_service.dart';
import '../utils/question_service.dart';
import '../utils/ad_helper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  bool _isLoading = true;
  double _overallProgress = 0.0;
  int _completedItems = 0;
  double _accuracy = 0.0;
  int _studyTime = 0;
  Map<String, dynamic> _lastActivity = {};
  List<String> _categories = [];

  // Rewarded interstitial ad manager
  final RewardedInterstitialAdManager _rewardedInterstitialAdManager =
      RewardedInterstitialAdManager();

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadRewardedInterstitialAd();
  }

  Future<void> _initializeData() async {
    // Load questions from JSON file
    await QuestionService.loadQuestions();

    // Initialize user data
    await _loadUserData();

    // Initialize progress data
    await _loadProgressData();
  }

  Future<void> _loadUserData() async {
    final name = await UserPreferences.getName();

    setState(() {
      _userName = name ?? 'User';
    });
  }

  Future<void> _loadProgressData() async {
    // Load category data
    _categories = await ProgressService.getCategories();

    // Load progress data
    final progress = await ProgressService.getOverallProgress();
    final completed = await ProgressService.getCompletedItems();
    final accuracy = await ProgressService.getAccuracy();
    final studyTime = await ProgressService.getStudyTime();
    final lastActivity = await ProgressService.getLastActivity();

    setState(() {
      _overallProgress = progress;
      _completedItems = completed;
      _accuracy = accuracy;
      _studyTime = studyTime;
      _lastActivity = lastActivity;
      _isLoading = false;
    });
  }

  void _loadRewardedInterstitialAd() {
    _rewardedInterstitialAdManager.loadAd(
      onUserEarnedReward: (reward) {
        // Handle reward
        _handleReward(reward);
      },
    );
  }

  void _handleReward(RewardItem reward) async {
    // For example, add study time as a reward
    await ProgressService.addStudyTime(reward.amount.toInt());
    await _loadProgressData();

    if (!mounted) return;

    // Show a snackbar to inform the user
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
  void dispose() {
    _rewardedInterstitialAdManager.dispose();
    super.dispose();
  }

  String _formatTimeAgo(int timestamp) {
    final now = DateTime.now();
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set system overlay style for status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadProgressData();
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App Header with Logo and Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E88E5).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SAT EXAM PRACTICE',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E88E5),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Exam Prep 2025',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF546E7A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // User Profile Icon
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF1976D2)),
                                  ),
                                ),
                              )
                            : Tooltip(
                                message: _userName,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.person_rounded,
                                    color: Color(0xFF1976D2),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) =>
                                          _buildProfileDialog(context),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // Welcome Message with User Name
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: _isLoading
                      ? const SizedBox.shrink()
                      : Text(
                          'Welcome, $_userName!',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF37474F),
                          ),
                        ),
                ),
              ),

              // Progress Tracker
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Your Progress',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${(_overallProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(
                            value: _overallProgress,
                            minHeight: 10,
                            backgroundColor: Colors.white30,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => QuizScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Continue Learning'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF1976D2),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProgressScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.insights_rounded,
                                  color: Colors.white,
                                ),
                                tooltip: 'View Progress Details',
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                      ],
                    ),
                  ),
                ),
              ),

              // Quick Stats Row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildQuickStat(
                          context,
                          icon: Icons.check_circle_outline_rounded,
                          value: '$_completedItems',
                          label: 'Completed',
                          color: const Color(0xFF66BB6A),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickStat(
                          context,
                          icon: Icons.task_alt_rounded,
                          value: '${(_accuracy * 100).toInt()}%',
                          label: 'Accuracy',
                          color: const Color(0xFF42A5F5),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickStat(
                          context,
                          icon: Icons.access_time_rounded,
                          value: '$_studyTime',
                          label: 'Minutes',
                          color: const Color(0xFFEC407A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tip of the day
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F9FF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFE3F2FD),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.lightbulb_outline,
                            color: Color(0xFF1976D2),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tip of the Day',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF455A64),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'SAT success demands strategy, not just memorization. Master question patterns, time management, and high-scoring techniques.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF607D8B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Last Activity
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Last Activity',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF37474F),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _lastActivity.containsKey('timestamp')
                                    ? _formatTimeAgo(_lastActivity['timestamp'])
                                    : 'Just now',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFEEEEEE),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                _lastActivity['type'] == 'quiz'
                                    ? Icons.quiz_rounded
                                    : _lastActivity['type'] == 'flashcard'
                                        ? Icons.style_rounded
                                        : _lastActivity['type'] == 'exam'
                                            ? Icons.timer_rounded
                                            : Icons.school_rounded,
                                color: const Color(0xFF1976D2),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _lastActivity['title'] ?? 'Welcome',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF37474F),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      if (_lastActivity['score'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF66BB6A)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${(_lastActivity['score'] * 100).toInt()}%',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF43A047),
                                            ),
                                          ),
                                        ),
                                      if (_lastActivity['score'] != null)
                                        const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _lastActivity['detail'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF78909C),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                  color: Color(0xFF1976D2),
                                ),
                                onPressed: () {
                                  if (_lastActivity['type'] == 'quiz') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => QuizScreen(),
                                      ),
                                    );
                                  } else if (_lastActivity['type'] ==
                                      'flashcard') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            FlashcardsScreen(),
                                      ),
                                    );
                                  } else if (_lastActivity['type'] == 'exam') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MockExamScreen(),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main Features Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 15, 20, 5),
                  child: Text(
                    'Exam Resources',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF37474F),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

              // Main Features Grid
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildFeatureCard(
                      context,
                      title: 'Quizzes',
                      subtitle: 'Test your knowledge',
                      icon: Icons.quiz_rounded,
                      color: const Color(0xFF1976D2),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuizScreen(),
                          ),
                        );
                      },
                    ),
                    _buildFeatureCard(
                      context,
                      title: 'Flashcards',
                      subtitle: 'Quick review',
                      icon: Icons.style_rounded,
                      color: const Color(0xFF26A69A),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FlashcardsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildFeatureCard(
                      context,
                      title: 'Mock Exams',
                      subtitle: 'Full practice',
                      icon: Icons.timer_rounded,
                      color: const Color(0xFF7E57C2),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MockExamScreen(),
                          ),
                        );
                      },
                    ),
                    _buildFeatureCard(
                      context,
                      title: 'Profile',
                      subtitle: 'Your account',
                      icon: Icons.person_rounded,
                      color: const Color(0xFF78909C),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => _buildProfileDialog(context),
                        );
                      },
                    ),
                  ]),
                ),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFEEEEEE),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 22,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF78909C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFEEEEEE),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF37474F),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF78909C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Profile Dialog Widget
  Widget _buildProfileDialog(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile Header
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF1976D2),
                    size: 40,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF37474F),
                        ),
                      ),
                      Text(
                        'SAT Learner',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Progress Statistics
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF37474F),
                        ),
                      ),
                      Text(
                        '${(_overallProgress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _overallProgress,
                      minHeight: 8,
                      backgroundColor: Colors.white,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF1976D2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      _buildStatItem(
                        icon: Icons.check_circle_outline_rounded,
                        value: '$_completedItems',
                        label: 'Completed',
                        color: const Color(0xFF66BB6A),
                      ),
                      _buildStatItem(
                        icon: Icons.access_time_rounded,
                        value: '$_studyTime',
                        label: 'Minutes',
                        color: const Color(0xFFEC407A),
                      ),
                      _buildStatItem(
                        icon: Icons.task_alt_rounded,
                        value: '${(_accuracy * 100).toInt()}%',
                        label: 'Accuracy',
                        color: const Color(0xFF42A5F5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Settings Options
            _buildSettingsOption(
              icon: Icons.edit_rounded,
              title: 'Edit Profile',
              onTap: () {
                Navigator.pop(context);
                _showEditProfileDialog(context);
              },
            ),
            const Divider(height: 1),
            _buildSettingsOption(
              icon: Icons.info_outline_rounded,
              title: 'About App',
              onTap: () {
                Navigator.pop(context);
                _showAboutAppDialog(context);
              },
            ),
            const SizedBox(height: 20),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for profile stats
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF37474F),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for settings options
  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1976D2), size: 22),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF37474F),
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFBDBDBD),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Edit Profile Dialog
  void _showEditProfileDialog(BuildContext context) {
    final nameController = TextEditingController(text: _userName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && newName != _userName) {
                await UserPreferences.setName(newName);
              }

              if (!mounted) return;
              Navigator.pop(context);

              setState(() {
                _userName = newName.isNotEmpty ? newName : _userName;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // About App Dialog
  void _showAboutAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About SAT Practice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'SAT Practice',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'This app helps you prepare for your SAT Exam with practice questions, flashcards, and mock exams.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
