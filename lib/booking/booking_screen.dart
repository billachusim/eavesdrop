import 'package:booking_calendar/booking_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eavesdrop/admin/user_management_screen.dart';
import 'package:eavesdrop/booking/booking_details_screen.dart';
import 'package:eavesdrop/models/booking_model.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:eavesdrop/widgets/home_greeting_slides.dart';
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

  @override
  void initState() {
    super.initState();
    mockBookingService = BookingService(
        serviceName: 'Book One Hour',
        serviceDuration: 60,
        bookingEnd: DateTime(now.year, now.month, now.day, 23, 59),
        bookingStart: DateTime(now.year, now.month, now.day, 0, 0));
  }

  CollectionReference bookings =
      FirebaseFirestore.instance.collection('bookings');

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
    return bookings
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

    final hostSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('isHost', isEqualTo: true)
        .get();

    if (hostSnapshot.docs.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Error: No host found.')),
      );
      return;
    }

    final hosts = hostSnapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingDetailsScreen(
          booking: newBooking,
          hosts: hosts,
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
          const SliverToBoxAdapter(
            child: HomeGreetingSlides(),
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
          SliverFillRemaining(
            child: BookingCalendar(
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
        ],
      ),
    );
  }
}
