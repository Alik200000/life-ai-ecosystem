import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/task.dart';
import '../models/diary_entry.dart';
import '../models/chat_message.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();

  List<Expense> _expenses = [];
  List<Task> _tasks = [];
  List<DiaryEntry> _diaryEntries = [];
  List<ChatMessage> _chatMessages = [];
  String _apiKey = '';
  String _geminiKey = '';
  String _groqKey = '';
  String _openaiKey = '';
  String _claudeKey = '';
  String _openrouterKey = '';
  String _activeProvider = 'auto';
  bool _autoFallback = true;
  String _syncUrl = 'http://192.168.1.31:5000/api/expenses';
  bool _isLoading = false;
  String? _errorMessage;

  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<Task> get tasks => List.unmodifiable(_tasks);
  List<DiaryEntry> get diaryEntries => List.unmodifiable(_diaryEntries);
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  String get apiKey => _apiKey;
  String get geminiKey => _geminiKey;
  String get groqKey => _groqKey;
  String get openaiKey => _openaiKey;
  String get claudeKey => _claudeKey;
  String get openrouterKey => _openrouterKey;
  String get activeProvider => _activeProvider;
  bool get autoFallback => _autoFallback;
  String get syncUrl => _syncUrl;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ─── Init ────────────────────────────────────────────────────────────────────
  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    _expenses = await _storage.loadExpenses();
    _tasks = await _storage.loadTasks();
    _diaryEntries = await _storage.loadDiaryEntries();
    _chatMessages = await _storage.loadChatHistory();
    _apiKey = await _storage.loadApiKey();

    final aiConfig = await _storage.loadAIConfig();
    _geminiKey = aiConfig['geminiKey'] as String? ?? '';
    _groqKey = aiConfig['groqKey'] as String? ?? '';
    _openaiKey = aiConfig['openaiKey'] as String? ?? '';
    _claudeKey = aiConfig['claudeKey'] as String? ?? '';
    _openrouterKey = aiConfig['openrouterKey'] as String? ?? '';
    _activeProvider = aiConfig['activeProvider'] as String? ?? 'auto';
    _autoFallback = aiConfig['autoFallback'] as bool? ?? true;
    _syncUrl = await _storage.getSyncUrl();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateSyncUrl(String url) async {
    _syncUrl = url.trim();
    await _storage.saveSyncUrl(_syncUrl);
    await syncExpenses();
    notifyListeners();
  }

  // ─── Expenses ────────────────────────────────────────────────────────────────
  Future<void> syncExpenses() async {
    _expenses = await _storage.loadExpenses();
    notifyListeners();
  }

  Future<bool> testApplePaySync() async {
    final ok = await _storage.sendTestApplePayExpense();
    if (ok) {
      await syncExpenses();
    }
    return ok;
  }

  Future<void> addExpense(Expense expense) async {
    _expenses.insert(0, expense);
    await _storage.saveExpenses(_expenses);
    await _storage.postExpenseToServer(expense);
    notifyListeners();
  }

  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    await _storage.saveExpenses(_expenses);
    notifyListeners();
  }

  List<Expense> getMonthlyExpenses() {
    final now = DateTime.now();
    return _expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
  }

  double getMonthlyTotal() {
    return getMonthlyExpenses().fold(0.0, (sum, e) => sum + e.amount);
  }

  Map<String, double> getTotalByCategory() {
    final monthly = getMonthlyExpenses();
    final result = <String, double>{};
    for (final expense in monthly) {
      result[expense.category] =
          (result[expense.category] ?? 0) + expense.amount;
    }
    return result;
  }

  List<Expense> getFilteredExpenses(String filter) {
    final now = DateTime.now();
    switch (filter) {
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return _expenses.where((e) => e.date.isAfter(weekAgo)).toList();
      case 'month':
        return getMonthlyExpenses();
      default:
        return _expenses;
    }
  }

  // ─── Tasks ───────────────────────────────────────────────────────────────────
  Future<void> addTask(Task task) async {
    _tasks.insert(0, task);
    await _storage.saveTasks(_tasks);
    notifyListeners();
  }

  Future<void> toggleTask(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _tasks[idx] = _tasks[idx].copyWith(isCompleted: !_tasks[idx].isCompleted);
      await _storage.saveTasks(_tasks);
      notifyListeners();
    }
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await _storage.saveTasks(_tasks);
    notifyListeners();
  }

  List<Task> getActiveTasks() => _tasks.where((t) => !t.isCompleted).toList();
  List<Task> getCompletedTasks() => _tasks.where((t) => t.isCompleted).toList();

  // ─── Diary ───────────────────────────────────────────────────────────────────
  Future<void> addDiaryEntry(DiaryEntry entry) async {
    _diaryEntries.insert(0, entry);
    await _storage.saveDiaryEntries(_diaryEntries);
    notifyListeners();
  }

  Future<void> deleteDiaryEntry(String id) async {
    _diaryEntries.removeWhere((e) => e.id == id);
    await _storage.saveDiaryEntries(_diaryEntries);
    notifyListeners();
  }

  // ─── Chat ─────────────────────────────────────────────────────────────────────
  Future<void> sendChatMessage(String message) async {
    _errorMessage = null;

    final userMsg = ChatMessage(content: message, isUser: true);
    _chatMessages = [..._chatMessages, userMsg];
    _isLoading = true;
    notifyListeners();

    try {
      final aiService = AIService(
        apiKey: _apiKey,
        geminiKey: _geminiKey,
        groqKey: _groqKey,
        openaiKey: _openaiKey,
        claudeKey: _claudeKey,
        openrouterKey: _openrouterKey,
        activeProvider: _activeProvider,
        autoFallback: _autoFallback,
      );
      final byCategory = getTotalByCategory();
      final topCategory = byCategory.isEmpty
          ? null
          : byCategory.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;

      final context = {
        'monthlyExpenses': getMonthlyTotal(),
        'topCategory': topCategory,
        'activeTasks': getActiveTasks(),
        'lastMood': _diaryEntries.isNotEmpty ? _diaryEntries.first.mood : null,
      };

      final response =
          await aiService.sendMessage(_chatMessages, message, context);

      final badge = response.wasFallback
          ? '${response.providerName} (резервный)'
          : response.providerName;

      final aiMsg = ChatMessage(
        content: response.text,
        isUser: false,
        modelProvider: badge,
      );
      _chatMessages = [..._chatMessages, aiMsg];
      await _storage.saveChatHistory(_chatMessages);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      final errMsg = ChatMessage(
        content: '❌ $_errorMessage',
        isUser: false,
      );
      _chatMessages = [..._chatMessages, errMsg];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> clearChatHistory() async {
    _chatMessages = [];
    await _storage.saveChatHistory([]);
    notifyListeners();
  }

  // ─── API Key & AI Config ──────────────────────────────────────────────────────
  Future<void> saveApiKey(String key) async {
    _apiKey = key;
    await _storage.saveApiKey(key);
    if (key.startsWith('sk-ant-')) {
      _claudeKey = key;
    } else if (key.startsWith('gsk_')) {
      _groqKey = key;
    } else if (key.startsWith('sk-or-')) {
      _openrouterKey = key;
    } else if (key.startsWith('sk-')) {
      _openaiKey = key;
    } else if (key.isNotEmpty) {
      _geminiKey = key;
    }
    await _storage.saveProviderKeys(
      geminiKey: _geminiKey,
      groqKey: _groqKey,
      openaiKey: _openaiKey,
      claudeKey: _claudeKey,
      openrouterKey: _openrouterKey,
      activeProvider: _activeProvider,
      autoFallback: _autoFallback,
    );
    notifyListeners();
  }

  Future<void> saveAIConfig({
    required String geminiKey,
    required String groqKey,
    required String openaiKey,
    required String claudeKey,
    required String openrouterKey,
    required String activeProvider,
    required bool autoFallback,
  }) async {
    _geminiKey = geminiKey;
    _groqKey = groqKey;
    _openaiKey = openaiKey;
    _claudeKey = claudeKey;
    _openrouterKey = openrouterKey;
    _activeProvider = activeProvider;
    _autoFallback = autoFallback;
    await _storage.saveProviderKeys(
      geminiKey: geminiKey,
      groqKey: groqKey,
      openaiKey: openaiKey,
      claudeKey: claudeKey,
      openrouterKey: openrouterKey,
      activeProvider: activeProvider,
      autoFallback: autoFallback,
    );
    notifyListeners();
  }

  // ─── Clear All ────────────────────────────────────────────────────────────────
  Future<void> clearAllData() async {
    _expenses = [];
    _tasks = [];
    _diaryEntries = [];
    _chatMessages = [];
    await _storage.clearAll();
    notifyListeners();
  }
}
