import 'dart:async';
import 'package:eavesdrop/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class IAPController extends GetxController {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  User? currentUser = FirebaseAuth.instance.currentUser;

  final RxList<ProductDetails> products = <ProductDetails>[].obs;
  final RxBool isAvailable = false.obs;
  final RxBool isLoading = true.obs;

  static const String premiumProductId = 'premium_monthly';
  static const Set<String> _kIds = {
    'credits_1200', // Starter
    'credits_3500', // Most Popular
    'credits_7500', // Best Value
    premiumProductId,
  };

  @override
  void onInit() {
    super.onInit();
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      if (kDebugMode) {
        print("IAP Error: $error");
      }
    });
    initStoreInfo();
  }

  @override
  void onClose() {
    _subscription.cancel();
    super.onClose();
  }

  Future<void> initStoreInfo() async {
    final bool available = await _inAppPurchase.isAvailable();
    isAvailable.value = available;

    if (!available) {
      isLoading.value = false;
      return;
    }

    final ProductDetailsResponse productDetailResponse =
        await _inAppPurchase.queryProductDetails(_kIds);

    if (productDetailResponse.error != null) {
      isLoading.value = false;
      if (kDebugMode) {
        print('IAP Error: ${productDetailResponse.error?.message}');
      }
      return;
    }

    if (productDetailResponse.productDetails.isEmpty) {
      if (kDebugMode) {
        print(
            'IAP Info: No products found. Make sure you have configured products in App Store Connect/Google Play Console.');
      }
    }

    products.value = productDetailResponse.productDetails;
    // Optional: Sort products by price
    products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    isLoading.value = false;
  }

  void buyProduct(ProductDetails product) {
    isLoading.value = true;
    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      if (product.id == premiumProductId) {
        _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar("Error", "Could not initiate purchase: ${e.toString()}",
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> restorePurchases() async {
    isLoading.value = true;
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      isLoading.value = false;
      Get.snackbar("Error", "Could not restore purchases: ${e.toString()}",
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        isLoading.value = true;
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          isLoading.value = false;
          Get.snackbar("Purchase Error", purchaseDetails.error!.message,
              snackPosition: SnackPosition.BOTTOM);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          bool delivered = await _handlePurchase(purchaseDetails);
          if (delivered) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        isLoading.value = false;
      }
    }
  }

  Future<bool> _handlePurchase(PurchaseDetails purchaseDetails) async {
    if (currentUser == null) return false;

    final db = DatabaseService();

    if (purchaseDetails.productID == premiumProductId) {
      // Handle subscription
      await db.activatePremiumSubscription(currentUser!.uid);
      // As per request, subscription gives unlimited access, but the example also gives bonus credits.
      // Let's add 10000 bonus credits as in the example.
      await db.updateUserCredits(currentUser!.uid, 10000);
      Get.snackbar("Success", "You are now a premium member!",
          snackPosition: SnackPosition.BOTTOM);
      return true;
    } else {
      // Handle consumable credits
      int amount = 0;
      if (purchaseDetails.productID == 'credits_1200') {
        amount = 1200;
      } else if (purchaseDetails.productID == 'credits_3500') {
        amount = 3500;
      } else if (purchaseDetails.productID == 'credits_7500') {
        amount = 7500;
      }

      if (amount > 0) {
        await db.updateUserCredits(currentUser!.uid, amount);
        Get.snackbar("Success", "You have received $amount credits.",
            snackPosition: SnackPosition.BOTTOM);
        return true;
      }
    }

    return false;
  }
}
