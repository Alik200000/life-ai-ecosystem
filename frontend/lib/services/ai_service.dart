import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import '../models/task.dart';

class AIResponse {
  final String text;
  final String providerName;
  final bool wasFallback;
  final String? fallbackReason;

  AIResponse({
    required this.text,
    required this.providerName,
    this.wasFallback = false,
    this.fallbackReason,
  });
}

class AIService {
  static const _systemPrompt =
      'Ты персональный ИИ-ассистент по имени АИ-Помощник. '
      'Ты помогаешь пользователю управлять расходами, задачами и жизнью. '
      'Ты знаешь о расходах и задачах пользователя и можешь давать советы. '
      'Отвечай всегда на русском языке. Будь дружелюбным, заботливым и практичным.';

  final String geminiKey;
  final String groqKey;
  final String openaiKey;
  final String claudeKey;
  final String openrouterKey;
  final String activeProvider;
  final bool autoFallback;

  AIService({
    String? apiKey,
    String? geminiKey,
    String? groqKey,
    String? openaiKey,
    String? claudeKey,
    String? openrouterKey,
    this.activeProvider = 'auto',
    this.autoFallback = true,
  })  : geminiKey = geminiKey ?? (apiKey != null && !apiKey.startsWith('sk-ant-') && !apiKey.startsWith('gsk_') && !apiKey.startsWith('sk-or-') && !apiKey.startsWith('sk-') ? apiKey : ''),
        groqKey = groqKey ?? (apiKey != null && apiKey.startsWith('gsk_') ? apiKey : ''),
        openaiKey = openaiKey ?? (apiKey != null && apiKey.startsWith('sk-') && !apiKey.startsWith('sk-ant-') && !apiKey.startsWith('sk-or-') ? apiKey : ''),
        claudeKey = claudeKey ?? (apiKey != null && apiKey.startsWith('sk-ant-') ? apiKey : ''),
        openrouterKey = openrouterKey ?? (apiKey != null && apiKey.startsWith('sk-or-') ? apiKey : '');

  // Построитель контекста пользователя
  String _buildSystemWithContext(Map<String, dynamic> context) {
    final contextParts = <String>[];
    if (context['monthlyExpenses'] != null) {
      contextParts.add(
          'Расходы пользователя за текущий месяц: ${(context['monthlyExpenses'] as double).toStringAsFixed(2)} ₽');
    }
    if (context['topCategory'] != null) {
      contextParts.add('Основная категория расходов: ${context['topCategory']}');
    }
    if (context['activeTasks'] != null) {
      final tasks = context['activeTasks'] as List<Task>;
      if (tasks.isNotEmpty) {
        final taskTitles = tasks.take(5).map((t) => '• ${t.title}').join('\n');
        contextParts.add('Активные задачи пользователя:\n$taskTitles');
      }
    }
    if (context['lastMood'] != null) {
      contextParts.add('Последнее настроение пользователя: ${context['lastMood']}');
    }

    return contextParts.isEmpty
        ? _systemPrompt
        : '$_systemPrompt\n\nКонтекст пользователя:\n${contextParts.join('\n')}';
  }

  // Определение очереди провайдеров для отправки запроса
  List<String> _getProviderQueue() {
    final available = <String>[];

    void addIfKey(String id, String key) {
      if (key.trim().isNotEmpty && !available.contains(id)) {
        available.add(id);
      }
    }

    if (activeProvider != 'auto') {
      switch (activeProvider) {
        case 'groq':
          addIfKey('groq', groqKey);
          break;
        case 'gemini':
          addIfKey('gemini', geminiKey);
          break;
        case 'openai':
          addIfKey('openai', openaiKey);
          break;
        case 'claude':
          addIfKey('claude', claudeKey);
          break;
        case 'openrouter':
          addIfKey('openrouter', openrouterKey);
          break;
      }
    }

    // Добавляем остальные провайдеры в порядке приоритета бесплатности и скорости
    addIfKey('groq', groqKey);
    addIfKey('gemini', geminiKey);
    addIfKey('openrouter', openrouterKey);
    addIfKey('openai', openaiKey);
    addIfKey('claude', claudeKey);

    return available;
  }

  Future<AIResponse> sendMessage(
    List<ChatMessage> history,
    String userMessage,
    Map<String, dynamic> context,
  ) async {
    final queue = _getProviderQueue();

    if (queue.isEmpty) {
      throw Exception(
        'Не настроен ни один API ключ.\n'
        'Перейдите в Настройки и добавьте бесплатный ключ Google Gemini или Groq Cloud.',
      );
    }

    final systemWithContext = _buildSystemWithContext(context);
    final recentHistory = history.length > 20
        ? history.sublist(history.length - 20)
        : history;

    final errors = <String>[];
    bool wasFallback = false;
    String? fallbackReason;

    for (int i = 0; i < queue.length; i++) {
      final providerId = queue[i];

      try {
        final result = await _callProvider(
          providerId,
          recentHistory,
          userMessage,
          systemWithContext,
        );

        return AIResponse(
          text: result.text,
          providerName: result.providerName,
          wasFallback: wasFallback,
          fallbackReason: fallbackReason,
        );
      } catch (e) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        errors.add('$providerId: $errorMsg');

        final isQuotaOrOverload = _isRateLimitOrOverload(errorMsg);

        if (autoFallback && i < queue.length - 1) {
          wasFallback = true;
          fallbackReason = isQuotaOrOverload
              ? 'Превышен лимит запросов ($providerId). Выполнен переход на резервный ИИ.'
              : 'Ошибка $providerId. Выполнен переход на резервный ИИ.';
          continue;
        } else {
          // Нет больше резервных провайдеров или отключен fallback
          if (errors.length == 1) {
            throw Exception(errorMsg);
          } else {
            throw Exception(
              'Все доступные ИИ исчерпали лимиты или вернули ошибки:\n• ${errors.join('\n• ')}',
            );
          }
        }
      }
    }

    throw Exception('Не удалось получить ответ: ${errors.join('; ')}');
  }

  bool _isRateLimitOrOverload(String error) {
    final lower = error.toLowerCase();
    return lower.contains('429') ||
        lower.contains('503') ||
        lower.contains('529') ||
        lower.contains('resource_exhausted') ||
        lower.contains('rate_limit') ||
        lower.contains('quota') ||
        lower.contains('overloaded');
  }

  Future<_CallResult> _callProvider(
    String providerId,
    List<ChatMessage> history,
    String userMessage,
    String systemWithContext,
  ) async {
    switch (providerId) {
      case 'gemini':
        final text = await _sendGemini(history, userMessage, systemWithContext, geminiKey.trim());
        return _CallResult(text: text, providerName: 'Google Gemini 3.8 Flash');
      case 'groq':
        final text = await _sendGroq(history, userMessage, systemWithContext, groqKey.trim());
        return _CallResult(text: text, providerName: 'Groq (GPT-OSS 120B)');
      case 'openai':
        final text = await _sendOpenAI(history, userMessage, systemWithContext, openaiKey.trim());
        return _CallResult(text: text, providerName: 'OpenAI GPT-4o-mini');
      case 'claude':
        final text = await _sendClaude(history, userMessage, systemWithContext, claudeKey.trim());
        return _CallResult(text: text, providerName: 'Claude 3.5 Haiku');
      case 'openrouter':
        final text = await _sendOpenRouter(history, userMessage, systemWithContext, openrouterKey.trim());
        return _CallResult(text: text, providerName: 'OpenRouter (Llama 3.3 Free)');
      default:
        throw Exception('Неизвестный провайдер: $providerId');
    }
  }

  // ─── 1. Google Gemini ───────────────────────────────────────────────────────
  Future<String> _sendGemini(
    List<ChatMessage> recentHistory,
    String userMessage,
    String systemWithContext,
    String key,
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=$key',
    );

    final contents = <Map<String, dynamic>>[];
    for (final m in recentHistory) {
      contents.add({
        'role': m.isUser ? 'user' : 'model',
        'parts': [
          {'text': m.content}
        ],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ],
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': systemWithContext}
          ]
        },
        'contents': contents,
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 1024,
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final parts = candidates[0]['content']?['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text'] as String;
        }
      }
      return 'Не удалось получить ответ от Gemini.';
    } else {
      try {
        final error = jsonDecode(response.body);
        final msg = error['error']?['message'] ?? response.body;
        throw Exception('Gemini (${response.statusCode}): $msg');
      } catch (e) {
        if (e.toString().startsWith('Exception: Gemini')) rethrow;
        throw Exception('Gemini (${response.statusCode}): ${response.body}');
      }
    }
  }

  // ─── 2. Groq (GPT-OSS 120B - Бесплатный и сверхбыстрый) ─────────────────────
  Future<String> _sendGroq(
    List<ChatMessage> recentHistory,
    String userMessage,
    String systemWithContext,
    String key,
  ) async {
    return _sendOpenAIFormat(
      url: 'https://api.groq.com/openai/v1/chat/completions',
      model: 'openai/gpt-oss-120b',
      key: key,
      providerLabel: 'Groq',
      recentHistory: recentHistory,
      userMessage: userMessage,
      systemWithContext: systemWithContext,
    );
  }

  // ─── 3. OpenAI (GPT-4o-mini) ────────────────────────────────────────────────
  Future<String> _sendOpenAI(
    List<ChatMessage> recentHistory,
    String userMessage,
    String systemWithContext,
    String key,
  ) async {
    return _sendOpenAIFormat(
      url: 'https://api.openai.com/v1/chat/completions',
      model: 'gpt-4o-mini',
      key: key,
      providerLabel: 'OpenAI',
      recentHistory: recentHistory,
      userMessage: userMessage,
      systemWithContext: systemWithContext,
    );
  }

  // ─── 4. OpenRouter (Бесплатные модели) ──────────────────────────────────────
  Future<String> _sendOpenRouter(
    List<ChatMessage> recentHistory,
    String userMessage,
    String systemWithContext,
    String key,
  ) async {
    return _sendOpenAIFormat(
      url: 'https://openrouter.ai/api/v1/chat/completions',
      model: 'meta-llama/llama-3.3-70b-instruct:free',
      key: key,
      providerLabel: 'OpenRouter',
      recentHistory: recentHistory,
      userMessage: userMessage,
      systemWithContext: systemWithContext,
      extraHeaders: {
        'HTTP-Referer': 'https://lifeai.local',
        'X-Title': 'Life AI Assistant',
      },
    );
  }

  // Общий метод для OpenAI-совместимых API (Groq, OpenAI, OpenRouter)
  Future<String> _sendOpenAIFormat({
    required String url,
    required String model,
    required String key,
    required String providerLabel,
    required List<ChatMessage> recentHistory,
    required String userMessage,
    required String systemWithContext,
    Map<String, String>? extraHeaders,
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemWithContext},
      ...recentHistory.map((m) => {
            'role': m.isUser ? 'user' : 'assistant',
            'content': m.content,
          }),
      {'role': 'user', 'content': userMessage},
    ];

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $key',
      if (extraHeaders != null) ...extraHeaders,
    };

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 1024,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        return choices[0]['message']['content'] as String;
      }
      return 'Не удалось получить ответ от $providerLabel.';
    } else {
      try {
        final error = jsonDecode(response.body);
        final msg = error['error']?['message'] ?? response.body;
        throw Exception('$providerLabel (${response.statusCode}): $msg');
      } catch (e) {
        if (e.toString().startsWith('Exception: $providerLabel')) rethrow;
        throw Exception('$providerLabel (${response.statusCode}): ${response.body}');
      }
    }
  }

  // ─── 5. Anthropic Claude ────────────────────────────────────────────────────
  Future<String> _sendClaude(
    List<ChatMessage> recentHistory,
    String userMessage,
    String systemWithContext,
    String key,
  ) async {
    final messages = [
      ...recentHistory.map((m) => {
            'role': m.isUser ? 'user' : 'assistant',
            'content': m.content,
          }),
      {
        'role': 'user',
        'content': userMessage,
      },
    ];

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': 'claude-3-5-haiku-20241022',
        'max_tokens': 1024,
        'system': systemWithContext,
        'messages': messages,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>;
      return (content.first as Map<String, dynamic>)['text'] as String;
    } else {
      final error = jsonDecode(response.body);
      final msg = error['error']?['message'] ?? 'Неизвестная ошибка';
      throw Exception('Claude (${response.statusCode}): $msg');
    }
  }
}

class _CallResult {
  final String text;
  final String providerName;

  _CallResult({required this.text, required this.providerName});
}
