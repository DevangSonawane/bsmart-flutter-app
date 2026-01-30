import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ledger_model.dart';
import '../models/account_details_model.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;
  AccountDetails? _accountDetails;

  WalletService._internal();

  // Get current coin balance from Supabase.
  // Uses maybeSingle() so missing wallet row (e.g. new user) returns 0 instead of throwing.
  Future<int> getCoinBalance() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    try {
      final response = await _supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', user.id)
          .maybeSingle();
      if (response == null) return 0;

      final balance = response['balance'];
      if (balance is int) return balance;
      if (balance is double) return balance.toInt();
      if (balance is num) return balance.toInt();
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // Get equivalent value (assuming 1 coin = $0.01)
  Future<double> getEquivalentValue() async {
    final balance = await getCoinBalance();
    return balance * 0.01;
  }

  // Get all transactions
  // Currently returns empty list as we don't have a transactions table yet.
  Future<List<LedgerTransaction>> getTransactions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final res = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final items = List<Map<String, dynamic>>.from(res);

      return items.map((item) {
        LedgerTransactionType type = LedgerTransactionType.adReward;
        final typeStr = (item['type'] as String?) ?? 'adReward';
        switch (typeStr) {
          case 'giftReceived':
            type = LedgerTransactionType.giftReceived;
            break;
          case 'giftSent':
            type = LedgerTransactionType.giftSent;
            break;
          case 'payout':
            type = LedgerTransactionType.payout;
            break;
          case 'refund':
            type = LedgerTransactionType.refund;
            break;
          default:
            type = LedgerTransactionType.adReward;
        }

        LedgerTransactionStatus status = LedgerTransactionStatus.pending;
        final statusStr = (item['status'] as String?) ?? 'pending';
        switch (statusStr) {
          case 'completed':
            status = LedgerTransactionStatus.completed;
            break;
          case 'failed':
            status = LedgerTransactionStatus.failed;
            break;
          case 'blocked':
            status = LedgerTransactionStatus.blocked;
            break;
          default:
            status = LedgerTransactionStatus.pending;
        }

        return LedgerTransaction(
          id: item['id'] as String,
          userId: item['user_id'] as String,
          type: type,
          amount: (item['amount'] as num?)?.toInt() ?? 0,
          timestamp: DateTime.parse(item['created_at'] as String),
          status: status,
          description: item['description'] as String?,
          relatedId: item['related_id'] as String?,
          metadata: item['metadata'] as Map<String, dynamic>?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Get filtered transactions
  Future<List<LedgerTransaction>> getFilteredTransactions({
    LedgerTransactionType? type,
    LedgerTransactionStatus? status,
  }) async {
    return [];
  }
  
  // Method to update balance (e.g. after a ledger transaction).
  // Prevents balance from going negative. Uses upsert so wallet row is created if missing.
  Future<void> updateBalance(int amount, String description) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final currentBalance = await getCoinBalance();
      final newBalance = currentBalance + amount;
      if (newBalance < 0) {
        throw StateError('Insufficient balance: cannot go below 0');
      }

      final now = DateTime.now().toIso8601String();
      await _supabase.from('wallets').upsert({
        'user_id': user.id,
        'balance': newBalance,
        'updated_at': now,
      }, onConflict: 'user_id');
    } catch (e) {
      rethrow;
    }
  }

  // Check if user has sufficient balance
  Future<bool> hasSufficientBalance(int amount) async {
    final balance = await getCoinBalance();
    return balance >= amount;
  }

  // Send gift coins to another user.
  // Tries RPC first; fallback: record ledger entries (giftSent / giftReceived) then update both wallets.
  Future<bool> sendGiftCoins(int amount, String recipientId, String recipientName) async {
    if (!await hasSufficientBalance(amount)) return false;

    final me = _supabase.auth.currentUser;
    if (me == null) return false;

    try {
      try {
        await _supabase.rpc('transfer_coins', params: {
          'sender_id': me.id,
          'recipient_id': recipientId,
          'amount': amount,
        });
        return true;
      } catch (_) {
        // RPC not available: ledger-first then update both wallets
      }

      final now = DateTime.now().toIso8601String();
      await _supabase.from('transactions').insert([
        {
          'user_id': me.id,
          'type': 'giftSent',
          'amount': -amount,
          'status': 'completed',
          'description': 'Gift to $recipientName',
          'related_id': recipientId,
          'created_at': now,
        },
        {
          'user_id': recipientId,
          'type': 'giftReceived',
          'amount': amount,
          'status': 'completed',
          'description': 'Gift from ${me.email ?? me.id}',
          'related_id': me.id,
          'created_at': now,
        },
      ]);

      await updateBalance(-amount, 'Gift to $recipientName');

      final resp = await _supabase.from('wallets').select('balance').eq('user_id', recipientId).maybeSingle();
      int recipientBal = 0;
      if (resp != null) {
        final cur = resp['balance'];
        if (cur is int) recipientBal = cur;
        else if (cur is double) recipientBal = cur.toInt();
        else if (cur is num) recipientBal = cur.toInt();
      }
      await _supabase.from('wallets').upsert({
        'user_id': recipientId,
        'balance': recipientBal + amount,
        'updated_at': now,
      }, onConflict: 'user_id');
      return true;
    } catch (_) {
      return false;
    }
  }

  // Add coins via ledger (for ads/rewards).
  // Ledger-first: insert transaction then update balance (per docs: no direct balance add without ledger).
  Future<bool> addCoinsViaLedger({
    required int amount,
    required String description,
    required String adId,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      await _supabase.from('transactions').insert({
        'user_id': user.id,
        'type': 'adReward',
        'amount': amount,
        'status': 'completed',
        'description': description,
        'related_id': adId,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
      await updateBalance(amount, description);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Get account details (Stub - requires new table/column)
  AccountDetails? getAccountDetails() {
    return _accountDetails;
  }

  // Save account details (Stub)
  Future<bool> saveAccountDetails(AccountDetails details) async {
    // Mock success
    // In real app, save to 'user_accounts' table or similar
    await Future.delayed(const Duration(milliseconds: 500));
    _accountDetails = details; // Update local cache if we had one
    return true;
  }

  // Delete account details (Stub)
  Future<void> deleteAccountDetails() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _accountDetails = null;
  }
}
