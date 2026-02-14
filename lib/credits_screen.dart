import 'package:eavesdrop/controllers/iap_controller.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  final IAPController iapController = Get.put(IAPController());

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
        title: const Text('Get Credits'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DefaultTextStyle(
          style: textTheme.bodyMedium!.copyWith(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user != null)
                StreamBuilder<UserModel>(
                  stream: db.streamUser(user.uid),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    final userModel = snapshot.data!;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('YOUR BALANCE',
                              style: TextStyle(color: Colors.white70, letterSpacing: 1.5)),
                          const SizedBox(height: 8),
                          Text(
                            '${userModel.credits} Credits',
                            style: textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              _buildUseCasePacks(),
              const SizedBox(height: 10),
              Expanded(
                child: Obx(() {
                  if (iapController.isLoading.value) {
                    return const Center(child: CupertinoActivityIndicator(radius: 16));
                  }

                  if (!iapController.isAvailable.value) {
                    return const Center(
                      child: Text('In-app purchases are not available.', style: TextStyle(color: Colors.white70)),
                    );
                  }

                  return ListView.builder(
                    itemCount: iapController.products.length,
                    itemBuilder: (context, index) {
                      final product = iapController.products[index];
                      return _buildProductCard(product);
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              _buildSubscriptionTransparency(),
              const SizedBox(height: 12),
              _buildFooter(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUseCasePacks() {
    Widget pack(String title, String subtitle) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        pack('2 Calls', 'Good for occasional deep chats'),
        pack('4 Calls', 'Best for weekly consistency'),
        pack('Unlock + 3 Qs', 'Live room + question credits'),
      ],
    );
  }

  Widget _buildSubscriptionTransparency() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Premium perks transparency', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.amberAccent)),
          SizedBox(height: 4),
          Text('• Unlimited call listening and scheduling'),
          Text('• 10,000 bonus credits monthly'),
          Text('• Priority feature access (beta)'),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductDetails product) {
    final bool isPremium = product.id == IAPController.premiumProductId;
    String title = product.title;
    if (product.title.contains('(')) {
      title = product.title.split('(').first;
    }

    String subscriptionPeriod = '';
    if (isPremium && product is AppStoreProductDetails) {
      final SKProductSubscriptionPeriodWrapper? period = product.skProduct.subscriptionPeriod;
      if (period != null) {
        final numberOfUnits = period.numberOfUnits;
        final unitText = switch (period.unit) {
          SKSubscriptionPeriodUnit.day => numberOfUnits == 1 ? 'day' : 'days',
          SKSubscriptionPeriodUnit.week => numberOfUnits == 1 ? 'week' : 'weeks',
          SKSubscriptionPeriodUnit.month => numberOfUnits == 1 ? 'month' : 'months',
          SKSubscriptionPeriodUnit.year => numberOfUnits == 1 ? 'year' : 'years',
        };
        subscriptionPeriod = numberOfUnits == 1 ? '/ $unitText' : '/ $numberOfUnits $unitText';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPremium ? const Color(0xFF1C1C1C) : const Color(0xFF151515),
        borderRadius: BorderRadius.circular(20),
        border: isPremium ? Border.all(color: Colors.amber, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
              child: const Text('PREMIUM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 11)),
            ),
          if (isPremium) const SizedBox(height: 10),
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            isPremium ? 'Unlimited Access' : product.description,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(product.price, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              if (subscriptionPeriod.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(subscriptionPeriod, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
            ],
          ),
          if (isPremium)
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPerk('Unlimited access to join and schedule calls'),
                  _buildPerk('10,000 bonus credits monthly'),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => iapController.buyProduct(product),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPremium ? Colors.amber : Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(isPremium ? 'Subscribe' : 'Buy Credits', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerk(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    const linkStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white,
      fontSize: 12,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const Text(
            'Secure store payment encryption enabled.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _launchUrl('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                child: const Text('Terms of Use (EULA)', style: linkStyle),
              ),
              const Text('  &  ', style: TextStyle(color: Colors.white, fontSize: 12)),
              GestureDetector(
                onTap: () => _launchUrl('https://sites.google.com/view/claire-diary/claire-privacy-policy'),
                child: const Text('Privacy Policy', style: linkStyle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Get.snackbar('Error', 'Could not launch $url', snackPosition: SnackPosition.BOTTOM);
    }
  }
}
