import 'dart:async';
import 'package:eavesdrop/admin/admin_dashboard.dart';
import 'package:eavesdrop/booking/booking_screen.dart';
import 'package:eavesdrop/calls/call_details_screen.dart';
import 'package:eavesdrop/calls/favorite_calls_screen.dart';
import 'package:eavesdrop/calls/my_calls_screen.dart';
import 'package:eavesdrop/constants/topic_mood_data.dart';
import 'package:eavesdrop/credits_screen.dart';
import 'package:eavesdrop/live_call_screen.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:eavesdrop/widgets/call_card.dart';
import 'package:eavesdrop/widgets/settings_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'auth/onboarding_screen.dart';

enum HomeFeedFilter { all, live, soon, week, past }

class LiveHomeScreen extends StatefulWidget {
  const LiveHomeScreen({super.key});

  @override
  State<LiveHomeScreen> createState() => _LiveHomeScreenState();
}

class _LiveHomeScreenState extends State<LiveHomeScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  HomeFeedFilter _activeFilter = HomeFeedFilter.all;
  String _searchQuery = '';
  bool _isMenuOpen = false;

  final List<String> _recommendedTopics = kConversationTopics;

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

    _featuredPastCallsSubscription = _db.streamFeaturedPastCalls().listen((
      calls,
    ) {
      if (mounted) setState(() => _featuredPastCalls = calls);
    });
  }

  void _setupCallsStream() {
    final liveCallsStream = _db.streamLiveCalls();
    final featuredUpcomingCallsStream = _db.streamUpcomingCalls();

    _callsStreamSubscription =
        Rx.combineLatest2(liveCallsStream, featuredUpcomingCallsStream, (
          List<CallModel> live,
          List<CallModel> upcoming,
        ) {
          final allCalls = [...live, ...upcoming];
          allCalls.sort((a, b) => b.startTime.compareTo(a.startTime));
          return allCalls;
        }).listen((calls) {
          if (mounted) {
            final newLiveCalls = calls.where((call) => call.isLive).toList();
            final newFeaturedUpcomingCalls = calls
                .where((call) => !call.isLive)
                .toList();

            setState(() {
              _liveCalls = newLiveCalls;
              _featuredUpcomingCalls = newFeaturedUpcomingCalls;
            });

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
        _userUpcomingCallsSubscription = _db
            .streamUserUpcomingCalls(_user!.uid)
            .listen((calls) {
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
    _searchController.dispose();
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
                    icon: Icon(_isMenuOpen ? Icons.close : Icons.menu_rounded),
                    onPressed: () {
                      setState(() {
                        _isMenuOpen = !_isMenuOpen;
                      });
                    },
                  ),
                ],
                bottom: _isMenuOpen
                    ? PreferredSize(
                        preferredSize: Size.fromHeight(
                          _user != null ? 250.0 : 206.0,
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 48.0,
                              child: _buildMenuButtons(_user),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(height: 44, child: _buildFilterChips()),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) =>
                                    setState(() => _searchQuery = value),
                                decoration: InputDecoration(
                                  hintText: 'Search topic, mood, host, date…',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                          icon: const Icon(Icons.close),
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: const Color(0xFF1A1A1A),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            if (_user != null) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: _buildTopicFollowChips(),
                              ),
                            ],
                            const SizedBox(height: 8),
                          ],
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
          body: StreamBuilder<UserModel>(
            stream: _user != null ? _db.streamUser(_user!.uid) : null,
            builder: (context, userSnap) {
              final userModel = userSnap.data;
              return CustomScrollView(
                slivers: <Widget>[
                  if (userModel != null && !userModel.isPremium)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CreditsScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.black, size: 30),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Upgrade to Premium",
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Text(
                                        "Unlimited calls & bonus credits",
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  _buildSection(
                    context,
                    title: 'Live Now',
                    isLiveSection: true,
                    calls: _applySearch(
                      _applySafetyFilters(
                        _applyPersonalization(
                          _applyFilter(_liveCalls),
                          userModel,
                        ),
                        userModel,
                      ),
                    ),
                    emptyMessage: 'No live calls right now.',
                  ),
                  _buildSection(
                    context,
                    title: 'Upcoming',
                    calls: _applySearch(
                      _applySafetyFilters(
                        _applyPersonalization(
                          _applyFilter(_upcomingCalls),
                          userModel,
                        ),
                        userModel,
                      ),
                    ),
                    emptyMessage: 'No upcoming calls scheduled.',
                  ),
                  _buildSection(
                    context,
                    title: 'Featured Past Calls',
                    calls: _applySearch(
                      _applySafetyFilters(
                        _applyPersonalization(
                          _applyFilter(_featuredPastCalls),
                          userModel,
                        ),
                        userModel,
                      ),
                    ),
                    emptyMessage: 'No featured past calls available.',
                  ),
                ],
              );
            },
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

  List<CallModel> _applyFilter(List<CallModel> calls) {
    final now = DateTime.now();
    switch (_activeFilter) {
      case HomeFeedFilter.live:
        return calls.where((c) => c.isLive).toList();
      case HomeFeedFilter.soon:
        return calls
            .where((c) => !c.isLive && c.startTime.toDate().isAfter(now))
            .where((c) => c.startTime.toDate().difference(now).inHours <= 24)
            .toList();
      case HomeFeedFilter.week:
        return calls
            .where((c) => !c.isLive && c.startTime.toDate().isAfter(now))
            .where((c) => c.startTime.toDate().difference(now).inDays <= 7)
            .toList();
      case HomeFeedFilter.past:
        return calls
            .where((c) => !c.isLive && c.startTime.toDate().isBefore(now))
            .toList();
      case HomeFeedFilter.all:
        return calls;
    }
  }

  List<CallModel> _applySafetyFilters(
    List<CallModel> calls,
    UserModel? userModel,
  ) {
    if (userModel == null) return calls;

    final hiddenCallIds = userModel.hiddenCallIds.toSet();
    final blockedUserIds = userModel.blockedUserIds.toSet();

    return calls
        .where((call) => !hiddenCallIds.contains(call.id))
        .where((call) => !blockedUserIds.contains(call.callerId))
        .toList();
  }

  List<CallModel> _applySearch(List<CallModel> calls) {
    if (_searchQuery.trim().isEmpty) return calls;
    final q = _searchQuery.toLowerCase();
    return calls.where((c) {
      return c.title.toLowerCase().contains(q) ||
          c.userNickname.toLowerCase().contains(q) ||
          c.hostName.toLowerCase().contains(q) ||
          (c.userMood?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<CallModel> _applyPersonalization(
    List<CallModel> calls,
    UserModel? userModel,
  ) {
    if (userModel == null) return calls;
    final followedHosts = userModel.followedHostIds.toSet();
    final followedTopics = userModel.followedTopics
        .map((e) => e.toLowerCase())
        .toSet();
    final prioritized = [...calls]
      ..sort((a, b) {
        int score(CallModel call) {
          final hostScore = followedHosts.contains(call.hostId) ? 2 : 0;
          final topicScore =
              followedTopics.any(
                (topic) =>
                    call.title.toLowerCase().contains(topic) ||
                    (call.userMood?.toLowerCase().contains(topic) ?? false),
              )
              ? 1
              : 0;
          return hostScore + topicScore;
        }

        return score(b).compareTo(score(a));
      });
    return prioritized;
  }

  Widget _buildFilterChips() {
    Widget chip(HomeFeedFilter filter, String label) {
      final selected = _activeFilter == filter;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _activeFilter = filter),
          selectedColor: Colors.white,
          labelStyle: TextStyle(color: selected ? Colors.black : Colors.white),
          backgroundColor: const Color(0xFF1D1D1D),
          side: BorderSide.none,
        ),
      );
    }

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        chip(HomeFeedFilter.all, 'All'),
        chip(HomeFeedFilter.live, 'Live'),
        chip(HomeFeedFilter.soon, 'Soon'),
        chip(HomeFeedFilter.week, 'This Week'),
        chip(HomeFeedFilter.past, 'Past'),
      ],
    );
  }

  Widget _buildMenuButtons(User? user) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                    label: const Text(
                      'Admin',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminDashboard(),
                        ),
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
                  content: Text('Please log in to see your calls.'),
                ),
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
          icon: const Icon(Icons.bookmark, color: Colors.white),
          label: const Text('Saved', style: TextStyle(color: Colors.white)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FavoriteCallsScreen(),
              ),
            );
          },
        ),
        if (user == null)
          TextButton.icon(
            icon: const Icon(Icons.login, color: Colors.white),
            label: const Text('Login', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OnboardingScreen(),
                ),
              );
            },
          )
        else
          TextButton.icon(
            icon: const Icon(Icons.settings_outlined),
            label:
            const Text('Settings', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()));
            },
          ),
      ],
    );
  }


  Widget _buildTopicFollowChips() {
    if (_user == null) return const SizedBox.shrink();
    return StreamBuilder<UserModel>(
      stream: _db.streamUser(_user!.uid),
      builder: (context, snapshot) {
        final followed = (snapshot.data?.followedTopics ?? const <String>[])
            .map((e) => e.toLowerCase())
            .toSet();
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: _recommendedTopics.map((topic) {
            final isSelected = followed.contains(topic.toLowerCase());
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(topic),
                selected: isSelected,
                onSelected: (selected) async {
                  if (selected) {
                    await _db.followTopic(_user!.uid, topic);
                  } else {
                    await _db.unfollowTopic(_user!.uid, topic);
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<CallModel> calls,
    required String emptyMessage,
    bool isLiveSection = false,
  }) {
    final textTheme = GoogleFonts.interTextTheme();

    // Special case for guest users in the Live section when there are actual live calls
    final bool showGuestLiveTeaser = isLiveSection && _user == null && _liveCalls.isNotEmpty;
    final List<CallModel> effectiveCalls = (_user == null && isLiveSection) ? [] : calls;

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
        if (effectiveCalls.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      showGuestLiveTeaser ? Icons.live_tv_rounded : Icons.inbox_outlined,
                      color: showGuestLiveTeaser ? Colors.redAccent : Colors.white38,
                      size: 36,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      showGuestLiveTeaser
                          ? 'There are ${_liveCalls.length} live conversations right now!'
                          : emptyMessage,
                      style: TextStyle(
                        color: showGuestLiveTeaser ? Colors.white : Colors.white54,
                        fontWeight: showGuestLiveTeaser ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        if (_user == null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OnboardingScreen(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BookingScreen(),
                            ),
                          );
                        }
                      },
                      style: showGuestLiveTeaser ? OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        foregroundColor: Colors.redAccent,
                      ) : null,
                      child: Text(
                        _user == null
                            ? (isLiveSection ? 'Log in to see live calls' : 'Log in to book a call')
                            : 'Book your next call',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((
                BuildContext context,
                int index,
              ) {
                final call = calls[index];
                return CallCard(
                  call: call,
                  onTap: () {
                    if (call.isLive) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LiveCallScreen(call: call),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CallDetailsScreen(call: call),
                        ),
                      );
                    }
                  },
                  onPlayRecording: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CallDetailsScreen(call: call, autoplay: true),
                      ),
                    );
                  },
                );
              }, childCount: calls.length),
            ),
          ),
      ],
    );
  }
}
