import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../../models/loan_model.dart';
import '../../models/payment_model.dart';
import '../../models/transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // Almacenamiento en memoria para Web Chrome
  final List<LoanModel> _webMemoryStore = [];
  final List<PaymentModel> _webPaymentsStore = [];
  int _webIdCounter = 1;
  int _webPaymentIdCounter = 1;

  DatabaseHelper._init();

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDB('prestamos_db.db');
    return _database;
  }

  Future<Database?> _initDB(String filePath) async {
    if (kIsWeb) return null;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE loans (
        id $idType,
        debtorName $textType,
        amount $realType,
        currency $textType,
        borrowDate $textType,
        dueDate $textType,
        paidDate $textNullable,
        status $textType,
        notes $textNullable,
        phone $textNullable,
        paymentFrequency $textType,
        interestValue $realType DEFAULT 0.0,
        interestType $textType DEFAULT "Monto Fijo"
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id $idType,
        loanId $intType,
        amount $realType,
        date $textType,
        note $textNullable
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN phone TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN paymentFrequency TEXT DEFAULT "Fecha Única"');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN interestValue REAL DEFAULT 0.0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN interestType TEXT DEFAULT "Monto Fijo"');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            loanId INTEGER NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            note TEXT
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE loans ADD COLUMN paidDate TEXT');
      } catch (_) {}
    }
  }

  // --- MÉTODOS DE PRÉSTAMOS ---

  Future<int> insertLoan(LoanModel loan) async {
    if (kIsWeb) {
      final newId = _webIdCounter++;
      final loanWithId = loan.copyWith(id: newId);
      _webMemoryStore.add(loanWithId);
      return newId;
    }

    final db = await database;
    return await db!.insert('loans', loan.toMap());
  }

  Future<List<LoanModel>> getAllLoans() async {
    if (kIsWeb) {
      final List<LoanModel> result = [];
      for (var loan in _webMemoryStore) {
        final payments = _webPaymentsStore.where((p) => p.loanId == loan.id).toList();
        result.add(loan.copyWith(payments: payments));
      }
      result.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return result;
    }

    final db = await database;
    final loanMaps = await db!.query('loans', orderBy: 'dueDate ASC');
    final List<LoanModel> loans = [];

    for (var map in loanMaps) {
      final loanId = map['id'] as int;
      final paymentMaps = await db.query('payments', where: 'loanId = ?', whereArgs: [loanId]);
      final payments = paymentMaps.map((pMap) => PaymentModel.fromMap(pMap)).toList();
      loans.add(LoanModel.fromMap(map, payments: payments));
    }

    return loans;
  }

  /// Retorna la lista consolidada de todas las transacciones (Pagos recibidos + Préstamos creados)
  Future<List<TransactionModel>> getAllTransactions() async {
    final loans = await getAllLoans();
    final List<TransactionModel> txs = [];

    for (var loan in loans) {
      // 1. Agregar la transacción de creación del préstamo (-)
      txs.add(TransactionModel(
        id: 'LOAN_${loan.id}',
        debtorName: loan.debtorName,
        amount: loan.totalWithInterest,
        currency: loan.currency,
        date: loan.borrowDate,
        type: 'PRESTAMO',
        note: 'Préstamo otorgado (${loan.paymentFrequency})',
        loanId: loan.id!,
        remainingBalance: loan.remainingBalance,
      ));

      // 2. Agregar cada abono o pago recibido (+)
      for (var p in loan.payments) {
        txs.add(TransactionModel(
          id: 'PAY_${p.id}',
          debtorName: loan.debtorName,
          amount: p.amount,
          currency: loan.currency,
          date: p.date,
          type: 'ABONO',
          note: p.note ?? 'Abono parcial recibido',
          loanId: loan.id!,
          remainingBalance: loan.remainingBalance,
        ));
      }
    }

    // Ordenar de más reciente a más antiguo
    txs.sort((a, b) => b.date.compareTo(a.date));
    return txs;
  }

  Future<int> updateLoan(LoanModel loan) async {
    if (kIsWeb) {
      final index = _webMemoryStore.indexWhere((l) => l.id == loan.id);
      if (index != -1) {
        _webMemoryStore[index] = loan;
        return 1;
      }
      return 0;
    }

    final db = await database;
    return await db!.update(
      'loans',
      loan.toMap(),
      where: 'id = ?',
      whereArgs: [loan.id],
    );
  }

  Future<int> updateStatus(int id, String newStatus) async {
    final paidDateStr = newStatus == 'Pagado' ? DateTime.now().toIso8601String() : null;

    if (kIsWeb) {
      final index = _webMemoryStore.indexWhere((l) => l.id == id);
      if (index != -1) {
        _webMemoryStore[index] = _webMemoryStore[index].copyWith(
          status: newStatus,
          paidDate: newStatus == 'Pagado' ? DateTime.now() : null,
        );
        return 1;
      }
      return 0;
    }

    final db = await database;
    return await db!.update(
      'loans',
      {
        'status': newStatus,
        'paidDate': paidDateStr,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteLoan(int id) async {
    if (kIsWeb) {
      _webMemoryStore.removeWhere((l) => l.id == id);
      _webPaymentsStore.removeWhere((p) => p.loanId == id);
      return 1;
    }

    final db = await database;
    await db!.delete('payments', where: 'loanId = ?', whereArgs: [id]);
    return await db.delete('loans', where: 'id = ?', whereArgs: [id]);
  }

  // --- MÉTODOS DE ABONOS ---

  Future<int> insertPayment(PaymentModel payment) async {
    if (kIsWeb) {
      final newId = _webPaymentIdCounter++;
      final pWithId = PaymentModel(
        id: newId,
        loanId: payment.loanId,
        amount: payment.amount,
        date: payment.date,
        note: payment.note,
      );
      _webPaymentsStore.add(pWithId);
      return newId;
    }

    final db = await database;
    return await db!.insert('payments', payment.toMap());
  }

  Future<int> deletePayment(int paymentId) async {
    if (kIsWeb) {
      _webPaymentsStore.removeWhere((p) => p.id == paymentId);
      return 1;
    }

    final db = await database;
    return await db!.delete('payments', where: 'id = ?', whereArgs: [paymentId]);
  }

  Future<void> replaceAllLoans(List<LoanModel> loans) async {
    if (kIsWeb) {
      _webMemoryStore.clear();
      _webPaymentsStore.clear();
      for (var loan in loans) {
        final newId = loan.id ?? _webIdCounter++;
        _webMemoryStore.add(loan.copyWith(id: newId));
        for (var p in loan.payments) {
          _webPaymentsStore.add(PaymentModel(
            id: _webPaymentIdCounter++,
            loanId: newId,
            amount: p.amount,
            date: p.date,
            note: p.note,
          ));
        }
      }
      return;
    }

    final db = await database;
    await db!.transaction((txn) async {
      await txn.delete('payments');
      await txn.delete('loans');
      for (var loan in loans) {
        final loanId = await txn.insert('loans', loan.toMap());
        for (var p in loan.payments) {
          final pMap = p.toMap();
          pMap['loanId'] = loanId;
          await txn.insert('payments', pMap);
        }
      }
    });
  }

  Future<void> close() async {
    if (!kIsWeb && _database != null) {
      final db = await database;
      await db?.close();
    }
  }
}
