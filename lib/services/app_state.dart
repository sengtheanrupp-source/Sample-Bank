import 'package:flutter/widgets.dart';

import '../config.dart';
import '../models/khqr.dart';
import 'api_settings.dart';
import 'payment_api.dart';

class Account {
  final String id;
  final String name;
  final String number;
  final KhqrCurrency currency;
  double balance;

  Account({
    required this.id,
    required this.name,
    required this.number,
    required this.currency,
    required this.balance,
  });
}

class TxRecord {
  final String refNo;
  final String merchant;
  final double amount;
  final KhqrCurrency currency;
  final DateTime at;
  final PaymentStatus status;
  final String remark;

  const TxRecord({
    required this.refNo,
    required this.merchant,
    required this.amount,
    required this.currency,
    required this.at,
    required this.status,
    required this.remark,
  });
}

/// Sample in-memory bank state (accounts, balance, history).
class AppState extends ChangeNotifier {
  AppState(this.settings) {
    settings.addListener(notifyListeners);
  }

  final ApiSettings settings;
  late final PaymentApi api = PaymentApi(settings);

  final List<Account> accounts = [
    Account(
      id: 'sav',
      name: 'Savings',
      number: '001 234 5678',
      currency: KhqrCurrency.usd,
      balance: 250000.00, // sample: USD 100k - 500k
    ),
    Account(
      id: 'riel',
      name: 'Daily Riel',
      number: '002 765 4321',
      currency: KhqrCurrency.khr,
      balance: 500000000, // sample: KHR 100M - 1,000M
    ),
  ];
  final List<TxRecord> history = [];

  late Account selected = accounts.first;
  bool balanceVisible = false;

  void toggleBalance() {
    balanceVisible = !balanceVisible;
    notifyListeners();
  }

  void select(Account a) {
    selected = a;
    notifyListeners();
  }

  double convert(double amount, KhqrCurrency from, KhqrCurrency to) {
    if (from == to) return amount;
    return from == KhqrCurrency.khr
        ? amount / AppConfig.khrPerUsd
        : amount * AppConfig.khrPerUsd;
  }

  bool canAfford(Account a, double amount, KhqrCurrency c) =>
      convert(amount, c, a.currency) <= a.balance + 0.000001;

  void record(Account from, PaymentResult r, String remark) {
    if (r.isSuccess) {
      from.balance -= convert(r.amount + r.fee, r.currency, from.currency);
    }
    history.insert(
      0,
      TxRecord(
        refNo: r.refNo,
        merchant: r.paidTo,
        amount: r.amount,
        currency: r.currency,
        at: r.paidAt,
        status: r.status,
        remark: remark,
      ),
    );
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope(
      {super.key, required AppState state, required super.child})
      : super(notifier: state);

  /// Rebuilds the caller when state changes.
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStateScope>()!.notifier!;

  /// One-off access (e.g. inside callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppStateScope>()!.notifier!;
}
