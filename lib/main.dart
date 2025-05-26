import 'package:flutter/material.dart';
import 'package:satexam/screens/progress_screen.dart';
import 'package:satexam/screens/quiz_screen.dart';
import 'package:satexam/screens/flashcards_screen.dart';
import 'package:satexam/screens/mock_exam_screen.dart';
import 'package:satexam/screens/home_screen.dart';
import 'package:satexam/screens/welcome_screen.dart';
import 'package:satexam/screens/splash_screen.dart';
import 'utils/user_preferences.dart';
import 'utils/progress_service.dart';
import 'utils/question_service.dart';
import 'utils/ad_helper.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Mobile Ads SDK
  await AdHelper.initialize();

  // Load questions data
  await QuestionService.loadQuestions();

  // Initialize progress data
  await ProgressService.initializeProgressData();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isFirstLaunch = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final isFirstLaunch = await UserPreferences.isFirstLaunch();

    setState(() {
      _isFirstLaunch = isFirstLaunch;
      _isLoading = false;
    });
  }

  void _onWelcomeComplete() {
    setState(() {
      _isFirstLaunch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAT Exam Prep 2025',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1976D2),
        ),
      ),
      home: _isLoading
          ? const SplashScreen()
          : _isFirstLaunch
              ? WelcomeScreen(onComplete: _onWelcomeComplete)
              : const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    HomeScreen(),
    QuizScreen(),
    FlashcardsScreen(),
    MockExamScreen(),
    ProgressScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF1976D2),
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.quiz_rounded),
            label: 'Quizzes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.style_rounded),
            label: 'Flashcards',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_rounded),
            label: 'Mock Exam',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_rounded),
            label: 'Progress',
          ),
        ],
      ),
    );
  }
}
