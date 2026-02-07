import 'dart:ui';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CallCard extends StatelessWidget {
  final CallModel call;
  final VoidCallback onTap;
  final VoidCallback onPlayRecording;

  const CallCard(
      {super.key,
      required this.call,
      required this.onTap,
      required this.onPlayRecording});

  String _getOrdinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasRecording =
        call.recordingUrl != null && call.recordingUrl!.isNotEmpty;
    final user = Provider.of<User?>(context);
    final db = DatabaseService();

    final start = call.startTime.toDate().toLocal();
    final end = start.add(const Duration(hours: 1));

    const durationText = 'One Hour Call';

    final dayOfWeek = DateFormat.E().format(start);
    final dayOfMonth = _getOrdinal(start.day);
    final month = DateFormat.MMM().format(start);
    final year = start.year;
    final dateString = '$dayOfWeek, $dayOfMonth $month, $year';

    final timeFormat = DateFormat('ha');
    final startTimeString = timeFormat.format(start).toLowerCase();
    final endTimeString = timeFormat.format(end).toLowerCase();
    final timeRangeString = '$startTimeString to $endTimeString';

    final fullDateTimeString =
        '$durationText on $dateString between $timeRangeString';

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
              border: Border.all(color: Colors.white.withAlpha(51)),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withAlpha(38),
                  Colors.white.withAlpha(13)
                ],
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
                      backgroundColor: Colors.white.withAlpha(77),
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
                    if (user != null)
                      StreamBuilder<UserModel>(
                          stream: db.streamUser(user.uid),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final userModel = snapshot.data!;
                              if (userModel.isAdmin ||
                                  userModel.isSuperAdmin) {
                                return IconButton(
                                  icon: Icon(
                                    call.isFeatured
                                        ? Icons.lightbulb
                                        : Icons.lightbulb_outline,
                                    color: call.isFeatured
                                        ? Colors.yellow
                                        : Colors.white,
                                  ),
                                  onPressed: () {
                                    db.toggleFeaturedCall(
                                        call.id, !call.isFeatured);
                                  },
                                );
                              }
                            }
                            return const SizedBox.shrink();
                          })
                  ],
                ),
                const SizedBox(height: 16),
                if (call.userMood != null && call.userMood!.isNotEmpty)
                  Chip(label: Text('Feeling: ${call.userMood!}')),
                if (call.userLocation != null &&
                    call.userLocation!.isNotEmpty)
                  Chip(label: Text('From: ${call.userLocation!}')),
                const SizedBox(height: 16),
                Text(
                  fullDateTimeString,
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
                if (hasRecording)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: ElevatedButton.icon(
                      onPressed:
                          onPlayRecording, // Or a separate function for playback
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