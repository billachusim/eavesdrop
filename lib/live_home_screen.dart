import 'dart:async';
import 'package:eavesdrop/admin/admin_dashboard.dart';
import 'package:eavesdrop/auth/auth_service.dart';
import 'package:eavesdrop/booking/booking_screen.dart';
import 'package:eavesdrop/calls/call_details_screen.dart';
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
  bool _isMenuOpen = false;

  late StreamSubscription _liveCallsSubscription;
  late StreamSubscription _featuredUpcomingCallsSubscription;
  StreamSubscription? _userUpcomingCallsSubscription;
  late StreamSubscription _featuredPastCallsSubscription;
  List<CallModel> _liveCalls = [];
  List<CallModel> _featuredUpcomingCalls = [];
  List<CallModel> _userUpcomingCalls = [];
  List<CallModel> _featuredPastCalls = [];
  User? _user;

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

    _featuredUpcomingCallsSubscription = _db.streamUpcomingCalls().listen((calls) {
      if (mounted) setState(() => _featuredUpcomingCalls = calls);
    });

    _featuredPastCallsSubscription = _db.streamFeaturedPastCalls().listen((calls) {
      if (mounted) setState(() => _featuredPastCalls = calls);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<User?>(context);
    if (user != _user) {
      _user = user;
      _userUpcomingCallsSubscription?.cancel();
      if (_user != null) {
        _userUpcomingCallsSubscription = _db.streamUserUpcomingCalls(_user!.uid).listen((calls) {
          if (mounted) setState(() => _userUpcomingCalls = calls);
        });
      } else {
        if (mounted) setState(() => _userUpcomingCalls = []);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _liveCallsSubscription.cancel();
    _featuredUpcomingCallsSubscription.cancel();
    _userUpcomingCallsSubscription?.cancel();
    _featuredPastCallsSubscription.cancel();
    super.dispose();
  }

  List<CallModel> get _upcomingCalls {
    final allCalls = <String, CallModel>{};
    for (var call in _featuredUpcomingCalls) {
      allCalls[call.channelName] = call;
    }
    for (var call in _userUpcomingCalls) {
      allCalls[call.channelName] = call;
    }
    return allCalls.values.toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: DefaultTextStyle(
        style: textTheme.bodyMedium!.copyWith(color: Colors.white),
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                title: _isMenuOpen
                    ? null
                    : Text(
                  "Eavesdrop",
                  style: textTheme.headlineMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(_isMenuOpen ? Icons.close : Icons.settings),
                    onPressed: () {
                      setState(() {
                        _isMenuOpen = !_isMenuOpen;
                      });
                    },
                  ),
                ],
                bottom: _isMenuOpen
                    ? PreferredSize(
                  // Increased height to prevent overflow if buttons wrap
                  preferredSize: const Size.fromHeight(80.0),
                  child: Center(
                    child: Container(
                      height: 80.0,
                      alignment: Alignment.center,
                      child: _buildMenuButtons(_user),
                    ),
                  ),
                )
                    : null,
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
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
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
                          context, _upcomingCalls[index]);
                    },
                    childCount: _upcomingCalls.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 40, 20, 20),
                  child: Text("Featured Past Calls",
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              ),
              _featuredPastCalls.isEmpty
                  ? const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("No featured past calls available."),
                  ),
                ),
              )
                  : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                      return _buildPastCallCard(
                          context, _featuredPastCalls[index]);
                    },
                    childCount: _featuredPastCalls.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please log in to book a call.')),
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

  Widget _buildMenuButtons(User? user) {
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (user != null)
          StreamBuilder<UserModel>(
            stream: _db.streamUser(user.uid),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final userModel = snapshot.data!;
                if (userModel.isAdmin || userModel.isSuperAdmin) {
                  return TextButton.icon(
                    icon: const Icon(Icons.dashboard, color: Colors.white),
                    label: const Text('Admin',
                        style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AdminDashboard()),
                      );
                    },
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
        TextButton.icon(
          icon: const Icon(Icons.monetization_on, color: Colors.white),
          label: const Text('Credits', style: TextStyle(color: Colors.white)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreditsScreen()),
            );
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.call, color: Colors.white),
          label: const Text('My Calls', style: TextStyle(color: Colors.white)),
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
              MaterialPageRoute(builder: (context) => const MyCallsScreen()),
            );
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.logout, color: Colors.white),
          label: const Text('Logout', style: TextStyle(color: Colors.white)),
          onPressed: () async {
            await AuthService().signOut();
            if (mounted) {
              setState(() {
                _isMenuOpen = false;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildPastCallCard(BuildContext context, CallModel call) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          CallCard(
            call: call,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallDetailsScreen(call: call),
                ),
              );
            },
            onPlayRecording: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Playback not implemented yet.')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingCallCard(BuildContext context, CallModel call) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          CallCard(
            call: call,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallDetailsScreen(call: call),
                ),
              );
            },
            onPlayRecording: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCard(BuildContext context, CallModel call) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () {
          if (_user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Please log in to join a call.')),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LiveCallScreen(
                call: call,
              ),
            ),
          );
        },
        child: Card(
          color: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        call.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16),
                        const SizedBox(width: 4),
                        Text(call.listeners.toString()),
                        const SizedBox(width: 20),
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseController.value,
                              child: child,
                            );
                          },
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
