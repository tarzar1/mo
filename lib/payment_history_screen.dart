import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'providers.dart';
import 'payment_provider.dart';

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProfileProvider);
      if (user.id.isNotEmpty) {
        ref.read(walletProvider.notifier).loadTransactions(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final appTheme = ref.watch(appThemeProvider);
    final wallet = ref.watch(walletProvider);

    final primary = AppThemes.primaryColor(appTheme, isDark);
    final bg = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).scaffoldBackgroundColor
        : AppThemes.getTheme(appTheme, Brightness.light).scaffoldBackgroundColor;
    final card = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).cardColor
        : AppThemes.getTheme(appTheme, Brightness.light).cardColor;
    final textPri = isDark ? Colors.white : const Color(0xFF0D1E30);
    final textSec = isDark ? Colors.white54 : const Color(0xFF546E7A);
    final border = isDark ? Colors.white10 : Colors.black12;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Historial',
            style: TextStyle(color: textPri, fontWeight: FontWeight.bold)),
        backgroundColor: card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPri),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final user = ref.read(userProfileProvider);
          if (user.id.isNotEmpty) {
            await ref.read(walletProvider.notifier).loadTransactions(user.id);
          }
        },
        child: wallet.transactions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        color: textSec.withValues(alpha: 0.4), size: 64),
                    const SizedBox(height: 16),
                    Text('Sin movimientos',
                        style: TextStyle(color: textSec, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Los pagos aparecerán aquí',
                        style: TextStyle(color: textSec, fontSize: 13)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: wallet.transactions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final t = wallet.transactions[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: t.isIncome
                                ? Colors.green.withValues(alpha: 0.1)
                                : primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            t.isIncome
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: t.isIncome ? Colors.green : primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.description.isNotEmpty
                                    ? t.description
                                    : 'Transacción',
                                style: TextStyle(
                                    color: textPri,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(_formatDate(t.createdAt),
                                  style: TextStyle(
                                      color: textSec, fontSize: 11)),
                              if (t.paymentMethodLabel.isNotEmpty)
                                Text(t.paymentMethodLabel,
                                    style: TextStyle(
                                        color: textSec, fontSize: 11)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(t.amountFormatted,
                                style: TextStyle(
                                    color: t.isIncome
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _statusColor(t.status, withOpacity: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(t.statusLabel,
                                  style: TextStyle(
                                      color: _statusColor(t.status),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Color _statusColor(TransactionStatus status, {double withOpacity = 1.0}) {
    switch (status) {
      case TransactionStatus.completed:
        return Colors.green.withValues(alpha: withOpacity);
      case TransactionStatus.pending:
        return const Color(0xFFFFB800).withValues(alpha: withOpacity);
      case TransactionStatus.failed:
        return Colors.red.withValues(alpha: withOpacity);
      case TransactionStatus.refunded:
        return Colors.blue.withValues(alpha: withOpacity);
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
