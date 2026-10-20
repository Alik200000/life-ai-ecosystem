import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../models/task.dart';
import '../models/diary_entry.dart';
import '../models/chat_message.dart';

import 'package:http/http.dart' as http;

class StorageService {
  static const _expensesKey = 'expenses';
  static const _tasksKey = 'tasks';
  static const _diaryKey = 'diary_entries';
  static const _chatKey = 'chat_history';
  static const _apiKeyKey = 'api_key';
  static const _syncUrlKey = 'sync_api_url';
  static const _defaultSyncApiUrl = 'http://192.168.1.31:5000/api/expenses';

  Future<String> getSyncUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_syncUrlKey) ?? _defaultSyncApiUrl;
  }

  Future<void> saveSyncUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncUrlKey, url.trim());
  }

  // ─── Expenses ───────────────────────────────────────────────────────────────
  Future<void> saveExpenses(List<Expense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = expenses.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_expensesKey, jsonList);
  }

  Future<void> postExpenseToServer(Expense expense) async {
    try {
      final syncUrl = await getSyncUrl();
      if (syncUrl.trim().isEmpty) return;
      await http.post(
        Uri.parse(syncUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(expense.toJson()),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<List<Expense>> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_expensesKey) ?? [];
    List<Expense> local = jsonList
        .map((s) => Expense.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();

    try {
      final syncUrl = await getSyncUrl();
      if (syncUrl.trim().isNotEmpty) {
        final res = await http.get(Uri.parse(syncUrl)).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
          final serverExpenses =
              list.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
          if (serverExpenses.isNotEmpty) {
            await saveExpenses(serverExpenses);
            return serverExpenses;
          }
        }
      }
    } catch (_) {}

    return local;
  }

  Future<bool> sendTestApplePayExpense({double amount = 260.0, String merchant = 'Apple Pay Kaspi'}) async {
    try {
      final syncUrl = await getSyncUrl();
      if (syncUrl.trim().isEmpty) return false;
      final uri = Uri.parse(syncUrl);
      final shortcutUri = uri.replace(
        path: '/api/shortcut/pay',
        queryParameters: {
          'amount': amount.toStringAsFixed(0),
          'merchant': merchant,
          'currency': '₸',
        },
      );
      final res = await http.get(shortcutUri).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = tasks.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_tasksKey, jsonList);
  }

  Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_tasksKey) ?? [];
    return jsonList
        .map((s) => Task.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  // ─── Diary ──────────────────────────────────────────────────────────────────
  Future<void> saveDiaryEntries(List<DiaryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = entries.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_diaryKey, jsonList);
  }

  Future<List<DiaryEntry>> loadDiaryEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_diaryKey) ?? [];
    return jsonList
        .map((s) =>
            DiaryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  // ─── Chat ───────────────────────────────────────────────────────────────────
  Future<void> saveChatHistory(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = messages.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList(_chatKey, jsonList);
  }

  Future<List<ChatMessage>> loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_chatKey) ?? [];
    return jsonList
        .map((s) =>
            ChatMessage.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  static const _geminiKey = 'gemini_api_key';
  static const _groqKey = 'groq_api_key';
  static const _openaiKey = 'openai_api_key';
  static const _claudeKey = 'claude_api_key';
  static const _openrouterKey = 'openrouter_api_key';
  static const _activeProviderKey = 'active_ai_provider';
  static const _autoFallbackKey = 'ai_auto_fallback';

  // ─── API Keys & AI Config ──────────────────────────────────────────────────
  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
  }

  Future<String> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey) ?? '';
  }

  Future<void> saveProviderKeys({
    required String geminiKey,
    required String groqKey,
    required String openaiKey,
    required String claudeKey,
    required String openrouterKey,
    required String activeProvider,
    required bool autoFallback,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_geminiKey, geminiKey);
    await prefs.setString(_groqKey, groqKey);
    await prefs.setString(_openaiKey, openaiKey);
    await prefs.setString(_claudeKey, claudeKey);
    await prefs.setString(_openrouterKey, openrouterKey);
    await prefs.setString(_activeProviderKey, activeProvider);
    await prefs.setBool(_autoFallbackKey, autoFallback);
  }

  Future<Map<String, dynamic>> loadAIConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyKey = prefs.getString(_apiKeyKey) ?? '';

    var gemini = prefs.getString(_geminiKey) ?? '';
    var groq = prefs.getString(_groqKey) ?? '';
    var openai = prefs.getString(_openaiKey) ?? '';
    var claude = prefs.getString(_claudeKey) ?? '';
    var openrouter = prefs.getString(_openrouterKey) ?? '';
    final active = prefs.getString(_activeProviderKey) ?? 'auto';
    final autoFallback = prefs.getBool(_autoFallbackKey) ?? true;

    // Автомиграция старого единого ключа, если новые пустые
    if (legacyKey.isNotEmpty && gemini.isEmpty && groq.isEmpty && openai.isEmpty && claude.isEmpty && openrouter.isEmpty) {
      if (legacyKey.startsWith('sk-ant-')) {
        claude = legacyKey;
      } else if (legacyKey.startsWith('gsk_')) {
        groq = legacyKey;
      } else if (legacyKey.startsWith('sk-or-')) {
        openrouter = legacyKey;
      } else if (legacyKey.startsWith('sk-')) {
        openai = legacyKey;
      } else {
        gemini = legacyKey;
      }
    }

    return {
      'geminiKey': gemini,
      'groqKey': groq,
      'openaiKey': openai,
      'claudeKey': claude,
      'openrouterKey': openrouter,
      'activeProvider': active,
      'autoFallback': autoFallback,
    };
  }

  // ─── Clear All ───────────────────────────────────────────────────────────────
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_expensesKey);
    await prefs.remove(_tasksKey);
    await prefs.remove(_diaryKey);
    await prefs.remove(_chatKey);
  }
}
