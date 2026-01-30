import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../theme/instagram_theme.dart';
import '../widgets/clay_container.dart';
import 'coins_history_screen.dart';
import 'watch_ads_screen.dart';
import 'gift_coins_screen.dart';
import 'account_details_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  int _coinBalance = 0;
  double _equivalentValue = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final balance = await _walletService.getCoinBalance();
    final value = await _walletService.getEquivalentValue();
    if (mounted) {
      setState(() {
        _coinBalance = balance;
        _equivalentValue = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: Colors.transparent,
        foregroundColor: InstagramTheme.textBlack,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Coins History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CoinsHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadBalance();
        },
        color: InstagramTheme.primaryPink,
        backgroundColor: InstagramTheme.surfaceWhite,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Wallet Balance Card
              ClayContainer(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                borderRadius: 24,
                color: InstagramTheme.surfaceWhite,
                child: Column(
                  children: [
                    const Text(
                      'Total Coins',
                      style: TextStyle(
                        fontSize: 16,
                        color: InstagramTheme.textGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.monetization_on, 
                          color: InstagramTheme.primaryPink, size: 40),
                        const SizedBox(width: 8),
                        Text(
                          _coinBalance.toString(),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: InstagramTheme.textBlack,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: InstagramTheme.primaryPink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: InstagramTheme.primaryPink.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '≈ \$${_equivalentValue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: InstagramTheme.primaryPink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.play_circle_outline,
                      title: 'Watch Ads',
                      subtitle: 'Earn Coins',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const WatchAdsScreen(),
                          ),
                        ).then((_) => _loadBalance());
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.card_giftcard,
                      title: 'Gift Coins',
                      subtitle: 'Send to Friends',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const GiftCoinsScreen(),
                          ),
                        ).then((_) => _loadBalance());
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Menu Options
              _buildMenuSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ClayButton(
      onPressed: onTap,
      color: InstagramTheme.surfaceWhite,
      child: Column(
        children: [
          Icon(icon, size: 32, color: InstagramTheme.primaryPink),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: InstagramTheme.textBlack,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: InstagramTheme.textGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Column(
      children: [
        _buildMenuItem(
          icon: Icons.history,
          title: 'Coins History',
          subtitle: 'View all transactions',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CoinsHistoryScreen(),
              ),
            );
          },
        ),
        _buildMenuItem(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Account Details',
          subtitle: 'Manage payout account',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AccountDetailsScreen(),
              ),
            );
          },
        ),
        _buildMenuItem(
          icon: Icons.help_outline,
          title: 'How to Earn Coins',
          subtitle: 'Learn about earning coins',
          onTap: () {
            _showHowToEarnDialog();
          },
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClayContainer(
        borderRadius: 16,
        color: InstagramTheme.surfaceWhite,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: InstagramTheme.primaryPink.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: InstagramTheme.primaryPink, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: InstagramTheme.textBlack,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: InstagramTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: InstagramTheme.textGrey),
            ],
          ),
        ),
      ),
    );
  }

  void _showHowToEarnDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: InstagramTheme.surfaceWhite,
        title: const Text('How to Earn Coins', 
          style: TextStyle(color: InstagramTheme.textBlack)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(text: '1. Watch Ads: Earn coins by watching advertisements'),
            SizedBox(height: 12),
            _InfoRow(text: '2. Receive Gifts: Get coins from other users'),
            SizedBox(height: 12),
            _InfoRow(text: '3. Complete Tasks: Earn coins by completing various tasks'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it', style: TextStyle(color: InstagramTheme.primaryPink)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String text;
  const _InfoRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, size: 16, color: InstagramTheme.primaryPink),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: InstagramTheme.textGrey)),
        ),
      ],
    );
  }
}
