import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'driver_api_service.dart';
import 'providers.dart';

enum TransactionStatus { pending, completed, failed, refunded }
enum TransactionType { payment, deposit, refund, withdrawal }

class PaymentTransaction {
  final String id;
  final String tripId;
  final double amount;
  final TransactionStatus status;
  final TransactionType type;
  final String description;
  final String paymentMethodLabel;
  final String otherPartyName;
  final String otherPartyAvatar;
  final DateTime createdAt;
  final bool isIncome;

  const PaymentTransaction({
    required this.id,
    this.tripId = '',
    required this.amount,
    this.status = TransactionStatus.completed,
    this.type = TransactionType.payment,
    this.description = '',
    this.paymentMethodLabel = '',
    this.otherPartyName = '',
    this.otherPartyAvatar = '',
    required this.createdAt,
    this.isIncome = false,
  });

  PaymentTransaction copyWith({TransactionStatus? status}) {
    return PaymentTransaction(
      id: id,
      tripId: tripId,
      amount: amount,
      status: status ?? this.status,
      type: type,
      description: description,
      paymentMethodLabel: paymentMethodLabel,
      otherPartyName: otherPartyName,
      otherPartyAvatar: otherPartyAvatar,
      createdAt: createdAt,
      isIncome: isIncome,
    );
  }

  String get statusLabel {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pendiente';
      case TransactionStatus.completed:
        return 'Completado';
      case TransactionStatus.failed:
        return 'Fallido';
      case TransactionStatus.refunded:
        return 'Reembolsado';
    }
  }

  String get amountFormatted {
    final sign = isIncome ? '+' : '-';
    return '$sign\$${amount.toStringAsFixed(2)}';
  }
}

class WalletState {
  final double balance;
  final double pendingBalance;
  final List<PaymentTransaction> transactions;
  final bool loading;
  final String? error;

  const WalletState({
    this.balance = 0.0,
    this.pendingBalance = 0.0,
    this.transactions = const [],
    this.loading = false,
    this.error,
  });

  WalletState copyWith({
    double? balance,
    double? pendingBalance,
    List<PaymentTransaction>? transactions,
    bool? loading,
    String? error,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      pendingBalance: pendingBalance ?? this.pendingBalance,
      transactions: transactions ?? this.transactions,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  final DriverApiService _api;

  WalletNotifier(this._api) : super(const WalletState());

  Future<void> loadWallet(String userId) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final data = await _api.getWallet(userId);
      state = WalletState(
        balance: data['balance'] ?? 0.0,
        pendingBalance: data['pending_balance'] ?? 0.0,
        loading: false,
      );
    } catch (e) {
      debugPrint('loadWallet error: $e');
      state = state.copyWith(loading: false, error: 'Error al cargar wallet');
    }
  }

  Future<void> loadTransactions(String userId) async {
    try {
      final items = await _api.getTransactions(userId);
      state = state.copyWith(
        transactions: items.map((t) {
          TransactionType type;
          switch (t.type) {
            case 'deposit':
              type = TransactionType.deposit;
              break;
            case 'refund':
              type = TransactionType.refund;
              break;
            case 'withdrawal':
              type = TransactionType.withdrawal;
              break;
            default:
              type = TransactionType.payment;
          }
          TransactionStatus status;
          switch (t.status) {
            case 'pending':
              status = TransactionStatus.pending;
              break;
            case 'failed':
              status = TransactionStatus.failed;
              break;
            case 'refunded':
              status = TransactionStatus.refunded;
              break;
            default:
              status = TransactionStatus.completed;
          }
          return PaymentTransaction(
            id: t.id,
            tripId: t.tripId,
            amount: t.amount,
            status: status,
            type: type,
            description: t.description,
            paymentMethodLabel: t.paymentMethodLabel,
            otherPartyName: t.otherPartyName,
            otherPartyAvatar: t.otherPartyAvatar,
            createdAt: DateTime.tryParse(t.createdAt) ?? DateTime.now(),
            isIncome: t.isIncome,
          );
        }).toList(),
      );
    } catch (e) {
      debugPrint('loadTransactions error: $e');
    }
  }

  Future<bool> processPayment({
    required String tripId,
    required double amount,
    required String paymentMethodId,
    String? description,
  }) async {
    try {
      final result = await _api.processPayment(
        tripId: tripId,
        amount: amount,
        paymentMethodId: paymentMethodId,
        description: description ?? 'Pago de viaje',
      );
      if (result) {
        state = state.copyWith(
          balance: state.balance - amount,
          pendingBalance: state.pendingBalance + amount,
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('processPayment error: $e');
      return false;
    }
  }

  Future<bool> confirmPayment(String tripId) async {
    try {
      final result = await _api.confirmPayment(tripId);
      if (result) {
        state = state.copyWith(
          pendingBalance: state.pendingBalance - 0,
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('confirmPayment error: $e');
      return false;
    }
  }
}

final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref.read(driverApiProvider));
});
