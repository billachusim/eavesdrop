import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String _title = '';
  String _nickname = '';
  String _location = '';
  String _mood = '';
  String _selectedAvatar = 'Claire'; // Default avatar

  final List<String> _avatars = ['Claire', 'The Brutally Honest Friend', 'The Therapist'];

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a Call'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2010, 10, 16),
                lastDay: DateTime.utc(2030, 3, 14),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  }
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title of Call'),
                validator: (val) => val!.isEmpty ? 'Enter a title' : null,
                onChanged: (val) {
                  setState(() => _title = val);
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Your Nickname'),
                validator: (val) => val!.isEmpty ? 'Enter a nickname' : null,
                onChanged: (val) {
                  setState(() => _nickname = val);
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Your Location (Optional)'),
                onChanged: (val) {
                  setState(() => _location = val);
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Your Mood (Optional)'),
                onChanged: (val) {
                  setState(() => _mood = val);
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _selectedAvatar,
                decoration: const InputDecoration(labelText: 'Select an Avatar'),
                items: _avatars.map((String avatar) {
                  return DropdownMenuItem<String>(
                    value: avatar,
                    child: Text(avatar),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedAvatar = newValue!;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate() && _selectedDay != null && user != null) {
                    final navigator = Navigator.of(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final call = CallModel(
                      id: '', // Firestore will generate this
                      hostId: user.uid,
                      callerId: 'placeholder_caller', // To be assigned later
                      isPrivate: false, // Default to public
                      isLive: false,
                      startTime: Timestamp.fromDate(_selectedDay!),
                      channelName: '', // To be generated when the call starts
                      title: _title,
                      userNickname: _nickname,
                      personalityAvatar: _selectedAvatar,
                      userLocation: _location,
                      userMood: _mood,
                    );

                    await _db.bookCall(call, 100); // Charge 100 credits

                    if (!mounted) return;

                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Call booked successfully!')),
                    );

                    navigator.pop();
                  }
                },
                child: const Text('Book Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
