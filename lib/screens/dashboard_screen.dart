import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_theme.dart';
import '../core/services/database_helper.dart';
import '../core/services/notification_service.dart';
import '../core/utils/formatters.dart';
import '../models/loan_model.dart';
import '../widgets/loan_tile.dart';
import '../widgets/stat_card.dart';
import 'loan_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<LoanModel> _allLoans = [];
  bool _isLoading = true;
  String _selectedFilter = 'Todos';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    setState(() => _isLoading = true);
    final loans = await DatabaseHelper.instance.getAllLoans();
    setState(() {
      _allLoans = loans;
      _isLoading = false;
    });
  }

  double get _totalBorrowed => _allLoans.fold(0.0, (sum, item) => sum + item.totalWithInterest);
  double get _totalRecovered => _allLoans.fold(0.0, (sum, item) => sum + item.totalPaid);
  double get _pendingBalance => _allLoans.fold(0.0, (sum, item) => sum + item.remainingBalance);

  int get _countPending => _allLoans.where((l) => l.isPending).length;
  int get _countPartial => _allLoans.where((l) => l.isPartial).length;
  int get _countOverdue => _allLoans.where((l) => l.isOverdue).length;
  int get _countPaid => _allLoans.where((l) => l.isPaid).length;

  List<LoanModel> get _filteredLoans {
    return _allLoans.where((loan) {
      final matchesSearch = loan.debtorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (loan.phone != null && loan.phone!.contains(_searchQuery));

      if (!matchesSearch) return false;

      switch (_selectedFilter) {
        case 'Pendientes':
          return loan.isPending;
        case 'Parciales':
          return loan.isPartial;
        case 'Vencidos':
          return loan.isOverdue;
        case 'Pagados':
          return loan.isPaid;
        case 'Todos':
        default:
          return true;
      }
    }).toList();
  }

  /// Agrupa los préstamos por Mes y Año (ej: "Setiembre 2026", "Agosto 2026")
  Map<String, List<LoanModel>> _groupByMonthAndYear(List<LoanModel> loans) {
    final Map<String, List<LoanModel>> grouped = {};
    for (var loan in loans) {
      final monthKey = DateFormat('MMMM yyyy', 'es').format(loan.dueDate);
      final capitalizedKey = monthKey[0].toUpperCase() + monthKey.substring(1);
      grouped.putIfAbsent(capitalizedKey, () => []).add(loan);
    }
    return grouped;
  }

  Future<void> _addOrEditLoan([LoanModel? existingLoan]) async {
    final result = await showModalBottomSheet<LoanModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LoanFormScreen(initialLoan: existingLoan),
    );

    if (result != null) {
      if (existingLoan == null) {
        final id = await DatabaseHelper.instance.insertLoan(result);
        final newLoan = result.copyWith(id: id);
        await NotificationService.instance.scheduleLoanReminder(newLoan);
        _showSnackBar('Préstamo registrado exitosamente');
      } else {
        await DatabaseHelper.instance.updateLoan(result);
        await NotificationService.instance.scheduleLoanReminder(result);
        _showSnackBar('Préstamo actualizado');
      }
      _loadLoans();
    }
  }

  Future<void> _togglePaid(LoanModel loan) async {
    if (!loan.isPaid) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: AppTheme.success),
              SizedBox(width: 8),
              Text('¿Confirmar Pago?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            '¿Estás seguro de marcar como PAGADO por completo el préstamo de ${loan.debtorName} por un saldo pendiente de ${AppFormatters.formatCurrency(loan.remainingBalance, loan.currency)}?',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check, color: Colors.white, size: 18),
              label: const Text('Sí, Confirmar Pago', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    final newStatus = loan.isPaid ? 'Pendiente' : 'Pagado';
    await DatabaseHelper.instance.updateStatus(loan.id!, newStatus);

    if (newStatus == 'Pagado') {
      await NotificationService.instance.cancelReminder(loan.id!);
      _showSnackBar('🎉 Pago completado y registrado');
    } else {
      await NotificationService.instance.scheduleLoanReminder(loan.copyWith(status: newStatus));
      _showSnackBar('Estado cambiado a PENDIENTE');
    }

    _loadLoans();
  }

  Future<void> _confirmDelete(LoanModel loan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Eliminar Préstamo', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '¿Estás seguro de eliminar el registro de ${loan.debtorName} por ${AppFormatters.formatCurrency(loan.remainingBalance, loan.currency)}?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && loan.id != null) {
      await DatabaseHelper.instance.deleteLoan(loan.id!);
      await NotificationService.instance.cancelReminder(loan.id!);
      _showSnackBar('Registro eliminado');
      _loadLoans();
    }
  }

  void _showStatsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '📊 Control y Balances',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'TOTAL PRESTADO',
                      amountFormatted: AppFormatters.formatCurrency(_totalBorrowed),
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppTheme.primaryAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'TOTAL COBRADO',
                      amountFormatted: AppFormatters.formatCurrency(_totalRecovered),
                      icon: Icons.check_circle_outline_rounded,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StatCard(
                title: 'BALANCE PENDIENTE POR RECOLECTAR',
                amountFormatted: AppFormatters.formatCurrency(_pendingBalance),
                icon: Icons.pending_actions_rounded,
                color: AppTheme.warning,
                subtitle: '${_allLoans.where((l) => !l.isPaid).length} préstamos activos por cobrar',
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.danger : AppTheme.primaryAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLoans;
    final groupedLoans = _groupByMonthAndYear(filtered);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.handshake_outlined, color: AppTheme.primaryAccent),
            SizedBox(width: 8),
            Text('Préstamos y Cobros', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showStatsDialog,
            icon: const Icon(Icons.bar_chart_rounded, color: AppTheme.warning),
            tooltip: 'Ver Balances y Estadísticas',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLoans,
        color: AppTheme.primaryAccent,
        child: Column(
          children: [
            // PANEL FIJO DE BÚSQUEDA Y FILTROS
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por deudor o teléfono...',
                      prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Todos', _allLoans.length, Colors.white),
                        _buildFilterChip('Pendientes', _countPending, AppTheme.warning),
                        _buildFilterChip('Parciales', _countPartial, const Color(0xFF06B6D4)),
                        _buildFilterChip('Vencidos', _countOverdue, AppTheme.danger),
                        _buildFilterChip('Pagados', _countPaid, AppTheme.success),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // CONTENIDO PRINCIPAL CON STICKY HEADERS POR MES Y AÑO
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_off_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No se encontraron coincidencias para "$_searchQuery"'
                                    : 'No hay préstamos en la sección $_selectedFilter',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : CustomScrollView(
                          slivers: groupedLoans.entries.map((entry) {
                            final monthYearHeader = entry.key;
                            final monthLoans = entry.value;

                            return SliverMainAxisGroup(
                              slivers: [
                                // ENCABEZADO PEGAJOSO EN GRIS ESTILO YAPE (SOLO MES Y AÑO)
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: _StickyMonthHeaderDelegate(
                                    monthYear: monthYearHeader.toUpperCase(),
                                  ),
                                ),

                                // LISTA DE PRÉSTAMOS DEL MES
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final loan = monthLoans[index];
                                        return LoanTile(
                                          loan: loan,
                                          onTogglePaid: () => _togglePaid(loan),
                                          onDelete: () => _confirmDelete(loan),
                                          onEdit: () => _addOrEditLoan(loan),
                                          onPaymentAdded: _loadLoans,
                                        );
                                      },
                                      childCount: monthLoans.length,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditLoan(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo Préstamo', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, Color accentColor) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white24 : accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        selectedColor: AppTheme.primaryAccent,
        backgroundColor: AppTheme.cardBg,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) {
          setState(() => _selectedFilter = label);
        },
      ),
    );
  }
}

/// Delegate para crear el Sticky Header Gris de Yape con SOLO MES Y AÑO
class _StickyMonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String monthYear;

  _StickyMonthHeaderDelegate({required this.monthYear});

  @override
  double get minExtent => 36.0;

  @override
  double get maxExtent => 36.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF1E293B), // Gris oscuro Yape
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        monthYear,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyMonthHeaderDelegate oldDelegate) {
    return oldDelegate.monthYear != monthYear;
  }
}
