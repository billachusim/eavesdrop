import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CallCard extends StatefulWidget {
  final CallModel call;
  final VoidCallback onTap;
  final VoidCallback onPlayRecording;

  const CallCard(
      {super.key,
      required this.call,
      required this.onTap,
      required this.onPlayRecording});

  @override
  State<CallCard> createState() => _CallCardState();
}

class _CallCardState extends State<CallCard> {
  Timer? _timer;
  Duration? _timeUntilLive;

  @override
  void initState() {
    super.initState();
    if (!widget.call.isLive && widget.call.startTime.toDate().isAfter(DateTime.now())) {
      _timeUntilLive = widget.call.startTime.toDate().difference(DateTime.now());
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _timeUntilLive = widget.call.startTime.toDate().difference(DateTime.now());
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getOrdinal(int number) {
    if (number >= 11 && number <= 13) {
      return 'th';
    }
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  String _formatTimeUntilLive() {
    if (_timeUntilLive == null || _timeUntilLive!.inSeconds <= 0) {
      return '';
    }
    if (_timeUntilLive!.inMinutes > 0) {
      return 'Live in ${_timeUntilLive!.inMinutes} minutes';
    }
    return 'Live in ${_timeUntilLive!.inSeconds} seconds';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasRecording =
        widget.call.recordingUrl != null && widget.call.recordingUrl!.isNotEmpty;
    final user = Provider.of<User?>(context);
    final db = DatabaseService();

    final start = widget.call.startTime.toDate().toLocal();
    final end = start.add(const Duration(hours: 1));

    const durationText = 'One Hour Call';

    final dayOfWeek = DateFormat.E().format(start);
    final dayOfMonth = start.day;
    final ordinal = _getOrdinal(dayOfMonth);
    final month = DateFormat.MMM().format(start);
    final year = start.year;
    final dateString = '$dayOfWeek, $dayOfMonth$ordinal $month, $year';

    final timeFormat = DateFormat('ha');
    final startTimeString = timeFormat.format(start).toLowerCase();
    final endTimeString = timeFormat.format(end).toLowerCase();
    final timeRangeString = '$startTimeString to $endTimeString';

    final fullDateTimeString =
        '$durationText on $dateString between $timeRangeString';

    return GestureDetector(
      onTap: widget.onTap,
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
                    StreamBuilder<UserModel>(
                      stream: db.streamUser(widget.call.callerId),
                        builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final caller = snapshot.data!;
                          return CircleAvatar(
                            backgroundColor: Colors.white.withAlpha(77),
                            backgroundImage: CachedNetworkImageProvider(caller.photoURL ?? ''),
                            child: caller.photoURL == null ? const Icon(Icons.person, color: Colors.white) : null,
                          );
                        } else {
                          return CircleAvatar(
                            backgroundColor: Colors.white.withAlpha(77),
                            child: const Icon(Icons.person, color: Colors.white),
                          );
                        }
                      }
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.call.title,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'with ${widget.call.userNickname}',
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
                                    widget.call.isFeatured
                                        ? Icons.lightbulb
                                        : Icons.lightbulb_outline,
                                    color: widget.call.isFeatured
                                        ? Colors.yellow
                                        : Colors.white,
                                  ),
                                  onPressed: () {
                                    db.toggleFeaturedCall(
                                        widget.call.id, !widget.call.isFeatured);
                                  },
                                );
                              }
                            }
                            return const SizedBox.shrink();
                          })
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.call.userMood != null && widget.call.userMood!.isNotEmpty)
                  Chip(label: Text('Feeling: ${widget.call.userMood!}')),
                if (widget.call.userLocation != null &&
                    widget.call.userLocation!.isNotEmpty)
                  Chip(label: Text('From: ${widget.call.userLocation!}')),
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
                          widget.onPlayRecording,
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
                if (!widget.call.isLive && _timeUntilLive != null && _timeUntilLive!.inSeconds > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            if (user != null) {
                              db.setReminder(widget.call.id, user.uid);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder set!')));
                            }
                          },
                          icon: const Icon(Icons.notifications_active),
                          label: const Text('Set Reminder'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.black,
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatTimeUntilLive(),
                          style: GoogleFonts.inter(
                            color: Colors.yellow,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (widget.call.isLive)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.5),
                              spreadRadius: 2,
                              blurRadius: 4,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                        child: Text(
                          'LIVE',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${widget.call.listeners} listening',
                        style: GoogleFonts.inter(color: Colors.white),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
