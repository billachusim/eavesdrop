import 'dart:ui';
import 'package:eavesdrop/models/call_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CallCard extends StatelessWidget {
  final CallModel call;
  final VoidCallback onTap;

  const CallCard({super.key, required this.call, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool hasRecording = call.recordingUrl != null && call.recordingUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      // Later, we can use a switch statement on call.personalityAvatar to show different images
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            call.title,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'with ${call.userNickname}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (call.userMood != null && call.userMood!.isNotEmpty)
                  Chip(label: Text('Feeling: ${call.userMood!}')),
                if (call.userLocation != null && call.userLocation!.isNotEmpty)
                  Chip(label: Text('From: ${call.userLocation!}')),

                const SizedBox(height: 16),
                Text(
                  '${call.startTime.toDate().toLocal()}'.split(' ')[0],
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
                if (hasRecording)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: ElevatedButton.icon(
                      onPressed: onTap, // Or a separate function for playback
                      icon: const Icon(Icons.play_circle_fill),
                      label: const Text('Listen to Recording'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
