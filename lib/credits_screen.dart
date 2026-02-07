import 'package:eavesdrop/controllers/iap_controller.dart';
import 'package:eavesdrop/models/user_model.dart';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

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
                            style: TextStyle(
                                color: Colors.white70, letterSpacing: 1.5),
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

              Expanded(
                child: Obx(() {
                  if (iapController.isLoading.value) {
                    return const Center(
                        child: CupertinoActivityIndicator(radius: 16));
                  }

                  if (!iapController.isAvailable.value) {
                    return const Center(
                        child: Text("In-app purchases are not available.",
                            style: TextStyle(color: Colors.white70)));
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
              const SizedBox(height: 20),
              _buildFooter(),
              const SizedBox(height: 20),
            ],
          ),
        ),
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
      final AppStoreProductDetails appStoreProductDetails = product;
      final SKProductSubscriptionPeriodWrapper? subscriptionPeriodDetails =
          appStoreProductDetails.skProduct.subscriptionPeriod;
      if (subscriptionPeriodDetails != null) {
        final int numberOfUnits = subscriptionPeriodDetails.numberOfUnits;
        final SKSubscriptionPeriodUnit unit = subscriptionPeriodDetails.unit;

        String unitText = '';
        switch (unit) {
          case SKSubscriptionPeriodUnit.day:
            unitText = numberOfUnits == 1 ? 'day' : 'days';
            break;
          case SKSubscriptionPeriodUnit.week:
            unitText = numberOfUnits == 1 ? 'week' : 'weeks';
            break;
          case SKSubscriptionPeriodUnit.month:
            unitText = numberOfUnits == 1 ? 'month' : 'months';
            break;
          case SKSubscriptionPeriodUnit.year:
            unitText = numberOfUnits == 1 ? 'year' : 'years';
            break;
        }

        if (numberOfUnits == 1) {
          subscriptionPeriod = '/ $unitText';
        } else {
          subscriptionPeriod = '/ $numberOfUnits $unitText';
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPremium
            ? const Color(0xFF1C1C1C)
            : const Color(0xFF151515),
        borderRadius: BorderRadius.circular(20),
        border: isPremium
            ? Border.all(color: Colors.amber, width: 1.5)
            : null,
        boxShadow: isPremium
            ? [
                BoxShadow(
                  color: Colors.amber.withAlpha(64),
                  blurRadius: 20,
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "PREMIUM",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 11,
                ),
              ),
            ),

          if (isPremium) const SizedBox(height: 10),

          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            isPremium ? "Unlimited Access" : product.description,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                product.price,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              if (subscriptionPeriod.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    subscriptionPeriod,
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
            ],
          ),

          if (isPremium)
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPerk("Unlimited access to join and schedule calls"),
                  _buildPerk("10,000 bonus credits monthly"),
                ],
              ),
            ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                iapController.buyProduct(product);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isPremium ? Colors.amber : Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                isPremium ? "Subscribe" : "Buy Credits",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
            "Secure store payment encryption enabled.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _launchUrl(
                    "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"),
                child: const Text("Terms of Use (EULA)", style: linkStyle),
              ),
              const Text("  &  ",
                  style: TextStyle(color: Colors.white, fontSize: 12)),
              GestureDetector(
                onTap: () => _launchUrl(
                    "https://sites.google.com/view/claire-diary/claire-privacy-policy"), // Replace with your privacy policy URL
                child: const Text("Privacy Policy", style: linkStyle),
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
