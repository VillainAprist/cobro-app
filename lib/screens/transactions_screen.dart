import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_theme.dart';
import '../core/services/database_helper.dart';
import '../core/utils/formatters.dart';
import '../models/transaction_model.dart';
import '../widgets/receipt_modal.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<TransactionModel> _allTransactions = [];
  bool _isLoading = true;
  String _selectedFilter = 'Todos'; // 'Todos', 'Cobros (+)', 'Préstamos (-)'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final txs = await DatabaseHelper.instance.getAllTransactions();
    setState(() {
      _allTransactions = txs;
      _isLoading = false;
    });
  }

  List<TransactionModel> get _filteredTransactions {
    return _allTransactions.where((tx) {
      final matchesSearch = tx.debtorName.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_selectedFilter == 'Cobros (+)') return tx.isAbono;
      if (_selectedFilter == 'Préstamos (-)') return !tx.isAbono;
      return true;
    }).toList();
  }

  /// Agrupa las transacciones por Mes/Año (ej: "Agosto 2026", "Julio 2026")
  Map<String, List<TransactionModel>> _groupByMonth(List<TransactionModel> txs) {
    final Map<String, List<TransactionModel>> grouped = {};
    for (var tx in txs) {
      final monthKey = DateFormat('MMMM yyyy', 'es').format(tx.date);
      final capitalizedKey = monthKey[0].toUpperCase() + monthKey.substring(1);
      grouped.putIfAbsent(capitalizedKey, () => []).add(tx);
    }
    return grouped;
  }

  /// Agrupa transacciones dentro de un mes por día (ej: "Hoy, 08 de Agosto", "Ayer, 07 de Agosto")
  Map<String, List<TransactionModel>> _groupByDay(List<TransactionModel> txs) {
    final Map<String, List<TransactionModel>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var tx in txs) {
      final txDay = DateTime(tx.date.year, tx.date.month, tx.date.day);
      String dayKey;
      if (txDay == today) {
        dayKey = 'Hoy - ${DateFormat('dd MMMM', 'es').format(tx.date)}';
      } else if (txDay == yesterday) {
        dayKey = 'Ayer - ${DateFormat('dd MMMM', 'es').format(tx.date)}';
      } else {
        dayKey = DateFormat('EEEE dd de MMMM', 'es').format(tx.date);
        dayKey = dayKey[0].toUpperCase() + dayKey.substring(1);
      }
      grouped.putIfAbsent(dayKey, () => []).add(tx);
    }
    return grouped;
  }

  void _showReceipt(TransactionModel tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ReceiptModal(transaction: tx),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;
    final groupedByMonth = _groupByMonth(filtered);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, color: AppTheme.success),
            SizedBox(width: 8),
            Text('Movimientos y Pagos', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        color: AppTheme.primaryAccent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BÚSQUEDA
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Buscar movimiento por deudor...',
                  prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 14),

              // FILTROS
              Row(
                children: [
                  _buildFilterChip('Todos'),
                  _buildFilterChip('Cobros (+)'),
                  _buildFilterChip('Préstamos (-)'),
                ],
              ),
              const SizedBox(height: 20),

              // LISTA SEGMENTADA POR MESES Y DÍAS
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
                )
              else if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No hay movimientos para "$_searchQuery"'
                              : 'No hay movimientos registrados en esta categoría',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: groupedByMonth.entries.map((monthEntry) {
                    final monthName = monthEntry.key;
                    final monthTxs = monthEntry.value;

                    // Calcular total abonado en este mes
                    final monthTotalAbonado = monthTxs
                        .where((t) => t.isAbono)
                        .fold(0.0, (sum, t) => sum + t.amount);

                    final groupedByDay = _groupByDay(monthTxs);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ENCABEZADO DEL MES
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBgLight.withValues(alpha: 0.8),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_month_outlined, color: AppTheme.primaryAccent, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      monthName.toUpperCase(),
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '+ ${AppFormatters.formatCurrency(monthTotalAbonado)}',
                                    style: const TextStyle(
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // LISTA POR DÍAS
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: groupedByDay.entries.map((dayEntry) {
                                final dayTitle = dayEntry.key;
                                final dayTxs = dayEntry.value;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // SUB-ENCABEZADO DE DÍA
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
                                      child: Text(
                                        dayTitle,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),

                                    // ELEMENTOS DE TRANSACCIÓN DEL DÍA
                                    ...dayTxs.map((tx) {
                                      final isAbono = tx.isAbono;
                                      final amountColor = isAbono ? AppTheme.success : AppTheme.primaryAccent;

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.cardBg,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: ListTile(
                                          onTap: () => _showReceipt(tx),
                                          leading: CircleAvatar(
                                            radius: 18,
                                            backgroundColor: amountColor.withValues(alpha: 0.15),
                                            child: Icon(
                                              isAbono ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                              color: amountColor,
                                              size: 18,
                                            ),
                                          ),
                                          title: Text(
                                            tx.debtorName,
                                            style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          subtitle: Text(
                                            tx.note ?? (isAbono ? 'Cobro / Abono parcial' : 'Entrega de préstamo'),
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 11.5,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          trailing: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${isAbono ? '+' : '-'} ${AppFormatters.formatCurrency(tx.amount, tx.currency)}',
                                                style: TextStyle(
                                                  color: amountColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                DateFormat('hh:mm a').format(tx.date),
                                                style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 10.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        selectedColor: AppTheme.primaryAccent,
        backgroundColor: AppTheme.cardBg,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12.5,
        ),
        onSelected: (_) {
          setState(() => _selectedFilter = label);
        },
      ),
    );
  }
}
