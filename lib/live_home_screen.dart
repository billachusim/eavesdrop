import 'package:eavesdrop/auth/auth_service.dart';
import 'package:eavesdrop/booking/booking_screen.dart';
import 'package:eavesdrop/calls/my_calls_screen.dart';
import 'package:eavesdrop/live_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LiveHomeScreen extends StatefulWidget {
  const LiveHomeScreen({super.key});

  @override
  State<LiveHomeScreen> createState() => _LiveHomeScreenState();
}

class _LiveHomeScreenState extends State<LiveHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.7,
      upperBound: 1.2,
    )..repeat(reverse: true);

    // 🔥 Optional:
    // Trigger your 1-sec muffled audio preview here
    // using just_audio or audioplayers.
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: Text(
          "Eavesdrop",
          style: textTheme.headlineMedium!.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.call, color: Colors.white),
            label: const Text('My Calls', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyCallsScreen()),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.person, color: Colors.white),
            label: const Text('Logout', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              await _auth.signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DefaultTextStyle(
            style: textTheme.bodyMedium!.copyWith(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),

                Text(
                  "Some conversations aren't meant for everyone...",
                  style: textTheme.bodySmall!.copyWith(
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 40),

                /// LIVE CARD
                _buildLiveCard(context),

                const SizedBox(height: 40),

                /// STARTING SOON
                Text(
                  "STARTING SOON",
                  style: textTheme.labelLarge!.copyWith(
                    color: Colors.white54,
                    letterSpacing: 1.3,
                  ),
                ),

                const SizedBox(height: 16),

                _buildStartingSoonCard(),

              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BookingScreen()),
          );
        },
        child: const Icon(Icons.calendar_today),
      ),
    );
  }

  Widget _buildLiveCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// LIVE BADGE
          Row(
            children: [
              ScaleTransition(
                scale: _pulseController,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "LIVE",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              const Icon(Icons.people_alt_outlined, size: 18, color: Colors.white70),

              const SizedBox(width: 4),

              const Text(
                "5,284 listening",
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// TITLE
          const Text(
            "I Found Out My Husband Has Another Family.",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 20),

          /// Fake waveform
          Row(
            children: List.generate(
              20,
              (index) => AnimatedContainer(
                duration: Duration(milliseconds: 300 + (index * 40)),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 3,
                height: (index % 5 + 4) * 6,
                decoration: BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          /// BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LiveCallScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Enter Quietly",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            "This conversation is being broadcast.",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStartingSoonCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "6 MIN",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 16),

          const Expanded(
            child: Text(
              "Tonight I'm confronting my sugar daddy.",
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          TextButton(
            onPressed: () {},
            child: const Text("Remind Me"),
          )
        ],
      ),
    );
  }
}
