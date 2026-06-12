import 'package:flutter/foundation.dart';
import 'app_diag_log.dart';

/// Payment gateway scaffold — **not live**. Wire StoreKit / Play Billing / Stripe here.
class PaymentGatewayService {
  PaymentGatewayService._();
  static final PaymentGatewayService instance = PaymentGatewayService._();

  bool _initialized = false;

  /// Stripe publishable key or IAP product catalog — from env at build time.
  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const bool paymentsEnabled = bool.fromEnvironment(
    'PAYMENTS_ENABLED',
    defaultValue: false,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    
      AppDiagLog.verbose('[PaymentGateway] scaffold only — PAYMENTS_ENABLED=$paymentsEnabled');
    
    _initialized = true;
  }

  /// Placeholder: start subscription checkout.
  Future<PaymentResult> purchaseSubscription({required String productSku}) async {
    await initialize();
    if (!paymentsEnabled) {
      return PaymentResult.failed('payments_not_enabled');
    }
    return PaymentResult.failed('gateway_not_configured');
  }

  /// Placeholder: restore purchases (mobile stores).
  Future<PaymentResult> restorePurchases() async {
    await initialize();
    return PaymentResult.failed('payments_not_enabled');
  }
}

class PaymentResult {
  const PaymentResult._({required this.ok, this.errorKey, this.receiptId});

  factory PaymentResult.success({String? receiptId}) =>
      PaymentResult._(ok: true, receiptId: receiptId);

  factory PaymentResult.failed(String key) => PaymentResult._(ok: false, errorKey: key);

  final bool ok;
  final String? errorKey;
  final String? receiptId;
}
