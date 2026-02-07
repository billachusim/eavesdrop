import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();
    final user = Provider.of<User?>(context);
    final db = DatabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Get Credits"),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DefaultTextStyle(
          style: textTheme.bodyMedium!.copyWith(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live Credit Balance Display
              if (user != null)
                StreamBuilder<UserModel>(
                  stream: db.streamUser(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData) {
                      return const SizedBox.shrink(); // Or a default view
                    }
                    final userModel = snapshot.data!;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "YOUR BALANCE",
                            style: TextStyle(color: Colors.white70, letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${userModel.credits} Credits",
                            style: textTheme.headlineMedium!.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 10),

              Text(
                "Never Miss What’s Being Said.",
                style: textTheme.headlineSmall!.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "Load credits to keep listening when conversations get interesting.",
                style: TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 30),

              /// CREDIT OPTIONS
              Expanded(
                child: ListView(
                  children: const [
                    CreditCard(
                      title: "Starter",
                      credits: "1,200",
                      price: "₦1,500",
                      highlight: false,
                    ),
                    CreditCard(
                      title: "Most Popular",
                      credits: "3,500",
                      price: "₦4,000",
                      highlight: true,
                    ),
                    CreditCard(
                      title: "Best Value",
                      credits: "7,500",
                      price: "₦7,500",
                      highlight: false,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                "Credits are used to enter live conversations and unlock premium calls.",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class CreditCard extends StatelessWidget {
  final String title;
  final String credits;
  final String price;
  final bool highlight;

  const CreditCard({
    super.key,
    required this.title,
    required this.credits,
    required this.price,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF1C1C1C) : const Color(0xFF151515),
        borderRadius: BorderRadius.circular(20),
        border: highlight
            ? Border.all(color: Colors.greenAccent, width: 1.5)
            : null,
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: Colors.greenAccent.withAlpha(64), // Adjusted for non-deprecated use
                  blurRadius: 20,
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlight)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "MOST POPULAR",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 11,
                ),
              ),
            ),

          if (highlight) const SizedBox(height: 10),

          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "$credits Credits",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            price,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // trigger in-app purchase
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    highlight ? Colors.greenAccent : Colors.white,
                foregroundColor:
                    highlight ? Colors.black : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Buy Credits",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
