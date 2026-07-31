import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  static const _steps = [
    _TutorialStep(
      emoji: '🃏',
      title: 'Welcome to Capture Tens',
      description: 'A strategic 4-player trick-taking card game where your goal is to capture the most 10s!',
      tip: 'You play in teams of 2 (seats 0+2 vs 1+3)',
      color: Color(0xFF48E5C2),
    ),
    _TutorialStep(
      emoji: '🎯',
      title: 'Capture the 10s',
      description: 'The team that captures the most 10-value cards wins the match. There are four 10s in the deck — one per suit.',
      tip: 'Tiebreaker: total cards captured, then aces',
      color: Color(0xFFFFC857),
    ),
    _TutorialStep(
      emoji: '⚡',
      title: 'The Power Suit',
      description: 'Before play begins, the dealer chooses a Power Suit (trump). Cards of this suit beat ALL other suits!',
      tip: 'Choose the suit you have the most cards in',
      color: Color(0xFFFF6B6B),
    ),
    _TutorialStep(
      emoji: '🃏',
      title: 'Follow the Lead',
      description: 'The first player in each trick leads a card. You MUST play the same suit if you have it.',
      tip: 'If you can\'t follow suit, you can play any card',
      color: Color(0xFF48E5C2),
    ),
    _TutorialStep(
      emoji: '⬆️',
      title: 'Play Higher',
      description: 'If following the lead suit, you must play a HIGHER card than the current highest — unless your teammate is already winning!',
      tip: 'Card order: 2, 3, 4 ... 10, J, Q, K, A',
      color: Color(0xFFB9F2FF),
    ),
    _TutorialStep(
      emoji: '🛡️',
      title: 'Protect Your 10s',
      description: 'You cannot discard an off-suit 10 unless you have 3 or fewer cards left in your hand.',
      tip: 'Hold your 10s as long as possible!',
      color: Color(0xFFFFC857),
    ),
    _TutorialStep(
      emoji: '🚫',
      title: 'First Trick Rules',
      description: 'On the very first trick: no Power Suit cards and no 10s can be played (unless you have no other option).',
      tip: 'This keeps the opening fair for everyone',
      color: Color(0xFFFF6B6B),
    ),
    _TutorialStep(
      emoji: '🏆',
      title: 'Ready to Play!',
      description: 'You now know the rules! Start a Bot Match to practice, or jump into Ranked to climb the leaderboard.',
      tip: 'Good luck and have fun! 🎉',
      color: Color(0xFF48E5C2),
    ),
  ];

  void _next() {
    if (_currentPage < _steps.length - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    } else {
      _finish();
    }
  }

  void _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed', true);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _steps.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF070B13),
      body: Stack(
        children: [
          // Animated background gradient
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  _steps[_currentPage].color.withOpacity(0.08),
                  const Color(0xFF070B13),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      isLast ? '' : 'Skip',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                    ),
                  ),
                ),

                // Page view
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _steps.length,
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Emoji icon with glow
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: step.color.withOpacity(0.1),
                                boxShadow: [
                                  BoxShadow(
                                    color: step.color.withOpacity(0.15),
                                    blurRadius: 40,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(step.emoji, style: const TextStyle(fontSize: 48)),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              step.title,
                              style: TextStyle(
                                color: step.color,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              step.description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            // Tip box
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: step.color.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: step.color.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lightbulb_outline, color: step.color, size: 16),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      step.tip,
                                      style: TextStyle(color: step.color, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Dots + Next button
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  child: Column(
                    children: [
                      // Page dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_steps.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == i ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _currentPage == i
                                  ? _steps[_currentPage].color
                                  : Colors.white.withOpacity(0.15),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      // Action button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _steps[_currentPage].color,
                            foregroundColor: const Color(0xFF070B13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Text(
                            isLast ? 'Start Playing!' : 'Next',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialStep {
  const _TutorialStep({
    required this.emoji,
    required this.title,
    required this.description,
    required this.tip,
    required this.color,
  });
  final String emoji;
  final String title;
  final String description;
  final String tip;
  final Color color;
}
