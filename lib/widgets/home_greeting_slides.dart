import 'package:flutter/material.dart';

class HomeGreetingSlides extends StatelessWidget {
  const HomeGreetingSlides({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      color: Theme.of(context).primaryColor,
      child: const Center(
        child: Text(
          'Book your session now!',
          style: TextStyle(fontSize: 24, color: Colors.white),
        ),
      ),
    );
  }
}
