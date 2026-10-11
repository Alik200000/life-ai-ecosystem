import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _geminiCtrl;
  late TextEditingController _groqCtrl;
  late TextEditingController _openaiCtrl;
  late TextEditingController _claudeCtrl;
  late TextEditingController _openrouterCtrl;
  late TextEditingController _syncUrlCtrl;

  late String _activeProvider;
  late bool _autoFallback;

  final Map<String, bool> _obscureFields = {
    'gemini': true,
    'groq': true,
    'openai': true,
    'claude': true,
    'openrouter': true,
  };

  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppProvider>();
    _geminiCtrl = TextEditingController(
        text: p.geminiKey.isNotEmpty
            ? p.geminiKey
            : (!p.apiKey.startsWith('gsk_') && !p.apiKey.startsWith('sk-')
                ? p.apiKey
                : ''));
    _groqCtrl = TextEditingController(text: p.groqKey);
    _openaiCtrl = TextEditingController(text: p.openaiKey);
    _claudeCtrl = TextEditingController(text: p.claudeKey);
    _openrouterCtrl = TextEditingController(text: p.openrouterKey);
    _syncUrlCtrl = TextEditingController(text: p.syncUrl);

    _activeProvider = p.activeProvider;
    _autoFallback = p.autoFallback;
  }

  @override
  void dispose() {
    _geminiCtrl.dispose();
    _groqCtrl.dispose();
    _openaiCtrl.dispose();
    _claudeCtrl.dispose();
    _openrouterCtrl.dispose();
    _syncUrlCtrl.dispose();
    super.dispose();
  }

  int _countActiveKeys() {
    int count = 0;
    if (_geminiCtrl.text.trim().isNotEmpty) count++;
    if (_groqCtrl.text.trim().isNotEmpty) count++;
    if (_openaiCtrl.text.trim().isNotEmpty) count++;
    if (_claudeCtrl.text.trim().isNotEmpty) count++;
    if (_openrouterCtrl.text.trim().isNotEmpty) count++;
    return count;
  }

  Future<void> _saveAll() async {
    final gemini = _geminiCtrl.text.trim();
    final groq = _groqCtrl.text.trim();
    final openai = _openaiCtrl.text.trim();
    final claude = _claudeCtrl.text.trim();
    final openrouter = _openrouterCtrl.text.trim();

    final provider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.of(context);

    await provider.saveAIConfig(
          geminiKey: gemini,
          groqKey: groq,
          openaiKey: openai,
          claudeKey: claude,
          openrouterKey: openrouter,
          activeProvider: _activeProvider,
          autoFallback: _autoFallback,
        );

    // Также обновляем главный ключ для совместимости
    String primaryKey = gemini;
    if (_activeProvider == 'groq' && groq.isNotEmpty) primaryKey = groq;
    if (_activeProvider == 'openai' && openai.isNotEmpty) primaryKey = openai;
    if (_activeProvider == 'claude' && claude.isNotEmpty) primaryKey = claude;
    if (_activeProvider == 'openrouter' && openrouter.isNotEmpty) primaryKey = openrouter;
    if (primaryKey.isEmpty) {
      primaryKey = [gemini, groq, openrouter, openai, claude].firstWhere((k) => k.isNotEmpty, orElse: () => '');
    }
    await provider.saveApiKey(primaryKey);
    await provider.updateSyncUrl(_syncUrlCtrl.text.trim());

    if (!mounted) return;
    setState(() => _saved = true);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Настройки сохранены! Активно ключей: ${_countActiveKeys()}'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _countActiveKeys();

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки ИИ и системы')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Status Overview Card ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2A1B4E), Color(0xFF1B2E4B)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF7B61FF).withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: activeCount > 0 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        activeCount > 0 ? Icons.shield : Icons.warning_amber,
                        color: activeCount > 0 ? Colors.greenAccent : Colors.orangeAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeCount > 0
                                ? 'Защита от лимитов активна'
                                : 'Ключи ИИ не настроены',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeCount > 0
                                ? 'Подключено провайдеров: $activeCount. При исчерпании лимита запрос переключится мгновенно.'
                                : 'Добавьте хотя бы один бесплатный ключ ниже.',
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── Provider & Fallback Settings ──────────────────────────────────
          _buildSection(
            title: 'Управление провайдерами',
            icon: Icons.tune,
            children: [
              // Выбор основного ИИ
              const Text(
                'Основной ИИ для ответов:',
                style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _activeProvider,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1E3A),
                    items: const [
                      DropdownMenuItem(
                        value: 'auto',
                        child: Text('⚡️ Автовыбор (сначала бесплатные и быстрые)'),
                      ),
                      DropdownMenuItem(
                        value: 'gemini',
                        child: Text('⭐️ Google Gemini 3.8 Flash (Бесплатно)'),
                      ),
                      DropdownMenuItem(
                        value: 'groq',
                        child: Text('🚀 Groq Cloud / GPT-OSS 120B (Бесплатно)'),
                      ),
                      DropdownMenuItem(
                        value: 'openrouter',
                        child: Text('🌐 OpenRouter (Агрегатор / Free модели)'),
                      ),
                      DropdownMenuItem(
                        value: 'openai',
                        child: Text('🤖 OpenAI (ChatGPT GPT-4o-mini)'),
                      ),
                      DropdownMenuItem(
                        value: 'claude',
                        child: Text('🧠 Anthropic Claude (3.5 Haiku)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _activeProvider = val;
                          _saved = false;
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Переключатель Fallback
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Автопереключение при лимитах',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Если текущий ИИ исчерпал лимит (429) или перегружен, мгновенно отправлять запрос резервному ИИ.',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
                value: _autoFallback,
                activeColor: const Color(0xFF00B4D8),
                onChanged: (val) {
                  setState(() {
                    _autoFallback = val;
                    _saved = false;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ─── API Keys ───────────────────────────────────────────────────────
          _buildSection(
            title: 'Ключи провайдеров',
            icon: Icons.key,
            children: [
              // 1. Google Gemini
              _buildKeyInput(
                providerId: 'gemini',
                title: '⭐️ Google Gemini API (Бесплатно)',
                hint: 'AQ... или AIzaSy... (15 запросов/мин, 1500/день)',
                controller: _geminiCtrl,
                urlHint: 'aistudio.google.com/app/apikey',
                badgeText: 'Бесплатно без карты',
                badgeColor: Colors.blueAccent,
              ),

              const Divider(color: Colors.white12, height: 28),

              // 2. Groq Cloud
              _buildKeyInput(
                providerId: 'groq',
                title: '🚀 Groq Cloud (Бесплатно и сверхбыстро)',
                hint: 'gsk_... (GPT-OSS 120B & Qwen)',
                controller: _groqCtrl,
                urlHint: 'console.groq.com/keys',
                badgeText: 'Бесплатно 14k токенов/мин',
                badgeColor: Colors.greenAccent,
              ),

              const Divider(color: Colors.white12, height: 28),

              // 3. OpenRouter
              _buildKeyInput(
                providerId: 'openrouter',
                title: '🌐 OpenRouter (Все модели мира)',
                hint: 'sk-or-v1-... (поддержка моделей :free)',
                controller: _openrouterCtrl,
                urlHint: 'openrouter.ai/keys',
                badgeText: 'Агрегатор моделей',
                badgeColor: Colors.purpleAccent,
              ),

              const Divider(color: Colors.white12, height: 28),

              // 4. OpenAI
              _buildKeyInput(
                providerId: 'openai',
                title: '🤖 OpenAI / ChatGPT',
                hint: 'sk-proj-... или sk-...',
                controller: _openaiCtrl,
                urlHint: 'platform.openai.com/api-keys',
                badgeText: 'GPT-4o-mini',
                badgeColor: Colors.tealAccent,
              ),

              const Divider(color: Colors.white12, height: 28),

              // 5. Anthropic Claude
              _buildKeyInput(
                providerId: 'claude',
                title: '🧠 Anthropic Claude',
                hint: 'sk-ant-...',
                controller: _claudeCtrl,
                urlHint: 'console.anthropic.com',
                badgeText: 'Claude 3.5 Haiku',
                badgeColor: Colors.amberAccent,
              ),

              const SizedBox(height: 20),

              // Кнопка сохранения
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _saved
                        ? Colors.green.shade700
                        : const Color(0xFF7B61FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _saveAll,
                  icon: Icon(_saved ? Icons.check : Icons.save, color: Colors.white),
                  label: Text(
                    _saved ? 'Настройки сохранены!' : 'Сохранить все ключи',
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ─── Telegram Sync Section ─────────────────────────────────────────
          _buildSection(
            title: 'Синхронизация с Telegram ботом',
            icon: Icons.sync,
            children: [
              const Text(
                'Адрес API для синхронизации расходов и команд Apple Pay:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _syncUrlCtrl,
                onChanged: (_) => setState(() => _saved = false),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'http://192.168.1.31:5000/api/expenses',
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Синхронизировать сейчас',
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await context.read<AppProvider>().updateSyncUrl(_syncUrlCtrl.text.trim());
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Расходы синхронизированы!')),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Локально: http://192.168.1.31:5000/api/expenses\nВ облаке: https://<ваше-имя>.onrender.com/api/expenses',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ─── About Section ─────────────────────────────────────────────────
          _buildSection(
            title: 'О системе',
            icon: Icons.info_outline,
            children: [
              _infoRow('Приложение', 'ЖизньАИ'),
              _infoRow('Версия', '1.1.0'),
              _infoRow('Система отказоустойчивости', 'Multi-AI Fallback 429 Guard'),
              _infoRow('Поддерживаемые ИИ', 'Gemini, Groq, OpenAI, Claude, OpenRouter'),
            ],
          ),

          const SizedBox(height: 16),

          // ─── Danger Zone ───────────────────────────────────────────────────
          _buildSection(
            title: 'Опасная зона',
            icon: Icons.warning_amber,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final provider = context.read<AppProvider>();
                    final messenger = ScaffoldMessenger.of(context);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Удалить все данные?'),
                        content: const Text(
                          'Все расходы, задачи, записи дневника и история чата будут удалены. Это действие нельзя отменить.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Отмена'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Удалить всё', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) {
                      await provider.clearAllData();
                      if (!mounted) return;
                      _geminiCtrl.clear();
                      _groqCtrl.clear();
                      _openaiCtrl.clear();
                      _claudeCtrl.clear();
                      _openrouterCtrl.clear();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Все данные и ключи очищены'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text(
                    'Очистить все данные и историю',
                    style: TextStyle(color: Colors.red, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyInput({
    required String providerId,
    required String title,
    required String hint,
    required TextEditingController controller,
    required String urlHint,
    required String badgeText,
    required Color badgeColor,
  }) {
    final isObscure = _obscureFields[providerId] ?? true;
    final hasValue = controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withOpacity(0.4), width: 0.8),
              ),
              child: Text(
                badgeText,
                style: TextStyle(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isObscure,
          onChanged: (_) => setState(() => _saved = false),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(
              hasValue ? Icons.vpn_key : Icons.vpn_key_outlined,
              color: hasValue ? Colors.greenAccent : Colors.white38,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isObscure ? Icons.visibility : Icons.visibility_off,
                size: 20,
                color: Colors.white54,
              ),
              onPressed: () => setState(() => _obscureFields[providerId] = !isObscure),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Получить: $urlHint',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF7B61FF)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
