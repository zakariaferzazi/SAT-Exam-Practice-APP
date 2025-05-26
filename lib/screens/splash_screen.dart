import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../utils/ad_helper.dart';
import '../utils/user_preferences.dart';
import 'welcome_screen.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isLoading = true;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  // App open ad manager
  final AppOpenAdManager _appOpenAdManager = AppOpenAdManager();

  @override
  void initState() {
    super.initState();

    // Initialize video player
    _initializeVideoPlayer();
    _navigateToNextScreen();
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    // Start animation and load app
    _animationController.forward();

    // Load app open ad
    _appOpenAdManager.loadAd();
  }

  void _initializeVideoPlayer() {
    try {
      _videoController =
          VideoPlayerController.asset('assets/videos/loading.mp4')
            ..initialize().then((_) {
              setState(() {
                _videoInitialized = true;
              });
              _videoController!.play();
              _videoController!.setLooping(true);
            }).catchError((error) {
              print('Error initializing video: $error');
              setState(() {
                _videoInitialized = false;
              });
            });
    } catch (e) {
      print('Failed to initialize video controller: $e');
      _videoInitialized = false;
    }
  }

  void _navigateToNextScreen() {
    // Show the app open ad if available
    if (_appOpenAdManager.isAdLoaded) {
      _appOpenAdManager.showAdIfAvailable();
    }

    // Small delay to ensure ad has time to show
    // or continue if no ad is available
    Future.delayed(Duration(seconds: 5), () {
      // Launch the appropriate screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigation()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set system overlay style for status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.blueGrey,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.3,
            ),
            // App logo with animation or video
            _videoInitialized &&
                    _videoController != null &&
                    _videoController!.value.isInitialized
                ? Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: VideoPlayer(_videoController!),
                  )
                : AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: Hero(
                      tag: 'app_logo',
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          color: Colors.white,
                          size: 70,
                        ),
                      ),
                    ),
                  ),

            const SizedBox(height: 32),

            // App name with animation
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: child,
                );
              },
              child: const Column(
                children: [
                  Text(
                    'SAT PRACTICE',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    'Exam Prep 2025',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(child: SizedBox()), // Push loading text to bottom

            // Loading indicator or Start button
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),

            SizedBox(height: 30), // Bottom padding
          ],
        ),
      ),
    );
  }
}
