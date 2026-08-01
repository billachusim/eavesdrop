import 'package:eavesdrop/auth/onboarding_screen.dart';
import 'package:eavesdrop/live_home_screen.dart';
import 'package:eavesdrop/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImmersiveOnboarding extends StatefulWidget {
  const ImmersiveOnboarding({super.key});

  @override
  State<ImmersiveOnboarding> createState() => _ImmersiveOnboardingState();
}

class _ImmersiveOnboardingState extends State<ImmersiveOnboarding> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: "LISTEN TO\nREAL PEOPLE.\nLIVE.",
      description: "Thousands of conversations happening right now on every topic.",
      icon: Icons.headphones_outlined,
      color: const Color(0xFF6200EA),
    ),
    OnboardingPageData(
      title: "JOIN\nWHEN YOU HAVE\nSOMETHING\nTO SAY.",
      description: "Raise your hand, share your voice, join the conversation.",
      icon: Icons.mic_none_outlined,
      color: const Color(0xFF00BFA5),
    ),
    OnboardingPageData(
      title: "DISCOVER\nCONVERSATIONS\nYOU'LL LOVE.",
      description: "Explore trending stories, topics and hosts that speak your vibe.",
      icon: Icons.explore_outlined,
      color: const Color(0xFFD500F9),
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LiveHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      page.color.withValues(alpha: 0.2),
                      const Color(0xFF0D0D0D),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(page.icon, size: 80, color: page.color),
                    const SizedBox(height: 40),
                    Text(
                      page.title,
                      style: GoogleFonts.inter(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      page.description,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            bottom: 60,
            left: 40,
            right: 40,
            child: Column(
              children: [
                Row(
                  children: List.generate(
                    _pages.length,
                    (index) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      height: 4,
                      width: _currentPage == index ? 24 : 12,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? Colors.white : Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                PrimaryButton(
                  text: _currentPage == _pages.length - 1 ? "Get Started" : "Next",
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    "Browse as Guest",
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
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

class OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
