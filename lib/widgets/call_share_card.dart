import 'package:eavesdrop/models/call_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CallShareCard extends StatelessWidget {
  final CallModel call;

  const CallShareCard({super.key, required this.call});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 1080,
        height: 1080,
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D0D),
        ),
        child: Stack(
          children: [
            // Background accent
            Positioned(
              top: -200,
              right: -200,
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.03),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(80.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              call.isLive ? Colors.red : Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          call.isLive ? "LIVE NOW" : "HAPPENING SOON",
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                      Text(
                        call.title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: call.title.length > 30 ? 64 : 84,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'with ${call.userNickname}',
                        style: GoogleFonts.inter(
                          fontSize: 42,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: Colors.white24, thickness: 2),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          const Icon(Icons.graphic_eq,
                              color: Colors.white, size: 72),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "EAVESDROP",
                                  style: GoogleFonts.inter(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 4,
                                  ),
                                ),
                                Text(
                                  "Live Conversations Worth Listening To",
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
