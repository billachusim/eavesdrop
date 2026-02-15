import 'dart:async';
import 'dart:ui';
import 'package:add_2_calendar/add_2_calendar.dart';
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

class _CallCardState extends State<CallCard>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration? _timeUntilLive;
  late AnimationController _pulseController;
  bool _isReminderSet = false;

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
      _timeUntilLive =
          widget.call.startTime.toDate().difference(DateTime.now());
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
      _checkIfReminderIsSet();
    }
  }

  void _checkIfReminderIsSet() async {
    final user = context.read<User?>();
    if (user != null) {
      final db = DatabaseService();
      final isSet = await db.isReminderSet(widget.call.id, user.uid);
      if (mounted) {
        setState(() {
          _isReminderSet = isSet;
        });
      }
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

  Event _createCalendarEvent() {
    return Event(
      title: widget.call.title,
      description: 'Reminder for the call: ${widget.call.title}',
      location: 'Eavesdrop App',
      startDate: widget.call.startTime.toDate(),
      endDate: widget.call.endTime?.toDate() ??
          widget.call.startTime.toDate().add(const Duration(hours: 1)),
      allDay: false,
      iosParams: const IOSParams(
        reminder: Duration(minutes: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final db = DatabaseService();
    final bool hasRecording =
        widget.call.recordingUrl != null && widget.call.recordingUrl!.isNotEmpty;
    final bool isUpcoming = !widget.call.isLive &&
        widget.call.startTime.toDate().isAfter(DateTime.now());
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
                image: (userSnapshot.hasData &&
                    userSnapshot.data!.photoURL != null)
                    ? DecorationImage(
                    image: CachedNetworkImageProvider(
                        userSnapshot.data!.photoURL!),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                        Colors.black.withAlpha(150), BlendMode.darken))
                    : null,
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
                      colors: [
                        Colors.black.withAlpha(200),
                        Colors.black.withAlpha(100)
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    )),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopRow(
                        context, user, db, isUpcoming, userSnapshot.data),
                    const SizedBox(height: 18),
                    Text(
                      widget.call.title,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.3,
                        shadows: [
                          const Shadow(blurRadius: 10, color: Colors.black)
                        ],
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
                    if ((widget.call.userMood ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: Text(widget.call.userMood!),
                            backgroundColor: Colors.white.withAlpha(25),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    if (isPast)
                      Align(
                          alignment: Alignment.topLeft,
                          child: _buildPastCallFooter(hasRecording)),
                    if (isUpcoming) _buildUpcomingCallFooter(context, user, db),
                    if (widget.call.isLive) _buildLiveCallFooter(),
                  ],
                ),
              ),
            ),
          );
        });
  }

  Widget _buildTopRow(BuildContext context, User? currentUser,
      DatabaseService db, bool isUpcoming, UserModel? callUser) {
    final isCallOwner =
        currentUser != null && widget.call.callerId == currentUser.uid;

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
              final isAdmin = snapshot.hasData &&
                  (snapshot.data!.isAdmin || snapshot.data!.isSuperAdmin);

              final actions = <Widget>[
                IconButton(
                  icon: const Icon(Icons.bookmark_border, color: Colors.white70),
                  onPressed: () async {
                    await db.favoriteCall(currentUser.uid, widget.call);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Saved call.')),
                      );
                    }
                  },
                ),
              ];

              if (isAdmin) {
                actions.add(
                  IconButton(
                    icon: Icon(
                      widget.call.isFeatured ? Icons.star : Icons.star_border,
                      color: widget.call.isFeatured
                          ? Colors.yellow.shade700
                          : Colors.white54,
                    ),
                    onPressed: () => db.toggleFeaturedCall(
                      widget.call.id,
                      !widget.call.isFeatured,
                    ),
                  ),
                );
              }

              if (!isCallOwner) {
                actions.add(
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, color: Colors.white60),
                    color: const Color(0xFF1F1F1F),
                    onSelected: (_) =>
                        _handleModerationAction(context, currentUser, db),
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'hide_report_block',
                        child: Text('Hide, report & block user'),
                      ),
                    ],
                  ),
                );
              }

              return Row(mainAxisSize: MainAxisSize.min, children: actions);
            },
          ),
      ],
    );
  }

  Future<void> _handleModerationAction(
    BuildContext context,
    User currentUser,
    DatabaseService db,
  ) async {
    final shouldModerate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hide and report this call?'),
          content: const Text(
            'This will hide the call from your feed, report the host, and block this host from your feed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (shouldModerate != true) return;

    await db.hideReportAndBlockCallOwner(uid: currentUser.uid, call: widget.call);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Call hidden. Host reported and blocked.'),
        ),
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
          boxShadow: [
            BoxShadow(
                color: Colors.red.withAlpha(150),
                blurRadius: 15,
                spreadRadius: 2)
          ],
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
      return Align(
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              "Record is available.",
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
            ),
            SizedBox(
              width: 50,
              child: IconButton(
                icon: const Icon(Icons.play_circle_filled),
                iconSize: 50,
                color: Colors.white,
                onPressed: widget.onPlayRecording,
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      "No recording on this conversation.",
      style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
    );
  }

  Widget _buildUpcomingCallFooter(
      BuildContext context, User? user, DatabaseService db) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          if (user == null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                  const SnackBar(content: Text('Please log in to set reminders.')));
            return;
          }

          if (_isReminderSet) {
            // --- Remove Reminder ---
            await db.removeReminder(widget.call.id, user.uid);
            if (mounted) {
              setState(() {
                _isReminderSet = false;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(
                    content: Text('Reminder removed.'),
                    backgroundColor: Colors.red,
                  ));
              });
            }
          } else {
            // --- Set Reminder ---
            await db.setReminder(widget.call.id, user.uid);
            await Add2Calendar.addEvent2Cal(_createCalendarEvent());
            if (mounted) {
              setState(() {
                _isReminderSet = true;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(
                    content: Text('Reminder set and added to calendar!'),
                    backgroundColor: Colors.green,
                  ));
              });
            }
          }
        },
        icon: Icon(
          _isReminderSet
              ? Icons.notifications_active
              : Icons.notifications_active_outlined,
          color: _isReminderSet ? Colors.yellow.shade700 : Colors.white,
        ),
        label: Text(_isReminderSet ? "Reminder Set" : "Remind Me"),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor:
          _isReminderSet ? const Color(0xFF4d481a) : const Color(0xFF2D2D2D),
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
            const Icon(Icons.people_alt_outlined,
                size: 18, color: Colors.white70),
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
