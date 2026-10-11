import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onDelete;

  static const Map<String, IconData> _icons = {
    'Еда': Icons.restaurant,
    'Транспорт': Icons.directions_car,
    'Развлечения': Icons.sports_esports,
    'Здоровье': Icons.local_hospital,
    'Одежда': Icons.checkroom,
    'Жильё': Icons.home,
    'Другое': Icons.category,
  };

  static const Map<String, Color> _colors = {
    'Еда': Color(0xFFFF6B6B),
    'Транспорт': Color(0xFF4ECDC4),
    'Развлечения': Color(0xFFFFE66D),
    'Здоровье': Color(0xFF95E1D3),
    'Одежда': Color(0xFFF38181),
    'Жильё': Color(0xFFA8E6CF),
    'Другое': Color(0xFF7B61FF),
  };

  const ExpenseCard({super.key, required this.expense, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = _colors[expense.category] ?? const Color(0xFF7B61FF);
    final icon = _icons[expense.category] ?? Icons.category;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${expense.category} · ${DateFormat('dd.MM.yyyy').format(expense.date)}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
                if (expense.note != null && expense.note!.isNotEmpty)
                  Text(
                    expense.note!,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${expense.amount.toStringAsFixed(0)} ₽',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF7B61FF),
                ),
              ),
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.close,
                      size: 16, color: Colors.white38),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
