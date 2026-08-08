import 'package:flutter/material.dart';
import '../core/constants/app_theme.dart';
import '../core/services/backup_service.dart';
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
  String _selectedFilter = 'Todos'; // 'Todos', 'Pendientes', 'Parciales', 'Vencidos', 'Pagados'
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
    final newStatus = loan.isPaid ? 'Pendiente' : 'Pagado';
    await DatabaseHelper.instance.updateStatus(loan.id!, newStatus);

    if (newStatus == 'Pagado') {
      await NotificationService.instance.cancelReminder(loan.id!);
      _showSnackBar('Marcado como PAGADO 🎉');
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

  Future<void> _handleBackupMenu(String choice) async {
    if (_allLoans.isEmpty && (choice == 'export_json' || choice == 'export_csv')) {
      _showSnackBar('No hay registros para exportar', isError: true);
      return;
    }

    if (choice == 'export_json') {
      final success = await BackupService.instance.exportJson(_allLoans);
      if (success) _showSnackBar('Respaldo JSON generado');
    } else if (choice == 'export_csv') {
      final success = await BackupService.instance.exportCsv(_allLoans);
      if (success) _showSnackBar('Reporte CSV generado');
    } else if (choice == 'import_json') {
      try {
        final count = await BackupService.instance.importJson();
        if (count != null) {
          _showSnackBar('Se restauraron $count préstamos con éxito 🔄');
          _loadLoans();
        }
      } catch (e) {
        _showSnackBar('Error al restaurar respaldo: Archivo no válido', isError: true);
      }
    }
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.shield_outlined, color: AppTheme.primaryAccent),
            tooltip: 'Respaldos y Seguridad',
            onSelected: _handleBackupMenu,
            color: AppTheme.cardBg,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export_json',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, color: AppTheme.primaryAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Exportar Respaldo (JSON)', style: TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined, color: AppTheme.success, size: 20),
                    SizedBox(width: 10),
                    Text('Exportar a Excel (CSV)', style: TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'import_json',
                child: Row(
                  children: [
                    Icon(Icons.upload_file_rounded, color: AppTheme.warning, size: 20),
                    SizedBox(width: 10),
                    Text('Restaurar Copia (JSON)', style: TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLoans,
        color: AppTheme.primaryAccent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BÚSQUEDA DIRECTA
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Buscar por deudor o teléfono...',
                  prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 14),

              // PESTAÑAS DE FILTRO CON CONTADORES
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
              const SizedBox(height: 20),

              // ENCABEZADO DE LISTA PRINCIPAL
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedFilter == 'Todos' ? 'Lista de Préstamos' : 'Préstamos: $_selectedFilter',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${filtered.length} registro(s)',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // LISTA DE PRÉSTAMOS
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryAccent),
                  ),
                )
              else if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.folder_off_outlined,
                          size: 64,
                          color: AppTheme.textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No se encontraron coincidencias para "$_searchQuery"'
                              : 'No hay préstamos en la sección $_selectedFilter',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final loan = filtered[index];
                    return LoanTile(
                      loan: loan,
                      onTogglePaid: () => _togglePaid(loan),
                      onDelete: () => _confirmDelete(loan),
                      onEdit: () => _addOrEditLoan(loan),
                      onPaymentAdded: _loadLoans,
                    );
                  },
                ),
            ],
          ),
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
