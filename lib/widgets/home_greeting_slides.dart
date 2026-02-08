import 'dart:async';
import 'package:eavesdrop/calls/my_calls_screen.dart';
import 'package:flutter/material.dart';

class HomeGreetingSlides extends StatefulWidget {
  const HomeGreetingSlides({super.key});

  @override
  State<HomeGreetingSlides> createState() => _HomeGreetingSlidesState();
}

class _HomeGreetingSlidesState extends State<HomeGreetingSlides> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (!mounted) return;
      int nextPage = (_currentPage + 1) % 3;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: const [
              _GreetingCard(
                icon: Icons.support_agent,
                title: 'Talk to Someone. For Real.',
                subtitle:
                'Not an audience. Not an algorithm. Just one human giving you their full attention.',
              ),
              _GreetingCard(
                icon: Icons.lightbulb_outline,
                title: 'Say the Things You’ve Been Holding In',
                subtitle:
                'About love, confusion, loneliness, situationships, or nothing at all. You won’t be judged or rushed.',
              ),
              _GreetingCard(
                icon: Icons.history,
                title: 'Build a Quiet Connection',
                subtitle:
                'Some conversations stay with you. Come back to them. Feel less alone next time.',
                isCta: true,
              ),
            ],

          ),
          Positioned(
            bottom: 10.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) => _buildDot(index, context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index, BuildContext context) {
    return Container(
      height: 10,
      width: 10,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _currentPage == index
            ? Theme.of(context).primaryColor
            : Colors.grey,
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCta;

  const _GreetingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isCta = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.all(16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0), // Adjust padding
        child: SingleChildScrollView( // Makes the content scrollable to prevent overflow
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.amber), // Changed color to yellow
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (isCta) const SizedBox(height: 15),
              if (isCta)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MyCallsScreen()),
                    );
                  },
                  child: const Text('See Past Calls'), // Changed button text
                )
            ],
          ),
        ),
      ),
    );
  }
}
