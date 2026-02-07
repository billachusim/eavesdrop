import 'package:eavesdrop/live_call_screen.dart';
import 'package:eavesdrop/models/call_model.dart';
import 'package:eavesdrop/services/ringtone_service.dart';
import 'package:flutter/material.dart';

class IncomingCallScreen extends StatelessWidget {
  final CallModel call;

  const IncomingCallScreen({super.key, required this.call});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Incoming Call',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Text(
              call.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'with ${call.userNickname}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    RingtoneService.stopRingtone();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LiveCallScreen(call: call),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(20),
                  ),
                  child: const Icon(Icons.call, color: Colors.white),
                ),
                ElevatedButton(
                  onPressed: () {
                    RingtoneService.stopRingtone();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(20),
                  ),
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
