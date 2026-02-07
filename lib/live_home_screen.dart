import 'dart:async';
import 'package:eavesdrop/admin/admin_dashboard.dart';
import 'package:eavesdrop/booking/booking_screen.dart';
import 'package:eavesdrop/calls/my_calls_screen.dart';
import 'package:eavesdrop/credits_screen.dart';
import 'package:eavesdrop/live_call_screen.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:eavesdrop/widgets/call_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class LiveHomeScreen extends StatefulWidget {
  const LiveHomeScreen({super.key});

  @override
  State<LiveHomeScreen> createState() => _LiveHomeScreenState();
}

class _LiveHomeScreenState extends State<LiveHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final DatabaseService _db = DatabaseService();

  late StreamSubscription _liveCallsSubscription;
  late StreamSubscription _upcomingCallsSubscription;
  List<CallModel> _liveCalls = [];
  List<CallModel> _upcomingCalls = [];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.7,
      upperBound: 1.2,
    )..repeat(reverse: true);

    _liveCallsSubscription = _db.streamLiveCalls().listen((calls) {
      if (mounted) setState(() => _liveCalls = calls);
    });

    _upcomingCallsSubscription = _db.streamUpcomingCalls().listen((calls) {
      if (mounted) setState(() => _upcomingCalls = calls);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _liveCallsSubscription.cancel();
    _upcomingCallsSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();
    final user = Provider.of<User?>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: DefaultTextStyle(
        style: textTheme.bodyMedium!.copyWith(color: Colors.white),
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                title: Text(
                  "Eavesdrop",
                  style: textTheme.headlineMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                actions: [
                  if (user != null)
                    StreamBuilder<UserModel>(
                      stream: _db.streamUser(user.uid),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final userModel = snapshot.data!;
                          return Row(
                            children: [
                              if (userModel.isAdmin || userModel.isSuperAdmin)
                                TextButton.icon(
                                  icon: const Icon(Icons.dashboard,
                                      color: Colors.white),
                                  label: const Text('Admin',
                                      style: TextStyle(color: Colors.white)),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const AdminDashboard()),
                                    );
                                  },
                                ),
                              TextButton.icon(
                                icon: const Icon(Icons.monetization_on,
                                    color: Colors.white),
                                label: Text('${userModel.credits} Credits',
                                    style: const TextStyle(color: Colors.white)),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const CreditsScreen()),
                                  );
                                },
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.call, color: Colors.white),
                    label: const Text('My Calls',
                        style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please log in to see your calls.')),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const MyCallsScreen()),
                      );
                    },
                  ),
                ],
                backgroundColor: const Color(0xFF0D0D0D),
                pinned: true,
                floating: true,
                snap: true,
              ),
            ];
          },
          body: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Some conversations aren't meant for everyone...",
                        style: textTheme.bodySmall!.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text("Live Now",
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              _liveCalls.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text("No live calls right now."),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            return _buildLiveCard(context, _liveCalls[index]);
                          },
                          childCount: _liveCalls.length,
                        ),
                      ),
                    ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 40, 20, 20),
                  child: Text("Upcoming",
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              ),
              _upcomingCalls.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text("No upcoming calls scheduled."),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            return _buildUpcomingCallCard(
                                context, _upcomingCalls[index], user);
                          },
                          childCount: _upcomingCalls.length,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Please log in to book a call.')),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BookingScreen()),
          );
        },
        child: const Icon(Icons.calendar_today),
      ),
    );
  }

  Widget _buildUpcomingCallCard(BuildContext context, CallModel call, User? user) {
    final timeDifference = call.startTime.toDate().difference(DateTime.now());
    final bool isSoon = timeDifference.inHours < 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          CallCard(call: call, onTap: () {}), // We can add navigation later
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isSoon)
                ScaleTransition(
                  scale: _pulseController,
                  child: Chip(
                    backgroundColor: Colors.blue,
                    label: Text(
                      "In ${timeDifference.inMinutes} mins",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (!isSoon)
                Chip(
                  backgroundColor: Colors.grey,
                  label: Text(
                    call.startTime.toDate().toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: () {
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please log in to set a reminder.')),
                    );
                    return;
                  }
                  _db.setReminder(call.id, user.uid);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reminder set!')),
                  );
                },
                icon: const Icon(Icons.notifications_active),
                label: const Text('Set Reminder'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withAlpha(51),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLiveCard(BuildContext context, CallModel call) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withAlpha(38),
            blurRadius: 25,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: _pulseController,
                child: Container(
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
              ),
              const SizedBox(width: 12),
              const Icon(Icons.people_alt_outlined,
                  size: 18, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                "${call.listeners} listening",
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            call.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LiveCallScreen(call: call),
                  ),
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
}
