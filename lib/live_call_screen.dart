import 'package:eavesdrop/paywall_overlay.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:avatar_glow/avatar_glow.dart';

class LiveCallScreen extends StatefulWidget {
  const LiveCallScreen({super.key});

  @override
  State<LiveCallScreen> createState() => _LiveCallScreenState();
}

class _LiveCallScreenState extends State<LiveCallScreen> {
  bool _isPaywallShown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted) {
        setState(() {
          _isPaywallShown = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DefaultTextStyle(
                style: textTheme.bodyMedium!.copyWith(color: Colors.white),
                child: Column(
                  children: [

                    const SizedBox(height: 12),

                    /// TOP BAR
                    _topBar(context),

                    const SizedBox(height: 30),

                    /// CALL TITLE
                    Text(
                      "I Found Out My Husband Has Another Family.",
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 30),

                    /// SPEAKERS
                    Expanded(
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: const [
                            SpeakerAvatar(
                              name: "Maya",
                              image:
                                  "https://i.pravatar.cc/300?img=5",
                              isSpeaking: true,
                            ),
                            SpeakerAvatar(
                              name: "Claire",
                              image:
                                  "https://i.pravatar.cc/300?img=47",
                              isSpeaking: false,
                            ),
                          ],
                        ),
                      ),
                    ),

                    /// LISTENER STRIP
                    _listenerStrip(),

                    const SizedBox(height: 20),

                    /// CONTROLS
                    _bottomControls(context),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          if (_isPaywallShown)
            const PaywallOverlay(),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        /// LIVE INDICATOR
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

        const SizedBox(width: 10),

        const Icon(Icons.people_alt_outlined, size: 18, color: Colors.white70),

        const SizedBox(width: 4),

        const Text("8,112 listening",
            style: TextStyle(color: Colors.white70)),

        const Spacer(),

        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        )
      ],
    );
  }

  Widget _listenerStrip() {
    return Column(
      children: [
        const SizedBox(height: 10),

        SizedBox(
          height: 40,
          child: Stack(
            children: List.generate(
              8,
              (index) => Positioned(
                left: index * 22,
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage:
                      NetworkImage("https://i.pravatar.cc/150?img=${index + 10}"),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          "This conversation is being broadcast.",
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _bottomControls(BuildContext context) {
    return Column(
      children: [

        /// SEND QUESTION
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.question_answer_outlined),
          label: const Text("Send a Question"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1C1C1C),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),

        const SizedBox(height: 12),

        /// LEAVE BUTTON
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            "Leave Quietly",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class SpeakerAvatar extends StatelessWidget {
  final String name;
  final String image;
  final bool isSpeaking;

  const SpeakerAvatar({
    super.key,
    required this.name,
    required this.image,
    required this.isSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AvatarGlow(
          animate: isSpeaking,
          glowColor: Colors.greenAccent,
          duration: const Duration(milliseconds: 2000),
          endRadius: 10,
          child: CircleAvatar(
            radius: 42,
            backgroundImage: NetworkImage(image),
          ),
        ),
        const SizedBox(height: 10),
        Text(name),
      ],
    );
  }
}
