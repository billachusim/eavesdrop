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
  late BookingService mockBookingService;
  DateTime? _selectedDay;
  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _selectedDay = now;
    mockBookingService = BookingService(
        serviceName: 'Book Hour',
        serviceDuration: 60,
        bookingEnd: DateTime(now.year, now.month, now.day, 23, 0),
        bookingStart: DateTime(now.year, now.month, now.day, now.hour, 0));
  }

  CollectionReference bookings =
      FirebaseFirestore.instance.collection('bookings');

  List<DateTimeRange> generatePauseSlots() {
    return [
      DateTimeRange(
          start: DateTime(
              _selectedDay!.year, _selectedDay!.month, _selectedDay!.day, 13, 0),
          end: DateTime(
              _selectedDay!.year, _selectedDay!.month, _selectedDay!.day, 16, 0))
    ];
  }

  Stream<dynamic>? getBookingStreamFirebase(
      {required DateTime end, required DateTime start}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!DateUtils.isSameDay(_selectedDay, start)) {
        setState(() {
          _selectedDay = start;
          mockBookingService = BookingService(
              serviceName: 'Book Hour',
              serviceDuration: 60,
              bookingEnd:
                  DateTime(start.year, start.month, start.day, 23, 0),
              bookingStart: DateUtils.isSameDay(start, now)
                  ? DateTime(now.year, now.month, now.day, now.hour, 0)
                  : DateTime(start.year, start.month, start.day, 6, 0));
        });
      }
    });
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
        .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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
          SliverFillRemaining(
            child: Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.deepPurple,
                  surface: Colors.black,
                ),
                canvasColor: Colors.black,
                cardColor: Colors.black,
              ),
              child: BookingCalendar(
                key: ValueKey(_selectedDay),
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
                availableSlotColor: Colors.purple.shade200.withOpacity(0.5),
                selectedSlotColor: Colors.deepPurple,
                bookedSlotColor: Colors.grey.shade800,
                availableSlotTextStyle: const TextStyle(color: Colors.white),
                selectedSlotTextStyle: const TextStyle(color: Colors.white),
                bookedSlotTextStyle: const TextStyle(color: Colors.white),
                wholeDayIsBookedWidget: const Text(
                  'Sorry, for this day everything is booked',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
