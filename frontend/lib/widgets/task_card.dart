import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  static Color priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:
        return const Color(0xFFFF6B6B);
      case TaskPriority.medium:
        return const Color(0xFFFFE66D);
      case TaskPriority.low:
        return const Color(0xFF4ECDC4);
    }
  }

  const TaskCard({
    super.key,
    required this.task,
    this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(task.priority);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: ListTile(
        leading: onToggle != null
            ? Checkbox(
                value: task.isCompleted,
                onChanged: (_) => onToggle!(),
                activeColor: const Color(0xFF7B61FF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              )
            : Icon(
                task.isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: task.isCompleted ? const Color(0xFF7B61FF) : Colors.white38,
              ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration:
                task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.white38 : Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty)
              Text(
                task.description,
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.priority.label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (task.dueDate != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.calendar_today,
                      size: 11, color: Colors.white38),
                  const SizedBox(width: 2),
                  Text(
                    DateFormat('dd.MM').format(task.dueDate!),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
