import 'package:booking_calendar/booking_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eavesdrop/admin/user_management_screen.dart';
import 'package:eavesdrop/booking/booking_details_screen.dart';
import 'package:eavesdrop/models/booking_model.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final now = DateTime.now();
  final _db = DatabaseService();
  late BookingService mockBookingService;
  final CollectionReference _bookings =
      FirebaseFirestore.instance.collection('bookings');
  List<UserModel> _hosts = [];
  UserModel? _selectedHost;

  @override
  void initState() {
    super.initState();
    mockBookingService = BookingService(
        serviceName: 'Book One Hour',
        serviceDuration: 60,
        bookingEnd: DateTime(now.year, now.month, now.day, 23, 59),
        bookingStart: DateTime(now.year, now.month, now.day, 0, 0));
    _loadHosts();
  }

  Future<void> _loadHosts() async {
    final hostSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('isHost', isEqualTo: true)
        .get();

    final hosts = hostSnapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _hosts = hosts;
      if (_selectedHost == null && hosts.isNotEmpty) {
        _selectedHost = hosts.first;
      }
    });
  }

  List<DateTimeRange> generatePauseSlots() {
    return [
      DateTimeRange(
          start: DateTime(now.year, now.month, now.day, 3, 0),
          end: DateTime(now.year, now.month, now.day, 4, 0)),
      DateTimeRange(
          start: DateTime(now.year, now.month, now.day, 11, 0),
          end: DateTime(now.year, now.month, now.day, 12, 0)),
      DateTimeRange(
          start: DateTime(now.year, now.month, now.day, 19, 0),
          end: DateTime(now.year, now.month, now.day, 20, 0))
    ];
  }

  Stream<dynamic>? getBookingStreamFirebase(
      {required DateTime end, required DateTime start}) {
    if (_selectedHost == null) {
      return _bookings
          .where('personalityId', isEqualTo: '__none__')
          .snapshots();
    }

    return _bookings
        .where('personalityId', isEqualTo: _selectedHost!.uid)
        .where('bookingStart', isGreaterThanOrEqualTo: start)
        .where('bookingStart', isLessThanOrEqualTo: end)
        .snapshots();
  }

  List<DateTimeRange> convertStreamResultFirebase(
      {required dynamic streamResult}) {
    List<BookingModel> converted = [];
    for (var i = 0; i < streamResult.size; i++) {
      final item = streamResult.docs[i].data();
      converted.add(BookingModel.fromJson(item));
    }
    return converted
        .map((item) =>
            DateTimeRange(start: item.bookingStart!, end: item.bookingEnd!))
        .toList();
  }

  Future<dynamic> moveToNext({required BookingService newBooking}) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = context.read<User?>();

    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Error: You are not logged in.')),
      );
      return;
    }

    if (_selectedHost == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Error: Please choose a host first.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingDetailsScreen(
          booking: newBooking,
          selectedHost: _selectedHost!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text("Book An Hour"),
            floating: true,
            pinned: true,
            actions: [
              if (user != null)
                StreamBuilder<UserModel>(
                  stream: _db.streamUser(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isAdmin) {
                      return IconButton(
                        icon: const Icon(Icons.admin_panel_settings),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserManagementScreen(),
                            ),
                          );
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amberAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Booking cost: 300 credits · Questions during live calls: 20 credits.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose your host',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 82,
                    child: _hosts.isEmpty
                        ? const Center(
                            child: Text(
                              'No hosts available right now.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _hosts.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final host = _hosts[index];
                              final isSelected = _selectedHost?.uid == host.uid;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedHost = host;
                                  });
                                },
                                child: Container(
                                  width: 76,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.deepPurple.withValues(alpha: 0.28)
                                        : const Color(0xFF1B1B1B),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.deepPurpleAccent
                                          : Colors.white10,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundImage: host.photoURL != null &&
                                                host.photoURL!.isNotEmpty
                                            ? NetworkImage(host.photoURL!)
                                            : null,
                                        child: (host.photoURL == null ||
                                                host.photoURL!.isEmpty)
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        host.displayName ?? 'Host',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: Container(
              color: const Color(0xFF111111),
              padding: const EdgeInsets.only(top: 8),
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Colors.deepPurple,
                    surface: Color(0xFF111111),
                  ),
                  scaffoldBackgroundColor: const Color(0xFF111111),
                  cardColor: const Color(0xFF111111),
                  canvasColor: const Color(0xFF111111),
                  textTheme: Theme.of(context)
                      .textTheme
                      .apply(bodyColor: Colors.white, displayColor: Colors.white),
                ),
                child: BookingCalendar(
                  key: ValueKey(_selectedHost?.uid ?? 'no-host'),
                  bookingService: mockBookingService,
                  convertStreamResultToDateTimeRanges: convertStreamResultFirebase,
                  getBookingStream: getBookingStreamFirebase,
                  uploadBooking: moveToNext,
                  pauseSlots: generatePauseSlots(),
                  pauseSlotText: 'Break',
                  hideBreakTime: false,
                  loadingWidget: const Text('Fetching data...'),
                  uploadingWidget:
                  const Center(child: CircularProgressIndicator()),
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  bookingButtonColor: Colors.deepPurple,
                  availableSlotColor: Colors.green,
                  selectedSlotColor: Colors.blue,
                  wholeDayIsBookedWidget: const Text(
                    'Sorry, for this day everything is booked',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
          )
            )
          )
        ],
      ),
    );
  }
}
