import 'dart:io';
import 'package:eavesdrop/constants/legal_links.dart';
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
        centerTitle: true,
        title: Text(
          'Credits & Premium',
          style: textTheme.titleLarge!.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Obx(() {
        if (iapController.isLoading.value && iapController.products.isEmpty) {
          return const Center(child: CupertinoActivityIndicator(radius: 16));
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            if (user != null)
              StreamBuilder<UserModel>(
                stream: db.streamUser(user.uid),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final userModel = snapshot.data!;
                  return _buildBalanceHeader(userModel, textTheme);
                },
              ),
            
            if (iapController.error.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        iapController.error.value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => iapController.initStoreInfo(),
                        icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
                        label: const Text('Retry Loading Products', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),

            // Premium Section
            ...iapController.products
                .where((p) => p.id == IAPController.premiumProductId)
                .map((p) => _buildProductCard(p)),

            const SizedBox(height: 10),
            if (iapController.products.any((p) => p.id != IAPController.premiumProductId))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'TOP UP CREDITS',
                  style: TextStyle(color: Colors.white70, letterSpacing: 1.5, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),

            // Credits Section
            ...iapController.products
                .where((p) => p.id != IAPController.premiumProductId)
                .map((p) => _buildProductCard(p)),

            const SizedBox(height: 32),
            _buildFooter(),
            const SizedBox(height: 40),
          ],
        );
      }),
    );
  }

  Widget _buildBalanceHeader(UserModel userModel, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('CURRENT BALANCE',
              style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            '${userModel.credits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} Credits',
            style: textTheme.headlineMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          if (userModel.isPremium)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: const Text('PREMIUM ACTIVE', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductDetails product) {
    final bool isPremium = product.id == IAPController.premiumProductId;
    String title = product.title;
    if (product.title.contains('(')) {
      title = product.title.split('(').first.trim();
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isPremium ? const Color(0xFF1A1A1A) : const Color(0xFF141414),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPremium ? Colors.amber.withValues(alpha: 0.4) : Colors.white10,
          width: isPremium ? 1.5 : 1,
        ),
        boxShadow: isPremium ? [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                  child: const Text('BEST VALUE', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 10)),
                )
              else
                const SizedBox.shrink(),
              Text(
                product.price,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isPremium ? Colors.amber : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPremium ? 'Eavesdrop Premium' : title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            isPremium ? 'Unlimited access & bonus credits' : product.description,
            style: const TextStyle(fontSize: 14, color: Colors.white60),
          ),
          if (isPremium) ...[
            const SizedBox(height: 20),
            _buildPerk('Unlimited call listening & scheduling'),
            _buildPerk('10,000 monthly bonus credits'),
            _buildPerk('Priority access to new features'),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => iapController.buyProduct(product),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPremium ? Colors.amber : Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                isPremium ? 'Subscribe Now $subscriptionPeriod' : 'Get Credits',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerk(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.amber, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    const linkStyle = TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      fontSize: 12,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => iapController.restorePurchases(),
              child: const Text('Restore Purchases', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
            if (Platform.isIOS) ...[
              const Text(' • ', style: TextStyle(color: Colors.white12)),
              TextButton(
                onPressed: () => _launchUrl('https://apps.apple.com/account/subscriptions'),
                child: const Text('Manage Subscriptions', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _launchUrl(LegalLinks.termsOfUse),
              child: const Text('Terms of Use', style: linkStyle),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('|', style: TextStyle(color: Colors.white12)),
            ),
            GestureDetector(
              onTap: () => _launchUrl(LegalLinks.privacyPolicy),
              child: const Text('Privacy Policy', style: linkStyle),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Secure store payment encryption enabled.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white24, fontSize: 10),
        ),
      ],
    );
  }

  void _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Get.snackbar('Error', 'Could not launch $url', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
    }
  }
}
