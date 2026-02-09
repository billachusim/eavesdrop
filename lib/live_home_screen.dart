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
import 'package:eavesdrop/services/ringtone_service.dart';
import 'package:eavesdrop/widgets/call_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import 'auth/onboarding_screen.dart';

class LiveHomeScreen extends StatefulWidget {
  const LiveHomeScreen({super.key});

  @override
  State<LiveHomeScreen> createState() => _LiveHomeScreenState();
}

class _LiveHomeScreenState extends State<LiveHomeScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isMenuOpen = false;

  StreamSubscription? _callsStreamSubscription;
  List<CallModel> _liveCalls = [];
  List<CallModel> _featuredUpcomingCalls = [];
  List<CallModel> _userUpcomingCalls = [];
  List<CallModel> _featuredPastCalls = [];
  User? _user;

  @override
  void initState() {
    super.initState();

    _setupCallsStream();

    _featuredPastCallsSubscription =
        _db.streamFeaturedPastCalls().listen((calls) {
      if (mounted) setState(() => _featuredPastCalls = calls);
    });
  }

  void _setupCallsStream() {
    final liveCallsStream = _db.streamLiveCalls();
    final featuredUpcomingCallsStream = _db.streamUpcomingCalls();

    _callsStreamSubscription = Rx.combineLatest2(
      liveCallsStream,
      featuredUpcomingCallsStream,
      (List<CallModel> live, List<CallModel> upcoming) {
        final allCalls = [...live, ...upcoming];
        allCalls.sort((a, b) => b.startTime.compareTo(a.startTime));
        return allCalls;
      },
    ).listen((calls) {
      if (mounted) {
        setState(() {
          _liveCalls = calls.where((call) => call.isLive).toList();
          _featuredUpcomingCalls = calls.where((call) => !call.isLive).toList();
        });
        if (_liveCalls.isNotEmpty) {
          RingtoneService.playRingtone();
        } else {
          RingtoneService.stopRingtone();
        }
      }
    });
  }

  late StreamSubscription _featuredPastCallsSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<User?>(context);
    if (user != _user) {
      _user = user;
      _userUpcomingCallsSubscription?.cancel();
      if (_user != null) {
        _userUpcomingCallsSubscription =
            _db.streamUserUpcomingCalls(_user!.uid).listen((calls) {
          if (mounted) setState(() => _userUpcomingCalls = calls);
        });
      } else {
        if (mounted) setState(() => _userUpcomingCalls = []);
      }
    }
  }

  StreamSubscription? _userUpcomingCallsSubscription;

  @override
  void dispose() {
    _callsStreamSubscription?.cancel();
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
    return allCalls.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
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
              _buildSection(context,
                  title: "Live Now",
                  calls: _liveCalls,
                  emptyMessage: "No live calls right now."),
              _buildSection(context,
                  title: "Upcoming",
                  calls: _upcomingCalls,
                  emptyMessage: "No upcoming calls scheduled."),
              _buildSection(context,
                  title: "Featured Past Calls",
                  calls: _featuredPastCalls,
                  emptyMessage: "No featured past calls available."),
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        child: const Icon(Icons.calendar_today),
      ),
    );
  }

  Widget _buildMenuButtons(User? user) {
    void navigateToOnboarding() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }

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
        if (user == null)
          TextButton.icon(
            icon: const Icon(Icons.login, color: Colors.white),
            label: const Text('Login', style: TextStyle(color: Colors.white)),
            onPressed: navigateToOnboarding,
          )
        else
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

  Widget _buildSection(BuildContext context, {required String title, required List<CallModel> calls, required String emptyMessage}) {
    final textTheme = GoogleFonts.interTextTheme();

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              title,
              style: textTheme.labelLarge!.copyWith(
                color: Colors.white54,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ),
        if (calls.isEmpty)
           SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(emptyMessage, style: const TextStyle(color: Colors.white54),),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final call = calls[index];
                  return CallCard(
                    call: call,
                    onTap: () {
                       if (call.isLive) {
                         RingtoneService.stopRingtone();
                         Navigator.push(
                           context,
                           MaterialPageRoute(builder: (context) => LiveCallScreen(call: call)),
                         );
                       } else {
                         Navigator.push(
                           context,
                           MaterialPageRoute(builder: (context) => CallDetailsScreen(call: call)),
                         );
                       }
                    },
                    onPlayRecording: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CallDetailsScreen(call: call, autoplay: true)),
                      );
                    },
                  );
                },
                childCount: calls.length,
              ),
            ),
          ),
      ],
    );
  }
}
