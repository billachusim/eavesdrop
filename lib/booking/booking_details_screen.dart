import 'dart:ui';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:booking_calendar/booking_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class BookingDetailsScreen extends StatefulWidget {
  final BookingService booking;
  final List<UserModel> hosts;

  const BookingDetailsScreen({
    super.key,
    required this.booking,
    required this.hosts,
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedMood;
  UserModel? _selectedHost;
  bool _isPrivate = false;
  var uuid = const Uuid();
  bool _isLoading = false;

  final List<String> _moods = ['Happy', 'Sad', 'Angry', 'Anxious', 'Excited'];

  @override
  void initState() {
    super.initState();
    if (widget.hosts.isNotEmpty) {
      _selectedHost = widget.hosts.first;
    }
  }

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
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final user = context.read<User?>();

      if (user == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Error: You are not logged in.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (_selectedHost == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Error: Please select a personality.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final theBookingStart = widget.booking.bookingStart;
      final theBookingEnd = widget.booking.bookingEnd;

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final nickname = userDoc.data()!['displayName'];
        final userEmail = userDoc.data()!['email'];
        final bookingId = uuid.v1();
        final channelId = uuid.v4();

        final bookingDocRef =
            FirebaseFirestore.instance.collection('bookings').doc(bookingId);
        final callDocRef =
            FirebaseFirestore.instance.collection('calls').doc(channelId);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          transaction.set(
              bookingDocRef,
              {
                'userId': user.uid,
                'nickname': nickname,
                'bookingId': bookingId,
                'isTrial': false,
                'bookingStart': theBookingStart,
                'bookingEnd': theBookingEnd,
                'timeOfBooking': FieldValue.serverTimestamp(),
                'channelId': channelId,
                'title': _titleController.text,
                'mood': _selectedMood,
                'location': _locationController.text,
                'personalityId': _selectedHost!.uid,
                'personalityAvatar': _selectedHost!.photoURL,
                'isPrivate': _isPrivate,
              },
              SetOptions(merge: true));

          transaction.set(
              callDocRef,
              {
                'id': channelId,
                'hostId': _selectedHost!.uid,
                'callerId': user.uid,
                'isPrivate': _isPrivate,
                'isLive': false,
                'startTime': Timestamp.fromDate(theBookingStart),
                'channelName': channelId,
                'title': _titleController.text,
                'userNickname': nickname,
                'personalityAvatar': _selectedHost!.photoURL,
                'bookingId': bookingId,
                'accepted': false,
                'rejected': false,
                'connected': false,
                'hasEnded': false,
              },
              SetOptions(merge: true));
        });

        await Add2Calendar.addEvent2Cal(
          addToCalendar(
              userEmail: userEmail.toString(),
              bookingStart: theBookingStart,
              bookingEnd: theBookingEnd),
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('booking', bookingId);

        messenger.showSnackBar(
            const SnackBar(content: Text('Appointment booked successfully!')));
        navigator.pop();
        navigator.pop();
      } catch (e) {
        if (kDebugMode) {
          print('Error saving booking: $e');
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error booking appointment: $e'),
          ),
        );
      } finally {
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
                    color: Colors.white.withOpacity(0.2),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Booking for: ${widget.booking.bookingStart!.toLocal().toString().substring(0, 16)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white.withOpacity(0.2),
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
                    color: Colors.white.withOpacity(0.2),
                    child: DropdownButtonFormField<String>(
                      value: _selectedMood,
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
                    color: Colors.white.withOpacity(0.2),
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
                  const Text('Choose a personality to talk to:',
                      style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    children: widget.hosts.map((host) {
                      return ChoiceChip(
                        label: Text(host.displayName ?? 'No name',
                            style: const TextStyle(color: Colors.white)),
                        avatar: host.photoURL != null
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(host.photoURL!),
                              )
                            : null,
                        selected: _selectedHost?.uid == host.uid,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedHost = host;
                            }
                          });
                        },
                        backgroundColor: Colors.white.withOpacity(0.2),
                        selectedColor: Colors.deepPurple,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.white.withOpacity(0.2),
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
                      activeColor: Colors.deepPurple,
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
                            child: const Text('Save Booking'),
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
