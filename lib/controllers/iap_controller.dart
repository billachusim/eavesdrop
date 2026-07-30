import 'dart:async';
import 'dart:io';
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
  final RxString error = ''.obs;

  static String get premiumProductId =>
      Platform.isIOS ? 'eaves_premium_monthly' : 'premium_monthly';

  static Set<String> get _kIds {
    final prefix = Platform.isIOS ? 'eaves_' : '';
    return {
      '${prefix}credits_1200',
      '${prefix}credits_3500',
      '${prefix}credits_7500',
      premiumProductId,
    };
  }

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
    if (kDebugMode) {
      print("IAP_DEBUG: Initializing store info...");
    }
    final bool available = await _inAppPurchase.isAvailable();
    isAvailable.value = available;
    error.value = '';

    if (!available) {
      isLoading.value = false;
      String message = 'In-app purchases are not available on this device.';
      if (Platform.isIOS && !kReleaseMode) {
        message += ' Note: StoreKit may not work on the iOS Simulator if not configured correctly. Try a physical device.';
      }
      error.value = message;
      if (kDebugMode) {
        print("IAP_DEBUG: Store not available. $message");
      }
      return;
    }

    try {
      final ProductDetailsResponse productDetailResponse =
          await _inAppPurchase.queryProductDetails(_kIds);

      if (productDetailResponse.error != null) {
        isLoading.value = false;
        error.value = 'Store error: ${productDetailResponse.error?.message}';
        if (kDebugMode) {
          print('IAP Error: ${productDetailResponse.error?.message}');
          print('IAP Error Details: ${productDetailResponse.error?.details}');
        }
        return;
      }

      if (productDetailResponse.notFoundIDs.isNotEmpty) {
        if (kDebugMode) {
          print('IAP_DEBUG: Product IDs NOT FOUND: ${productDetailResponse.notFoundIDs.join(", ")}');
        }
      }

      if (productDetailResponse.productDetails.isEmpty) {
        if (kDebugMode) {
          print('IAP_DEBUG: No products found in the store.');
        }
        error.value = 'No products found in the store. Please check your internet connection or App Store status.';
      }

      products.value = productDetailResponse.productDetails;
      products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      if (kDebugMode) {
        print("IAP_DEBUG: Loaded ${products.length} products.");
      }
    } catch (e) {
      error.value = 'Failed to load products: ${e.toString()}';
      if (kDebugMode) {
        print("IAP_DEBUG: Exception during initStoreInfo: $e");
      }
    } finally {
      isLoading.value = false;
    }
  }

  void buyProduct(ProductDetails product) {
    if (kDebugMode) {
      print("IAP_DEBUG: Initiating purchase for ProductID: ${product.id}");
    }
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
      if (kDebugMode) {
        print("IAP_DEBUG: Could not initiate purchase: $e");
      }
      Get.snackbar("Error", "Could not initiate purchase: ${e.toString()}",
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // Explicitly for subscriptions as in the reference
  void buySubscription(ProductDetails product) {
    if (kDebugMode) {
      print("IAP_DEBUG: Initiating subscription purchase for ProductID: ${product.id}");
    }
    isLoading.value = true;
    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      isLoading.value = false;
      if (kDebugMode) {
        print("IAP_DEBUG: Could not initiate subscription: $e");
      }
      Get.snackbar("Error", "Could not initiate subscription: ${e.toString()}",
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> restorePurchases() async {
    if (kDebugMode) {
      print("IAP_DEBUG: Restoring purchases...");
    }
    isLoading.value = true;
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      isLoading.value = false;
      if (kDebugMode) {
        print("IAP_DEBUG: Could not restore purchases: $e");
      }
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
          if (kDebugMode) {
            print("IAP_DEBUG: Purchase failed: ${purchaseDetails.error?.message}");
          }
          Get.snackbar("Purchase Error", purchaseDetails.error!.message,
              snackPosition: SnackPosition.BOTTOM);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          
          bool delivered = false;
          if (purchaseDetails.productID == premiumProductId) {
            delivered = await _deliverSubscription(purchaseDetails);
          } else {
            delivered = await _deliverCredits(purchaseDetails);
          }

          if (delivered) {
            if (kDebugMode) {
              print("IAP_DEBUG: Delivery successful. Completing purchase...");
            }
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

  Future<bool> _deliverSubscription(PurchaseDetails purchase) async {
    if (kDebugMode) {
      print("IAP_DEBUG: Starting subscription delivery for ProductID: ${purchase.productID}");
    }
    if (currentUser == null) {
      if (kDebugMode) {
        print("IAP_DEBUG: User ID is null. Cannot deliver subscription.");
      }
      return false;
    }

    try {
      final db = DatabaseService();
      await db.activatePremiumSubscription(currentUser!.uid);
      // Give 10,000 monthly bonus credits for premium
      await db.updateUserCredits(currentUser!.uid, 10000);
      
      if (kDebugMode) {
        print("IAP_DEBUG: Premium subscription activation successful.");
      }
      Get.snackbar("Success", "You are now a premium member!",
          snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("IAP_DEBUG: Exception during subscription activation: $e");
      }
      return false;
    }
  }

  Future<bool> _deliverCredits(PurchaseDetails purchase) async {
    if (kDebugMode) {
      print("IAP_DEBUG: Starting credits delivery for ProductID: ${purchase.productID}");
    }
    if (currentUser == null) {
      if (kDebugMode) {
        print("IAP_DEBUG: User ID is null. Cannot deliver credits.");
      }
      return false;
    }

    int amount = 0;
    final productId = purchase.productID;
    if (productId.contains('credits_1200')) {
      amount = 1200;
    } else if (productId.contains('credits_3500')) {
      amount = 3500;
    } else if (productId.contains('credits_7500')) {
      amount = 7500;
    }

    if (amount == 0) {
      if (kDebugMode) {
        print("IAP_DEBUG: Failed to map ProductID ${purchase.productID} to an amount.");
      }
      return false;
    }

    try {
      final db = DatabaseService();
      await db.updateUserCredits(currentUser!.uid, amount);
      if (kDebugMode) {
        print("IAP_DEBUG: Credited $amount credits to user.");
      }
      Get.snackbar("Success", "You have received $amount credits.",
          snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("IAP_DEBUG: Exception during credits delivery: $e");
      }
      return false;
    }
  }
}
