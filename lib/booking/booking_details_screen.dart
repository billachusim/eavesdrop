import 'dart:ui';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:booking_calendar/booking_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eavesdrop/constants/topic_mood_data.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/booking_model.dart';
import '../models/call_model.dart';
import '../services/database_service.dart';

class BookingDetailsScreen extends StatefulWidget {
  final BookingService booking;
  final UserModel selectedHost;

  const BookingDetailsScreen({
    super.key,
    required this.booking,
    required this.selectedHost,
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedMood;
  bool _isPrivate = false;
  var uuid = const Uuid();
  bool _isLoading = false;
  final List<String> _moods = kMoodOptions;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Event addToCalendar(
      {required String userEmail,
      required DateTime bookingStart,
      required DateTime bookingEnd}) {
    return Event(
      title: 'One Hour Call',
      description: 'You will talk your chosen personality for one hour',
      location: 'Eavesdrop App',
      startDate: bookingStart,
      endDate: bookingEnd,
      allDay: false,
      iosParams: const IOSParams(
        reminder: Duration(minutes: 40),
        url: "https://techfaculty.ng",
      ),
      androidParams: AndroidParams(
        emailInvites: [userEmail],
      ),
    );
  }

  Future<dynamic> saveAndUploadBooking() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final user = context.read<User?>();

    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Error: You are not logged in.')),
      );
      return;
    }

    // --- Show Confirmation Dialog ---
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Booking'),
          content: const Text(
              'This will deduct 300 credits from your account. Do you want to proceed?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return; // User cancelled
    }

    setState(() {
      _isLoading = true;
    });

    try {
      const int cost = 300;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();

      if (userData == null) {
        throw Exception('User data not found.');
      }

      final nickname = userData['displayName'] ?? 'No name';
      final photoURL = userData['photoURL'] ?? '';
      final userEmail = userData['email'] ?? '';
      final userCredits = userData['credits'] as int? ?? 0;

      if (userCredits < cost) {
        throw Exception('You do not have enough credits to make this booking.');
      }

      final bookingId = uuid.v1();
      final channelId = uuid.v4();
      final theBookingStart = widget.booking.bookingStart;
      final theBookingEnd = widget.booking.bookingEnd;

      // 1. Create the BookingModel instance
      final booking = BookingModel(
        userId: user.uid,
        nickname: nickname,
        bookingId: bookingId,
        isTrial: false,
        bookingStart: theBookingStart,
        bookingEnd: theBookingEnd,
        channelId: channelId,
        title: _titleController.text,
        mood: _selectedMood,
        location: _locationController.text,
        personalityId: widget.selectedHost.uid,
        personalityAvatar: widget.selectedHost.photoURL,
        isPrivate: _isPrivate,
      );

      // 2. Create the CallModel instance
      final call = CallModel(
        id: channelId,
        hostId: widget.selectedHost.uid,
        hostName: widget.selectedHost.displayName ?? 'No name',
        callerId: user.uid,
        isPrivate: _isPrivate,
        isLive: false,
        startTime: Timestamp.fromDate(theBookingStart),
        endTime: Timestamp.fromDate(theBookingEnd),
        channelName: channelId,
        title: _titleController.text,
        userNickname: nickname,
        userPhotoURL: photoURL,
        personalityAvatar: widget.selectedHost.photoURL ?? '',
        userLocation: _locationController.text.isNotEmpty
            ? _locationController.text
            : null,
        userMood: _selectedMood,
        bookingId: bookingId,
        hasEnded: false,
        accepted: false,
        connected: false,
        rejected: false,
      );

      // 3. Use the new DatabaseService method
      await DatabaseService().createBookingAndCall(
        booking: booking,
        call: call,
        cost: cost,
      );

      await Add2Calendar.addEvent2Cal(
        addToCalendar(
            userEmail: userEmail,
            bookingStart: theBookingStart,
            bookingEnd: theBookingEnd),
      );

      // Persist the bookingId for future reference if needed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('booking', bookingId);

      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Appointment booked successfully! 300 credits have been deducted.')));
      navigator.pop();
      navigator.pop();
    } catch (e) {
      if (kDebugMode) {
        print('Error saving booking: $e');
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              'Error booking appointment: ${e.toString().replaceFirst("Exception: ", "")}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Set up your appointment'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: Colors.white.withValues(alpha:0.2),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Booking for: ${widget.booking.bookingStart.toLocal().toString().substring(0, 16)} (${DateTime.now().timeZoneName})',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'Total due now: 300 credits',
                      style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white.withValues(alpha:0.2),
                    child: TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Title/Topic',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintText: 'What do you want to talk about?',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white.withValues(alpha:0.2),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedMood,
                      dropdownColor: Colors.deepPurple,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Mood',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      items: _moods.map((String mood) {
                        return DropdownMenuItem<String>(
                          value: mood,
                          child: Text(mood),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedMood = newValue;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'field required' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white.withValues(alpha:0.2),
                    child: TextFormField(
                      controller: _locationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Location (Optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintText: 'Where are you?',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Selected host:',
                      style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: widget.selectedHost.photoURL != null &&
                                  widget.selectedHost.photoURL!.isNotEmpty
                              ? NetworkImage(widget.selectedHost.photoURL!)
                              : null,
                          child: (widget.selectedHost.photoURL == null ||
                                  widget.selectedHost.photoURL!.isEmpty)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.selectedHost.displayName ?? 'Host',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              'Chosen on previous step',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white.withValues(alpha:0.2),
                    child: SwitchListTile(
                      title: const Text('Private Call',
                          style: TextStyle(color: Colors.white)),
                      subtitle: const Text(
                        'If you set this to private, the call will not be broadcasted.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      value: _isPrivate,
                      onChanged: (bool value) {
                        setState(() {
                          _isPrivate = value;
                        });
                      },
                      activeThumbColor: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: saveAndUploadBooking,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 15),
                            ),
                            child: const Text('Confirm & Pay 300 Credits'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
