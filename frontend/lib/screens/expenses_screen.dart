import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../providers/app_provider.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _filter = 'month';

  static const Map<String, IconData> _categoryIcons = {
    'Еда': Icons.restaurant,
    'Транспорт': Icons.directions_car,
    'Развлечения': Icons.sports_esports,
    'Здоровье': Icons.local_hospital,
    'Одежда': Icons.checkroom,
    'Жильё': Icons.home,
    'Другое': Icons.category,
  };

  static const Map<String, Color> _categoryColors = {
    'Еда': Color(0xFFFF6B6B),
    'Транспорт': Color(0xFF4ECDC4),
    'Развлечения': Color(0xFFFFE66D),
    'Здоровье': Color(0xFF95E1D3),
    'Одежда': Color(0xFFF38181),
    'Жильё': Color(0xFFA8E6CF),
    'Другое': Color(0xFF7B61FF),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Расходы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Синхронизировать',
            onPressed: () async {
              await context.read<AppProvider>().syncExpenses();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Расходы синхронизированы с Telegram!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            initialValue: _filter,
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'week', child: Text('Неделя')),
              PopupMenuItem(value: 'month', child: Text('Месяц')),
              PopupMenuItem(value: 'all', child: Text('Все время')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                const Icon(Icons.filter_list),
                const SizedBox(width: 4),
                Text(_filter == 'week'
                    ? 'Неделя'
                    : _filter == 'month'
                        ? 'Месяц'
                        : 'Все'),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
        backgroundColor: const Color(0xFF7B61FF),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final expenses = provider.getFilteredExpenses(_filter);
          final monthly = provider.getMonthlyExpenses();
          final total =
              monthly.fold(0.0, (sum, e) => sum + e.amount);
          final byCategory = provider.getTotalByCategory();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildSummaryCard(total),
                    if (byCategory.isNotEmpty) _buildPieChart(byCategory),
                  ],
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final expense = expenses[index];
                    return _buildExpenseTile(expense, provider);
                  },
                  childCount: expenses.length,
                ),
              ),
              if (expenses.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 60, color: Colors.white24),
                        SizedBox(height: 12),
                        Text('Нет расходов',
                            style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(double total) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B61FF), Color(0xFF00B4D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet,
              color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Расходы за месяц',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                '${NumberFormat('#,##0.00', 'ru_RU').format(total)} ₽',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> byCategory) {
    final total = byCategory.values.fold(0.0, (a, b) => a + b);
    final sections = byCategory.entries.map((e) {
      final color = _categoryColors[e.key] ?? const Color(0xFF7B61FF);
      return PieChartSectionData(
        color: color,
        value: e.value,
        title: '${(e.value / total * 100).toStringAsFixed(0)}%',
        radius: 55,
        titleStyle:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('По категориям',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                height: 150,
                width: 150,
                child: PieChart(PieChartData(
                  sections: sections,
                  centerSpaceRadius: 30,
                  sectionsSpace: 2,
                )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: byCategory.entries.map((e) {
                    final color =
                        _categoryColors[e.key] ?? const Color(0xFF7B61FF);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(e.key,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(
                            '${e.value.toStringAsFixed(0)} ₽',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(Expense expense, AppProvider provider) {
    final color = _categoryColors[expense.category] ?? const Color(0xFF7B61FF);
    final icon = _categoryIcons[expense.category] ?? Icons.category;
    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.withOpacity(0.2),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      onDismissed: (_) => provider.deleteExpense(expense.id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E3A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${expense.category} · ${DateFormat('dd.MM.yyyy').format(expense.date)}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  if (expense.note != null && expense.note!.isNotEmpty)
                    Text(expense.note!,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11)),
                ],
              ),
            ),
            Text(
              '${expense.amount.toStringAsFixed(0)} ₽',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF7B61FF)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String category = Expense.categories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Новый расход',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  prefixIcon: Icon(Icons.edit),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Сумма (₽)',
                  prefixIcon: Icon(Icons.monetization_on),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: 'Категория',
                  prefixIcon: Icon(Icons.category),
                ),
                dropdownColor: const Color(0xFF0F0F1E),
                items: Expense.categories
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setModalState(() => category = v ?? category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Заметка (необязательно)',
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B61FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final amount =
                        double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                    if (titleCtrl.text.isNotEmpty && amount != null) {
                      context.read<AppProvider>().addExpense(Expense(
                            title: titleCtrl.text.trim(),
                            amount: amount,
                            category: category,
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                          ));
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Добавить расход',
                      style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
