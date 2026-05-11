import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'providers.dart';
import 'payment_provider.dart';
import 'payment_history_screen.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _showBalance = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_initialized) return;
    _initialized = true;
    final user = ref.read(userProfileProvider);
    if (user.id.isNotEmpty) {
      await ref.read(walletProvider.notifier).loadWallet(user.id);
      await ref.read(walletProvider.notifier).loadTransactions(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final appTheme = ref.watch(appThemeProvider);
    final wallet = ref.watch(walletProvider);

    final primary = AppThemes.primaryColor(appTheme, isDark);
    final secondary = AppThemes.secondaryColor(appTheme);
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
      body: RefreshIndicator(
        onRefresh: () async {
          final user = ref.read(userProfileProvider);
          if (user.id.isNotEmpty) {
            await ref.read(walletProvider.notifier).loadWallet(user.id);
            await ref.read(walletProvider.notifier).loadTransactions(user.id);
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 20,
                  right: 20,
                  bottom: 28,
                ),
                decoration: BoxDecoration(
                  color: card,
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Mi Billetera',
                            style: TextStyle(
                                color: textPri,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () => setState(() => _showBalance = !_showBalance),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _showBalance ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              color: primary, size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _showBalance
                          ? Text('\$${wallet.balance.toStringAsFixed(2)}',
                              key: const ValueKey('balance'),
                              style: TextStyle(
                                  color: textPri,
                                  fontSize: 44,
                                  fontWeight: FontWeight.bold))
                          : Text('••••••',
                              key: const ValueKey('hidden'),
                              style: TextStyle(
                                  color: textPri,
                                  fontSize: 44,
                                  fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 6),
                    Text('Saldo disponible',
                        style: TextStyle(color: textSec, fontSize: 14)),
                    if (wallet.pendingBalance > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                            '\$${wallet.pendingBalance.toStringAsFixed(2)} pendiente',
                            style: TextStyle(
                                color: const Color(0xFFFFB800), fontSize: 12)),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.add_circle_outline,
                            label: 'Recargar',
                            color: primary,
                            isDark: isDark,
                            card: card,
                            border: border,
                            onTap: () => _showAddFunds(context, ref, isDark, appTheme),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionBtn(
                            icon: Icons.history_rounded,
                            label: 'Historial',
                            color: secondary,
                            isDark: isDark,
                            card: card,
                            border: border,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PaymentHistoryScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Métodos de pago',
                        style: TextStyle(
                            color: textPri,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () => _showAddPaymentMethod(context, ref, isDark, appTheme),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: primary, size: 14),
                            const SizedBox(width: 4),
                            Text('Agregar',
                                style: TextStyle(
                                    color: primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _PaymentMethodsList(
              isDark: isDark,
              card: card,
              textPri: textPri,
              textSec: textSec,
              border: border,
              primary: primary,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Últimos movimientos',
                        style: TextStyle(
                            color: textPri,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    if (wallet.transactions.length > 5)
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaymentHistoryScreen(),
                          ),
                        ),
                        child: Text('Ver todo',
                            style: TextStyle(
                                color: primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ),
            if (wallet.transactions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            color: textSec.withValues(alpha: 0.4), size: 48),
                        const SizedBox(height: 12),
                        Text('Sin movimientos aún',
                            style: TextStyle(color: textSec, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildListDelegate(
                  wallet.transactions.take(5).map((t) => _TransactionTile(
                    transaction: t,
                    isDark: isDark,
                    card: card,
                    textPri: textPri,
                    textSec: textSec,
                    border: border,
                    primary: primary,
                  )).toList(),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  void _showAddFunds(BuildContext context, WidgetRef ref, bool isDark, AppThemeVariant appTheme) {
    final amountCtrl = TextEditingController();
    final bgColor = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).cardColor
        : AppThemes.getTheme(appTheme, Brightness.light).cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF0D1E30);
    final subColor = isDark ? Colors.white54 : const Color(0xFF546E7A);
    final borderColor = isDark ? Colors.white10 : Colors.black12;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text('Recargar saldo',
                style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Text('\$', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(color: subColor, fontSize: 18),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('\$${amount.toStringAsFixed(2)} agregados a tu billetera')),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: AppThemes.gradientColors(appTheme)),
                ),
                child: Center(
                  child: Text('Confirmar recarga',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPaymentMethod(BuildContext context, WidgetRef ref, bool isDark, AppThemeVariant appTheme) {
    final bgColor = isDark
        ? AppThemes.getTheme(appTheme, Brightness.dark).cardColor
        : AppThemes.getTheme(appTheme, Brightness.light).cardColor;
    final textColor = isDark ? Colors.white : const Color(0xFF0D1E30);
    final subColor = isDark ? Colors.white54 : const Color(0xFF546E7A);
    final borderColor = isDark ? Colors.white10 : Colors.black12;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text('Agregar método de pago',
                style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Selecciona el tipo de método que deseas agregar',
                style: TextStyle(color: subColor, fontSize: 13)),
            const SizedBox(height: 24),
            _PaymentTypeOption(
              icon: Icons.credit_card_rounded,
              title: 'Tarjeta',
              subtitle: 'Visa, Mastercard, etc.',
              isDark: isDark,
              border: borderColor,
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Funcionalidad de tarjeta próximamente')),
                );
              },
            ),
            const SizedBox(height: 8),
            _PaymentTypeOption(
              icon: Icons.account_balance_wallet_rounded,
              title: 'PayPal',
              subtitle: 'Cuenta de PayPal',
              isDark: isDark,
              border: borderColor,
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Funcionalidad de PayPal próximamente')),
                );
              },
            ),
            const SizedBox(height: 8),
            _PaymentTypeOption(
              icon: Icons.money_rounded,
              title: 'Efectivo',
              subtitle: 'Paga al conductor en efectivo',
              isDark: isDark,
              border: borderColor,
              textColor: textColor,
              onTap: () {
                ref.read(paymentMethodsProvider.notifier).add(
                  PaymentMethod(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: PaymentType.cash,
                    label: 'Efectivo',
                    detail: 'Pago en efectivo',
                  ),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Efectivo agregado como método de pago')),
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar', style: TextStyle(color: subColor)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final Color card, border;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.card,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

class _PaymentTypeOption extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool isDark;
  final Color border, textColor;
  final VoidCallback onTap;

  const _PaymentTypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.border,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.3)),
        ],
      ),
    ),
  );
}

class _PaymentMethodsList extends ConsumerWidget {
  final bool isDark;
  final Color card, textPri, textSec, border, primary;

  const _PaymentMethodsList({
    required this.isDark,
    required this.card,
    required this.textPri,
    required this.textSec,
    required this.border,
    required this.primary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);
    if (methods.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(Icons.credit_card_outlined, color: textSec.withValues(alpha: 0.5), size: 24),
                const SizedBox(width: 12),
                Text('Sin métodos de pago',
                    style: TextStyle(color: textSec, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildListDelegate(
        methods.map((m) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: m.isDefault ? primary.withValues(alpha: 0.5) : border),
            ),
            child: Row(
              children: [
                Icon(_iconForType(m.type), color: primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(m.label,
                              style: TextStyle(color: textPri, fontWeight: FontWeight.w600, fontSize: 14)),
                          if (m.isDefault)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Default',
                                  style: TextStyle(color: primary, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(m.detail,
                          style: TextStyle(color: textSec, fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (!m.isDefault) {
                      ref.read(paymentMethodsProvider.notifier).setDefault(m.id);
                    }
                  },
                  child: Icon(
                    m.isDefault ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: m.isDefault ? primary : textSec,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  IconData _iconForType(PaymentType type) {
    switch (type) {
      case PaymentType.card:
        return Icons.credit_card_rounded;
      case PaymentType.paypal:
        return Icons.account_balance_wallet_rounded;
      case PaymentType.cash:
        return Icons.money_rounded;
      case PaymentType.applePay:
        return Icons.apple_rounded;
    }
  }
}

class _TransactionTile extends StatelessWidget {
  final PaymentTransaction transaction;
  final bool isDark;
  final Color card, textPri, textSec, border, primary;

  const _TransactionTile({
    required this.transaction,
    required this.isDark,
    required this.card,
    required this.textPri,
    required this.textSec,
    required this.border,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border),
    ),
    child: Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: transaction.isIncome
                ? Colors.green.withValues(alpha: 0.1)
                : primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            transaction.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: transaction.isIncome ? Colors.green : primary,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(transaction.description.isNotEmpty
                      ? transaction.description
                      : 'Transacción',
                  style: TextStyle(color: textPri, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(_formatDate(transaction.createdAt),
                  style: TextStyle(color: textSec, fontSize: 11)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(transaction.amountFormatted,
                style: TextStyle(
                    color: transaction.isIncome ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 2),
            Text(transaction.statusLabel,
                style: TextStyle(
                    color: _statusColor(transaction.status),
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    ),
  );

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Color _statusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return Colors.green;
      case TransactionStatus.pending:
        return const Color(0xFFFFB800);
      case TransactionStatus.failed:
        return Colors.red;
      case TransactionStatus.refunded:
        return Colors.blue;
    }
  }
}
