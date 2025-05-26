import 'package:flutter/material.dart';
import 'dart:math';
import '../utils/question_service.dart';
import '../utils/progress_service.dart';
import '../utils/category_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/ad_helper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({Key? key}) : super(key: key);

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _allFlashcards = [];
  List<Map<String, dynamic>> _filteredFlashcards = [];
  List<String> _categories = [];
  String? _selectedCategory;
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _showingAnswer = false;

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Ad related variables
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  final RewardedInterstitialAdManager _rewardedInterstitialAdManager =
      RewardedInterstitialAdManager();
  int _cardsSinceLastAd = 0;

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
    _loadBannerAd();
    _loadRewardedInterstitialAd();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    _bannerAd?.load();
  }

  void _loadRewardedInterstitialAd() {
    _rewardedInterstitialAdManager.loadAd(
      onUserEarnedReward: (reward) {
        // Handle reward if needed
      },
    );
  }

  Future<void> _loadFlashcards() async {
    setState(() {
      _isLoading = true;
    });

    // Load questions from JSON file
    await QuestionService.loadQuestions();

    // Get categories
    _categories = QuestionService.getCategories();

    // Get all questions
    _allFlashcards = QuestionService.getAllQuestions();

    // Apply initial filter
    _applyFilters();

    setState(() {
      _isLoading = false;
    });
  }

  void _applyFilters() {
    setState(() {
      if (_selectedCategory != null) {
        _filteredFlashcards = _allFlashcards
            .where((card) => card['category'] == _selectedCategory)
            .toList();
      } else {
        _filteredFlashcards = List.from(_allFlashcards);
      }

      // Shuffle the cards
      _filteredFlashcards.shuffle();

      if (_filteredFlashcards.isEmpty) {
        _filteredFlashcards = [
          {
            'question': 'No flashcards available Because of What?',
            'explanation': 'Because of the internet issue in your device',
            'category': 'N/A'
          }
        ];
      }

      // Reset to first card
      _currentIndex = 0;
      _showingAnswer = false;
      _animationController.reset();
    });
  }

  void _toggleShowAnswer() {
    setState(() {
      _showingAnswer = !_showingAnswer;
      if (_showingAnswer) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _nextCard() async {
    if (_filteredFlashcards.isEmpty) return;

    // Record activity periodically
    if (_currentIndex % 5 == 0) {
      await ProgressService.recordActivity(
        title: _selectedCategory ?? 'Flashcards',
        type: 'flashcard',
        detail: 'Reviewed flashcards',
        score: null,
      );

      // Add study time
      await ProgressService.addStudyTime(1);
    }

    // Increment counter for ad display
    _cardsSinceLastAd++;

    // Show rewarded interstitial ad every 8 cards
    if (_cardsSinceLastAd >= 8 && _rewardedInterstitialAdManager.isAdLoaded) {
      _rewardedInterstitialAdManager.showAd();
      _cardsSinceLastAd = 0;
      _loadRewardedInterstitialAd(); // Preload next ad
    }

    setState(() {
      if (_currentIndex < _filteredFlashcards.length - 1) {
        _currentIndex++;
      } else {
        // Loop back to the start
        _currentIndex = 0;
      }
      _showingAnswer = false;
      _animationController.reset();
    });
  }

  void _previousCard() {
    if (_filteredFlashcards.isEmpty) return;

    setState(() {
      if (_currentIndex > 0) {
        _currentIndex--;
      } else {
        // Loop to the end
        _currentIndex = _filteredFlashcards.length - 1;
      }
      _showingAnswer = false;
      _animationController.reset();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _bannerAd?.dispose();
    _rewardedInterstitialAdManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = CategoryUtils.getCategoryColor(_selectedCategory);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor.withOpacity(0.9),
        title: Row(
          children: [
            CategoryUtils.getFontAwesomeIcon(_selectedCategory,
                size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Flashcards',
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.visible,
              ),
            )
          ],
        ),
        actions: [
          Chip(
            avatar: CircleAvatar(
              backgroundColor: Colors.white,
              child: CategoryUtils.getFontAwesomeIcon(
                _selectedCategory,
                size: 14,
                color: primaryColor,
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
            backgroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.filter, size: 18),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Filter by Category',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          height: 320,
                          child: GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 2.5,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount:
                                _categories.length + 1, // +1 for "All" option
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // All categories option
                                final isSelected = _selectedCategory == null;
                                return _buildCategoryFilterItem(
                                  context,
                                  'All',
                                  FontAwesomeIcons.layerGroup,
                                  Colors.blue.shade400,
                                  isSelected,
                                  () {
                                    setState(() {
                                      _selectedCategory = null;
                                    });
                                    _applyFilters();
                                    Navigator.pop(context);
                                  },
                                );
                              } else {
                                // Specific category
                                final category = _categories[index - 1];
                                final isSelected =
                                    category == _selectedCategory;
                                final categoryColor =
                                    CategoryUtils.getCategoryColor(category);
                                final categoryIcon =
                                    CategoryUtils.getCategoryIcon(category);

                                return _buildCategoryFilterItem(
                                  context,
                                  category,
                                  categoryIcon is IconData
                                      ? categoryIcon as IconData
                                      : FontAwesomeIcons.layerGroup,
                                  categoryColor,
                                  isSelected,
                                  () {
                                    setState(() {
                                      _selectedCategory = category;
                                    });
                                    _applyFilters();
                                    Navigator.pop(context);
                                  },
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            tooltip: 'Filter by Category',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading flashcards...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          primaryColor.withOpacity(0.2),
                          theme.scaffoldBackgroundColor,
                          theme.colorScheme.background.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        // Category selector at the top
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: CategoryUtils.buildCategoryChipsList(
                            categories: _categories,
                            selectedCategory: _selectedCategory,
                            onCategorySelected: (category) {
                              setState(() {
                                _selectedCategory = category;
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                        // Progress indicator
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.2),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                // Percentage circle
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      primaryColor.withOpacity(0.1),
                                  child: Text(
                                    '${((_currentIndex + 1) / _filteredFlashcards.length * 100).round()}%',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Progress bar and card count
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Progress bar
                                      Container(
                                        height: 8,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          color: Colors.grey.shade200,
                                        ),
                                        child: Row(
                                          children: [
                                            // Filled part
                                            Flexible(
                                              flex: _currentIndex + 1,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      primaryColor
                                                          .withOpacity(0.7),
                                                      primaryColor,
                                                    ],
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: primaryColor
                                                          .withOpacity(0.5),
                                                      blurRadius: 5,
                                                      offset:
                                                          const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // Empty part
                                            Flexible(
                                              flex: _filteredFlashcards.length -
                                                  (_currentIndex + 1),
                                              child: const SizedBox(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Card counter
                                      Text(
                                        'Card ${_currentIndex + 1} of ${_filteredFlashcards.length}',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Flashcard
                        Expanded(
                          child: GestureDetector(
                            onHorizontalDragEnd: (details) {
                              if (details.primaryVelocity! > 0) {
                                _previousCard();
                              } else if (details.primaryVelocity! < 0) {
                                _nextCard();
                              }
                            },
                            onTap: _toggleShowAnswer,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 16),
                                child: AnimatedBuilder(
                                  animation: _animation,
                                  builder: (context, child) {
                                    final angle = _animation.value * pi;
                                    final isBack = angle > pi / 2;

                                    return Transform(
                                      transform: Matrix4.identity()
                                        ..setEntry(3, 2, 0.001)
                                        ..rotateY(angle),
                                      alignment: Alignment.center,
                                      child: Card(
                                        elevation: 10,
                                        shadowColor:
                                            primaryColor.withOpacity(0.4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          side: BorderSide(
                                            color: isBack
                                                ? primaryColor.withOpacity(0.5)
                                                : Colors.grey.withOpacity(0.2),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: isBack
                                                  ? [
                                                      primaryColor
                                                          .withOpacity(0.05),
                                                      Colors.white,
                                                      Colors.white,
                                                    ]
                                                  : [
                                                      Colors.white,
                                                      Colors.white,
                                                      primaryColor
                                                          .withOpacity(0.05),
                                                    ],
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              if (!isBack)
                                                Positioned(
                                                  top: 16,
                                                  right: 16,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: primaryColor
                                                          .withOpacity(0.1),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: FaIcon(
                                                      CategoryUtils.getCategoryIcon(
                                                          _filteredFlashcards[
                                                                  _currentIndex]
                                                              ['category']),
                                                      color: primaryColor,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              if (isBack)
                                                Positioned(
                                                  top: 16,
                                                  right: 16,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: primaryColor
                                                          .withOpacity(0.1),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: FaIcon(
                                                      FontAwesomeIcons
                                                          .lightbulb,
                                                      color: primaryColor,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(24),
                                                child: isBack
                                                    ? _buildBackContent(
                                                        primaryColor)
                                                    : _buildFrontContent(
                                                        primaryColor),
                                              ),
                                              Positioned(
                                                bottom: 16,
                                                right: 16,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.1),
                                                        spreadRadius: 1,
                                                        blurRadius: 3,
                                                      ),
                                                    ],
                                                  ),
                                                  child: FaIcon(
                                                    isBack
                                                        ? FontAwesomeIcons.redo
                                                        : FontAwesomeIcons
                                                            .handPointLeft,
                                                    color: Colors.grey.shade400,
                                                    size: 18,
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
                              ),
                            ),
                          ),
                        ),
                        // Card navigation controls
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildNavigationButton(
                                Icons.arrow_back_rounded,
                                _previousCard,
                                'Previous card',
                                Colors.grey.shade700,
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor.withOpacity(0.8),
                                      primaryColor,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.4),
                                      spreadRadius: 1,
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (Widget child,
                                        Animation<double> animation) {
                                      return RotationTransition(
                                        turns: animation,
                                        child: FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: FaIcon(
                                      _showingAnswer
                                          ? FontAwesomeIcons.arrowsRotate
                                          : FontAwesomeIcons.rotate,
                                      key: ValueKey<bool>(_showingAnswer),
                                      color: Colors.white,
                                    ),
                                  ),
                                  onPressed: _toggleShowAnswer,
                                  iconSize: 30,
                                  tooltip: 'Flip card',
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                              _buildNavigationButton(
                                Icons.arrow_forward_rounded,
                                _nextCard,
                                'Next card',
                                Colors.grey.shade700,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Banner Ad at the bottom
                if (_isBannerAdLoaded && _bannerAd != null)
                  Container(
                    alignment: Alignment.center,
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
    );
  }

  Widget _buildNavigationButton(
      IconData icon, VoidCallback onPressed, String tooltip, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        iconSize: 26,
        color: color,
        tooltip: tooltip,
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildFrontContent(Color primaryColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'QUESTION',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              FaIcon(
                FontAwesomeIcons.question,
                size: 16,
                color: primaryColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                _filteredFlashcards[_currentIndex]['question'],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(
                FontAwesomeIcons.handPointer,
                size: 18,
                color: primaryColor.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Tap to reveal answer',
                style: TextStyle(
                  fontSize: 14,
                  color: primaryColor.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackContent(Color primaryColor) {
    return Transform(
      transform: Matrix4.identity()..rotateY(pi),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  FontAwesomeIcons.lightbulb,
                  size: 16,
                  color: primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'ANSWER',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  _filteredFlashcards[_currentIndex]['explanation'] ??
                      'No explanation available',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(
                  FontAwesomeIcons.handPointer,
                  size: 18,
                  color: primaryColor.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tap to flip back',
                  style: TextStyle(
                    fontSize: 14,
                    color: primaryColor.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterItem(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.transparent : color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color:
                      isSelected ? Colors.white.withOpacity(0.3) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: FaIcon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : color,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
