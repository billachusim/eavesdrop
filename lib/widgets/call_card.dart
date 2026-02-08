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
  final VoidCallback? onPlayRecording;

  const CallCard({
    super.key,
    required this.call,
    required this.onTap,
    this.onPlayRecording,
  });

  @override
  State<CallCard> createState() => _CallCardState();
}

class _CallCardState extends State<CallCard> with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration? _timeUntilLive;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.95,
      upperBound: 1.05,
    );

    if (widget.call.isLive) {
      _pulseController.repeat(reverse: true);
    } else if (widget.call.startTime.toDate().isAfter(DateTime.now())) {
      _timeUntilLive = widget.call.startTime.toDate().difference(DateTime.now());
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _timeUntilLive =
              widget.call.startTime.toDate().difference(DateTime.now());
          if (_timeUntilLive!.inSeconds <= 0) {
            _timer?.cancel();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTimeUntilLive() {
    if (_timeUntilLive == null || _timeUntilLive!.isNegative) return "SOON";
    if (_timeUntilLive!.inDays > 0) return '${_timeUntilLive!.inDays}d';
    if (_timeUntilLive!.inHours > 0) return '${_timeUntilLive!.inHours}h';
    if (_timeUntilLive!.inMinutes > 0) return '${_timeUntilLive!.inMinutes}m';
    return '${_timeUntilLive!.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final db = DatabaseService();
    final bool hasRecording =
        widget.call.recordingUrl != null && widget.call.recordingUrl!.isNotEmpty;
    final bool isUpcoming =
        !widget.call.isLive && widget.call.startTime.toDate().isAfter(DateTime.now());
    final bool isPast = !widget.call.isLive && !isUpcoming;

    return StreamBuilder<UserModel>(
        stream: db.streamUser(widget.call.callerId),
        builder: (context, userSnapshot) {
          return GestureDetector(
            onTap: widget.onTap,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(22),
                image: (userSnapshot.hasData && userSnapshot.data!.photoURL != null)
                ? DecorationImage(
                  image: CachedNetworkImageProvider(userSnapshot.data!.photoURL!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withAlpha(150), BlendMode.darken)
                ) : null,
                border: Border.all(
                  color: widget.call.isLive
                      ? Colors.red.withAlpha(128)
                      : Colors.white.withAlpha(30),
                  width: 1,
                ),
                boxShadow: widget.call.isLive
                    ? [
                        BoxShadow(
                          color: Colors.red.withAlpha(51),
                          blurRadius: 25,
                          spreadRadius: 2,
                        )
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withAlpha(102),
                          blurRadius: 15,
                          spreadRadius: -5,
                          offset: const Offset(0, 8),
                        )
                      ],
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [Colors.black.withAlpha(200), Colors.black.withAlpha(100)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  )
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopRow(context, user, db, isUpcoming, userSnapshot.data),
                    const SizedBox(height: 18),
                    Text(
                      widget.call.title,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.3,
                        shadows: [const Shadow(blurRadius: 10, color: Colors.black)],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'with ${widget.call.userNickname}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isPast) _buildPastCallFooter(hasRecording),
                    if (isUpcoming) _buildUpcomingCallFooter(context, user, db),
                    if (widget.call.isLive) _buildLiveCallFooter(),
                  ],
                ),
              ),
            ),
          );
        });
  }

  Widget _buildTopRow(BuildContext context, User? currentUser, DatabaseService db,
      bool isUpcoming, UserModel? callUser) {
    return Row(
      children: [
        if (widget.call.isLive)
          _buildLiveBadge()
        else if (isUpcoming)
          _buildUpcomingBadge()
        else
          _buildPastBadge(),
        const SizedBox(width: 10),
        if (callUser != null && callUser.photoURL != null)
        CircleAvatar(
          radius: 12,
          backgroundImage: CachedNetworkImageProvider(callUser.photoURL!),
        ),
        const Spacer(),
        if (currentUser != null)
          StreamBuilder<UserModel>(
            stream: db.streamUser(currentUser.uid),
            builder: (context, snapshot) {
              if (snapshot.hasData &&
                  (snapshot.data!.isAdmin || snapshot.data!.isSuperAdmin)) {
                return IconButton(
                  icon: Icon(
                    widget.call.isFeatured ? Icons.star : Icons.star_border,
                    color: widget.call.isFeatured
                        ? Colors.yellow.shade700
                        : Colors.white54,
                  ),
                  onPressed: () =>
                      db.toggleFeaturedCall(widget.call.id, !widget.call.isFeatured),
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  Widget _buildLiveBadge() {
    return ScaleTransition(
      scale: _pulseController,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.red.withAlpha(150), blurRadius: 15, spreadRadius: 2)],
        ),
        child: Text(
          "LIVE",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange.shade700,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _formatTimeUntilLive(),
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPastBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        DateFormat.yMMMd().format(widget.call.startTime.toDate()),
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildPastCallFooter(bool hasRecording) {
    if (hasRecording && widget.onPlayRecording != null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: widget.onPlayRecording,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text("Play Recording"),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      );
    }
    return Text(
      "This conversation was not recorded.",
      style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
    );
  }

  Widget _buildUpcomingCallFooter(
      BuildContext context, User? user, DatabaseService db) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          if (user != null) {
            db.setReminder(widget.call.id, user.uid);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                content: Text('Reminder set!'),
                backgroundColor: Colors.green,
              ));
          } else {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                  content: Text('Please log in to set reminders.')));
          }
        },
        icon: const Icon(Icons.notifications_active_outlined),
        label: const Text("Remind Me"),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: const Color(0xFF2D2D2D),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveCallFooter() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              "Enter Quietly",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_alt_outlined, size: 18, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              "${widget.call.listeners} listening",
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}
