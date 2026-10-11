import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../providers/app_provider.dart';

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Дневник')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _DiaryEditScreen()),
        ),
        icon: const Icon(Icons.create),
        label: const Text('Запись'),
        backgroundColor: const Color(0xFF7B61FF),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final entries = provider.diaryEntries;
          if (entries.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.book, size: 60, color: Colors.white24),
                  SizedBox(height: 12),
                  Text('Нет записей', style: TextStyle(color: Colors.white38)),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _DiaryCard(
                entry: entry,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _DiaryViewScreen(entry: entry),
                  ),
                ),
                onDelete: () => provider.deleteDiaryEntry(entry.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DiaryCard(
      {required this.entry,
      required this.onTap,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить запись?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Отмена')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Удалить',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirmed == true) onDelete();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E3A),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.moodEmoji, style: const TextStyle(fontSize: 28)),
                Text(
                  DateFormat('dd.MM').format(entry.date),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                entry.content,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: entry.tags
                    .take(2)
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7B61FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('#$t',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF7B61FF))),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiaryViewScreen extends StatelessWidget {
  final DiaryEntry entry;
  const _DiaryViewScreen({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Удалить запись?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Удалить',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                context.read<AppProvider>().deleteDiaryEntry(entry.id);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(entry.moodEmoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.mood,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    Text(
                      DateFormat('dd MMMM yyyy', 'ru').format(entry.date),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              entry.content,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entry.tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7B61FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('#$t',
                              style: const TextStyle(
                                  color: Color(0xFF7B61FF))),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiaryEditScreen extends StatefulWidget {
  const _DiaryEditScreen();

  @override
  State<_DiaryEditScreen> createState() => _DiaryEditScreenState();
}

class _DiaryEditScreenState extends State<_DiaryEditScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  String _mood = 'нормально';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая запись'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Сохранить',
                style: TextStyle(
                    color: Color(0xFF7B61FF),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Заголовок',
                hintText: 'Как прошёл день?',
              ),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            const Text('Настроение',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: DiaryEntry.moods.map((mood) {
                final isSelected = _mood == mood;
                return GestureDetector(
                  onTap: () => setState(() => _mood = mood),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7B61FF)
                          : const Color(0xFF1E1E3A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF7B61FF)
                            : Colors.white24,
                      ),
                    ),
                    child: Text(
                      '${DiaryEntry.moodEmojis[mood]} $mood',
                      style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white60),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _contentCtrl,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Запись',
                hintText: 'Напишите о своём дне...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(
                labelText: 'Теги (через запятую)',
                prefixIcon: Icon(Icons.tag),
                hintText: 'работа, семья, спорт',
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Заполните заголовок и текст записи')),
      );
      return;
    }

    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    context.read<AppProvider>().addDiaryEntry(DiaryEntry(
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          mood: _mood,
          tags: tags,
        ));

    Navigator.pop(context);
  }
}
