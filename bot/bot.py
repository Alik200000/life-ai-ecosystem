import os
import re
import sqlite3
import datetime
import json
import threading
import requests
import telebot
from telebot import types
from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS

TOKEN = os.environ.get('TELEGRAM_BOT_TOKEN', '8906685761:AAFr-u6JvXQPJBSOxBO17fSeAFDyEbFpvBg')
DB_PATH = os.path.join(os.path.dirname(__file__), 'assistant.db')

bot = telebot.TeleBot(TOKEN)
app = Flask(__name__)
CORS(app)

@app.route('/', methods=['GET'])
def health():
    return jsonify({
        'status': 'online',
        'service': 'Life AI Ecosystem Bot & API',
        'endpoints': ['/api/expenses', '/api/expenses/<id>']
    }), 200

# ----------------- БАЗА ДАННЫХ -----------------
def init_db():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            amount REAL,
            category TEXT,
            merchant TEXT,
            created_at TEXT
        )
    ''')
    cur.execute('''
        CREATE TABLE IF NOT EXISTS user_settings (
            user_id INTEGER PRIMARY KEY,
            gemini_key TEXT
        )
    ''')
    conn.commit()
    conn.close()

init_db()

def get_gemini_key(user_id):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute('SELECT gemini_key FROM user_settings WHERE user_id = ?', (user_id,))
    row = cur.fetchone()
    conn.close()
    return row[0] if row and row[0] else None

def set_gemini_key(user_id, key):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute('''
        INSERT INTO user_settings (user_id, gemini_key) 
        VALUES (?, ?) 
        ON CONFLICT(user_id) DO UPDATE SET gemini_key = excluded.gemini_key
    ''', (user_id, key.strip()))
    conn.commit()
    conn.close()

def add_expense(user_id, amount, category, merchant):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    now_str = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    cur.execute('''
        INSERT INTO expenses (user_id, amount, category, merchant, created_at)
        VALUES (?, ?, ?, ?, ?)
    ''', (user_id, amount, category, merchant, now_str))
    conn.commit()
    conn.close()

def get_monthly_total(user_id):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    first_day = datetime.datetime.now().strftime('%Y-%m-01 00:00:00')
    cur.execute('''
        SELECT SUM(amount) FROM expenses 
        WHERE user_id = ? AND created_at >= ?
    ''', (user_id, first_day))
    total = cur.fetchone()[0]
    conn.close()
    return total or 0.0

def get_monthly_by_category(user_id):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    first_day = datetime.datetime.now().strftime('%Y-%m-01 00:00:00')
    cur.execute('''
        SELECT category, SUM(amount) FROM expenses 
        WHERE user_id = ? AND created_at >= ?
        GROUP BY category
        ORDER BY SUM(amount) DESC
    ''', (user_id, first_day))
    rows = cur.fetchall()
    conn.close()
    return rows

def map_to_flutter_cat(cat_str):
    c = (cat_str or '').lower()
    if 'ед' in c or 'продукт' in c or 'кафе' in c or 'ресторан' in c:
        return 'Еда'
    elif 'транспорт' in c or 'такси' in c or 'бензин' in c:
        return 'Транспорт'
    elif 'развлечен' in c or 'игр' in c or 'кино' in c:
        return 'Развлечения'
    elif 'здоров' in c or 'аптек' in c or 'клиник' in c:
        return 'Здоровье'
    elif 'одежд' in c or 'обув' in c or 'покупк' in c:
        return 'Одежда'
    elif 'счет' in c or 'связь' in c or 'жкх' in c or 'аренд' in c:
        return 'Жильё'
    return 'Другое'

# ----------------- FLASK СИНХРОНИЗАЦИЯ API -----------------
@app.route('/api/expenses', methods=['GET'])
def api_get_expenses():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute('SELECT id, merchant, amount, category, created_at FROM expenses ORDER BY id DESC')
    rows = cur.fetchall()
    conn.close()
    def parse_iso(d_str):
        if not d_str:
            return datetime.datetime.now().isoformat()
        for fmt in ('%Y-%m-%d %H:%M:%S', '%d.%m.%Y %H:%M:%S', '%Y-%m-%dT%H:%M:%S', '%d.%m.%Y %H:%M'):
            try:
                return datetime.datetime.strptime(d_str, fmt).isoformat()
            except Exception:
                pass
        return datetime.datetime.now().isoformat()

    result = []
    for r in rows:
        cat = map_to_flutter_cat(r[3])
        date_iso = parse_iso(r[4])
        result.append({
            'id': str(r[0]),
            'title': r[1] or 'Расход',
            'amount': float(r[2]),
            'category': cat,
            'date': date_iso,
            'note': f"Категория: {r[3]}"
        })
    return jsonify(result)

@app.route('/api/expenses', methods=['POST'])
def api_add_expense():
    data = request.json or {}
    merchant = data.get('title', 'Расход')
    amount = float(data.get('amount', 0))
    category = data.get('category', 'Другое')
    user_id = data.get('user_id', 6456555935)
    add_expense(user_id, amount, category, merchant)
    return jsonify({'status': 'success'})

@app.route('/api/expenses/<int:exp_id>', methods=['DELETE'])
def api_delete_expense(exp_id):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute('DELETE FROM expenses WHERE id = ?', (exp_id,))
    conn.commit()
    conn.close()
    return jsonify({'status': 'deleted'})

@app.route('/api/shortcut/pay', methods=['GET', 'POST'])
@app.route('/api/pay', methods=['GET', 'POST'])
def api_shortcut_pay():
    raw_amount = None
    raw_merchant = None
    raw_currency = None
    raw_card = None
    user_id = 6456555935

    if request.is_json and request.json:
        data = request.json
        raw_amount = data.get('amount')
        raw_merchant = data.get('merchant') or data.get('title')
        raw_currency = data.get('currency')
        raw_card = data.get('card')
        user_id = data.get('user_id', user_id)
    else:
        raw_amount = request.args.get('amount')
        raw_merchant = request.args.get('merchant') or request.args.get('title')
        raw_currency = request.args.get('currency')
        raw_card = request.args.get('card')
        user_id = request.args.get('user_id', user_id)
        combined_text = request.args.get('text') or request.args.get('query')
        if combined_text and not raw_amount:
            match = re.search(r'(\d+(?:[\.,]\d+)?)', combined_text)
            if match:
                raw_amount = match.group(1)
                raw_merchant = combined_text[match.end():].strip()

    if not raw_amount:
        return jsonify({
            'status': 'error',
            'message': 'Не указана сумма расхода. Пример: /api/shortcut/pay?amount=260&merchant=Магазин'
        }), 400

    amount_str = str(raw_amount).replace(' ', '').replace(',', '.')
    num_match = re.search(r'(\d+(?:\.\d+)?)', amount_str)
    if not num_match:
        return jsonify({
            'status': 'error',
            'message': f'Не удалось распознать сумму: {raw_amount}'
        }), 400

    try:
        amount = float(num_match.group(1))
    except ValueError:
        return jsonify({'status': 'error', 'message': 'Некорректный формат суммы'}), 400

    text_to_check = f"{raw_amount} {raw_merchant or ''} {raw_currency or ''}".lower()
    is_kzt = any(c in text_to_check for c in ['тг', '₸', 'kzt', 'тенге']) or not any(c in text_to_check for c in ['руб', '₽', 'rub', 'usd', '$', 'eur', '€'])
    currency = "₸" if is_kzt else "₽"
    if '$' in text_to_check or 'usd' in text_to_check:
        currency = "$"
    elif '€' in text_to_check or 'eur' in text_to_check:
        currency = "€"

    merchant = str(raw_merchant or '').strip()
    merchant = re.sub(r'^(?:[/\\|\s-]+)', '', merchant)
    merchant = re.sub(r'(?:тг|₸|kzt|тенге|руб|рублей|₽|rub)\b', '', merchant, flags=re.IGNORECASE).strip()
    merchant = re.sub(r'^(?:[/\\|\s-]+)', '', merchant).strip()

    if not merchant or merchant.lower() in ['none', 'null', 'undefined']:
        merchant = "Apple Pay"

    category = auto_detect_category(merchant)

    try:
        user_id = int(user_id)
    except (ValueError, TypeError):
        user_id = 6456555935

    add_expense(user_id, amount, category, merchant)
    total = get_monthly_total(user_id)

    telegram_delivered = False
    try:
        notif = (
            f"⚡ **Оплата Apple Pay зафиксирована!**\n\n"
            f"• Сумма: **{amount:.2f} {currency}**\n"
            f"• Продавец: **{merchant}**\n"
            f"• Категория: **{category}**\n"
        )
        if raw_card:
            notif += f"• Карта: **{raw_card}**\n"
        notif += (
            f"\n📈 Всего за месяц: **{total:.2f} {currency}**\n"
            f"✨ Синхронизировано с приложением ЖизньАИ"
        )
        bot.send_message(user_id, notif, parse_mode='Markdown')
        telegram_delivered = True
    except Exception as e:
        print(f"Telegram notification error: {e}")

    return jsonify({
        'status': 'success',
        'message': 'Расход успешно записан и синхронизирован',
        'expense': {
            'amount': amount,
            'currency': currency,
            'merchant': merchant,
            'category': category,
            'user_id': user_id,
            'monthly_total': total
        },
        'telegram_notified': telegram_delivered
    }), 200

@app.route('/shortcut', methods=['GET'])
def shortcut_portal():
    host = request.host_url.rstrip('/')
    sample_url = f"{host}/api/shortcut/pay?amount=[Сумма]&merchant=[Продавец]"
    html = f"""<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Синхронизация Apple Pay и Команд iOS — ЖизньАИ</title>
  <style>
    :root {{
      --bg: #0b0f19;
      --card-bg: rgba(23, 32, 54, 0.75);
      --accent: #6366f1;
      --accent-hover: #4f46e5;
      --text: #f8fafc;
      --subtext: #94a3b8;
      --success: #10b981;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: radial-gradient(circle at top right, #1e1b4b, var(--bg));
      color: var(--text);
      margin: 0;
      padding: 24px 16px;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
    }}
    .container {{
      background: var(--card-bg);
      backdrop-filter: blur(20px);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 24px;
      max-width: 580px;
      width: 100%;
      padding: 32px 24px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.7);
    }}
    .badge {{
      display: inline-block;
      background: rgba(99, 102, 241, 0.2);
      color: #a5b4fc;
      border: 1px solid rgba(99, 102, 241, 0.4);
      padding: 6px 14px;
      border-radius: 9999px;
      font-size: 13px;
      font-weight: 600;
      margin-bottom: 12px;
    }}
    h1 {{
      font-size: 26px;
      margin: 0 0 10px 0;
      font-weight: 700;
      letter-spacing: -0.5px;
    }}
    p.desc {{
      color: var(--subtext);
      font-size: 14px;
      line-height: 1.6;
      margin: 0 0 24px 0;
    }}
    .card {{
      background: rgba(11, 15, 25, 0.7);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 16px;
      padding: 16px;
      margin-bottom: 20px;
    }}
    .card-title {{
      font-size: 14px;
      font-weight: 600;
      color: #e2e8f0;
      margin-bottom: 10px;
    }}
    .url-box {{
      display: flex;
      gap: 8px;
      background: #030712;
      border: 1px solid #334155;
      border-radius: 12px;
      padding: 8px 12px;
      align-items: center;
    }}
    input.url-input {{
      background: transparent;
      border: none;
      color: #38bdf8;
      font-family: monospace;
      font-size: 12px;
      width: 100%;
      outline: none;
    }}
    button.btn {{
      background: var(--accent);
      color: white;
      border: none;
      border-radius: 10px;
      padding: 10px 16px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
      white-space: nowrap;
    }}
    button.btn:hover {{
      background: var(--accent-hover);
    }}
    button.btn-test {{
      width: 100%;
      background: linear-gradient(135deg, #059669, #10b981);
      padding: 14px;
      font-size: 15px;
      margin-top: 10px;
      border-radius: 14px;
      box-shadow: 0 10px 20px rgba(16, 185, 129, 0.25);
    }}
    button.btn-test:hover {{
      opacity: 0.95;
      transform: translateY(-1px);
    }}
    ol.steps {{
      padding-left: 20px;
      margin: 0;
      color: var(--subtext);
      font-size: 13px;
      line-height: 1.8;
    }}
    ol.steps li strong {{
      color: var(--text);
    }}
    .result-box {{
      margin-top: 16px;
      padding: 14px;
      border-radius: 12px;
      display: none;
      font-size: 13px;
      line-height: 1.5;
    }}
  </style>
</head>
<body>
  <div class="container">
    <div style="text-align: center;">
      <span class="badge">⚡ Прямой API для Команд iOS</span>
      <h1>Apple Pay ➔ ЖизньАИ</h1>
      <p class="desc">Автоматизация iOS «Команды» отправляет траты напрямую в базу приложения и бота. Никаких лишних текстовых сообщений в диалоге!</p>
    </div>

    <div class="card">
      <div class="card-title">🔗 Персональный URL для действия «Получить содержимое URL»:</div>
      <div class="url-box">
        <input type="text" id="webhookUrl" class="url-input" readonly value="{sample_url}">
        <button class="btn" onclick="copyUrl()">Копировать</button>
      </div>
    </div>

    <div class="card">
      <div class="card-title">📱 4 простых шага настройки на iPhone:</div>
      <ol class="steps">
        <li>Откройте приложение <strong>«Команды» (Shortcuts)</strong> на iPhone.</li>
        <li>Вкладка <strong>«Автоматизация»</strong> ➔ нажмите <strong>+</strong> ➔ выберите <strong>«Транзакция»</strong>.</li>
        <li>Укажите карту (Любая) и выберите <strong>«Выполнять немедленно»</strong>.</li>
        <li>Добавьте действие <strong>«Получить содержимое URL»</strong> (Get Contents of URL) со скопированной ссылкой. Замените <code>[Сумма]</code> и <code>[Продавец]</code> на переменные транзакции.</li>
      </ol>
    </div>

    <button class="btn btn-test" onclick="sendTestExpense()">🧪 Протестировать отправку 260 ₸ прямо сейчас</button>
    <div id="resultBox" class="result-box"></div>
  </div>

  <script>
    function copyUrl() {{
      const urlInput = document.getElementById('webhookUrl');
      urlInput.select();
      navigator.clipboard.writeText(urlInput.value);
      alert('✅ Ссылка скопирована в буфер обмена!');
    }}

    async function sendTestExpense() {{
      const box = document.getElementById('resultBox');
      box.style.display = 'block';
      box.style.background = 'rgba(99, 102, 241, 0.15)';
      box.style.border = '1px solid rgba(99, 102, 241, 0.3)';
      box.innerHTML = '⏳ Отправка тестовой транзакции...';

      try {{
        const res = await fetch('/api/shortcut/pay?amount=260&merchant=Apple Pay Kaspi&currency=₸');
        const data = await res.json();
        if (data.status === 'success') {{
          box.style.background = 'rgba(16, 185, 129, 0.15)';
          box.style.border = '1px solid rgba(16, 185, 129, 0.3)';
          box.innerHTML = '✅ <strong>Успешно!</strong> Расход 260 ₸ сохранён. Проверьте Telegram и мобильное приложение ЖизньАИ — трата уже там!';
        }} else {{
          box.style.background = 'rgba(239, 68, 68, 0.15)';
          box.style.border = '1px solid rgba(239, 68, 68, 0.3)';
          box.innerHTML = '❌ Ошибка: ' + (data.message || 'Неизвестная ошибка');
        }}
      }} catch (err) {{
        box.style.background = 'rgba(239, 68, 68, 0.15)';
        box.style.border = '1px solid rgba(239, 68, 68, 0.3)';
        box.innerHTML = '❌ Ошибка соединения: ' + err.message;
      }}
    }}
  </script>
</body>
</html>
"""
    return render_template_string(html)

def run_flask():
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False, use_reloader=False)

# ----------------- ИИ (GEMINI) -----------------
def call_gemini(user_id, prompt):
    api_key = get_gemini_key(user_id)
    if not api_key:
        return '⚠️ Пожалуйста, укажите ваш бесплатный ключ Gemini командой:\n`/key AIzaSy...`\n(Получить за 1 минуту: aistudio.google.com/app/apikey)'

    monthly_total = get_monthly_total(user_id)
    categories = get_monthly_by_category(user_id)
    cat_summary = ", ".join([f"{c}: {s:.0f}₽" for c, s in categories[:4]])

    system_prompt = (
        "Ты умный персональный финансовый и жизненный ИИ-помощник. "
        "Ты говоришь на русском языке. Будь кратким, полезным, позитивным. "
        f"Текущие траты пользователя за этот месяц: {monthly_total:.0f} руб. "
        f"Категории: {cat_summary if cat_summary else 'пока нет трат'}. "
        "Помогай планировать бюджет, давай советы по экономии и организовывай жизнь."
    )

    models = ['gemini-3.8-flash', 'gemini-2.5-flash', 'gemini-1.5-flash']
    for model in models:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
        payload = {
            "system_instruction": {"parts": [{"text": system_prompt}]},
            "contents": [{"role": "user", "parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.7, "maxOutputTokens": 800}
        }
        try:
            r = requests.post(url, json=payload, timeout=20)
            if r.status_code == 200:
                data = r.json()
                return data['candidates'][0]['content']['parts'][0]['text']
        except Exception:
            continue

    return "Не удалось связаться с Gemini. Проверьте правильность API ключа."

def auto_detect_category(merchant_or_text):
    text = merchant_or_text.lower()
    if any(w in text for w in ['магнит', 'пятёрочк', 'пятерочк', 'перекресток', 'лента', 'вкусвилл', 'ашан', 'супермаркет', 'продукты', 'хлеб', 'молоко', 'еда']):
        return 'Продукты 🛒'
    elif any(w in text for w in ['кафе', 'ресторан', 'кофе', 'coffee', 'бургер', 'макдон', 'вкусно и точка', 'додо', 'пицца', 'шаурма', 'кфс', 'kfc', 'столовая', 'обед', 'бар']):
        return 'Кафе и рестораны ☕️'
    elif any(w in text for w in ['такси', 'uber', 'яндекс', 'yandex', 'метро', 'автобус', 'бензин', 'заправка', 'газпром', 'лукойл', 'транспорт', 'парковка']):
        return 'Транспорт 🚖'
    elif any(w in text for w in ['аптека', 'врач', 'клиника', 'анализ', 'лекарств', 'стоматолог', 'здоровье']):
        return 'Здоровье 💊'
    elif any(w in text for w in ['одежда', 'обувь', 'zara', 'wb', 'wildberries', 'ozon', 'озон', 'aliexpress', 'шопинг']):
        return 'Покупки 🛍'
    elif any(w in text for w in ['кино', 'игры', 'подписка', 'steam', 'playstation', 'билет', 'развлечения']):
        return 'Развлечения 🎮'
    elif any(w in text for w in ['жкх', 'аренда', 'квартира', 'свет', 'интернет', 'связь', 'мтс', 'мегафон', 'билайн', 'tele2']):
        return 'Счета и связь 📱'
    return 'Прочее 📦'

# ----------------- КЛАВИАТУРА -----------------
def get_main_keyboard():
    markup = types.ReplyKeyboardMarkup(resize_keyboard=True)
    markup.row('💳 Расходы за месяц', '📊 По категориям')
    markup.row('🍎 Настроить Apple Pay', '⚙️ API Ключ')
    return markup

# ----------------- ОБРАБОТЧИКИ -----------------
@bot.message_handler(commands=['start'])
def send_welcome(message):
    text = (
        f"👋 Привет, {message.from_user.first_name}!\n\n"
        "Я твой **персональный ИИ-ассистент для расходов и жизни**.\n\n"
        "✨ **Что я умею:**\n"
        "• ⚡️ Автоматически ловить покупки из **Apple Pay**\n"
        "• 📲 **Синхронизировать все траты** с мобильным приложением\n"
        "• 💰 Записывать траты из текста («Купил кофе за 250»)\n"
        "• 📊 Показывать статистику и баланс\n"
        "• 🧠 Давать финансовые советы через Gemini\n\n"
        "Чтобы подключить ИИ, напиши:\n`/key ТВОЙ_GEMINI_КЛЮЧ`"
    )
    bot.reply_to(message, text, reply_markup=get_main_keyboard(), parse_mode='Markdown')

@bot.message_handler(commands=['key'])
def set_key_command(message):
    parts = message.text.split(maxsplit=1)
    if len(parts) < 2:
        bot.reply_to(
            message,
            "ℹ️ Отправьте ключ в формате:\n`/key AIzaSy...`\n\nБесплатный ключ берётся тут: https://aistudio.google.com/app/apikey",
            parse_mode='Markdown'
        )
        return
    key = parts[1].strip()
    set_gemini_key(message.from_user.id, key)
    bot.reply_to(message, "✅ Google Gemini API ключ успешно сохранён! Теперь ИИ активен.", reply_markup=get_main_keyboard())

@bot.message_handler(func=lambda m: m.text and m.text.strip().lower().startswith('/pay'))
def handle_pay_command(message):
    text = message.text.strip()
    raw = re.sub(r'^/pay[\s_:]*', '', text, flags=re.IGNORECASE).strip()

    match = re.search(r'(\d+(?:[\.,]\d+)?)', raw)
    if not match:
        bot.reply_to(message, "Используйте: `/pay 500 Магазин`", parse_mode='Markdown')
        return

    amount_str = match.group(1)
    try:
        amount = float(amount_str.replace(',', '.'))
    except ValueError:
        bot.reply_to(message, "❌ Не удалось распознать сумму. Пример: `/pay 250 Кофе`", parse_mode='Markdown')
        return

    rest = raw[match.end():].strip()

    # Определяем валюту
    is_kzt = any(c in (text).lower() for c in ['тг', '₸', 'kzt', 'тенге'])
    currency = "₸" if is_kzt else "₽"

    # Очищаем название продавца
    merchant = re.sub(r'^(?:[/\\|\s-]+)', '', rest)
    merchant = re.sub(r'(?:тг|₸|kzt|тенге|руб|рублей|₽|rub)\b', '', merchant, flags=re.IGNORECASE).strip()
    merchant = re.sub(r'^(?:[/\\|\s-]+)', '', merchant).strip()

    if not merchant:
        merchant = "Apple Pay"

    category = auto_detect_category(merchant)
    add_expense(message.from_user.id, amount, category, merchant)

    total = get_monthly_total(message.from_user.id)
    bot.reply_to(
        message,
        f"💳 **Расход записан и синхронизирован с приложением!**\n\n"
        f"• Сумма: **{amount:.2f} {currency}**\n"
        f"• Категория: {category}\n"
        f"• Магазин: {merchant}\n\n"
        f"📈 Всего за месяц: **{total:.2f} {currency}**",
        parse_mode='Markdown'
    )

@bot.message_handler(func=lambda m: m.text == '💳 Расходы за месяц')
def show_total(message):
    total = get_monthly_total(message.from_user.id)
    bot.reply_to(message, f"💰 Ваши расходы в этом месяце: **{total:.2f} ₽**", parse_mode='Markdown')

@bot.message_handler(func=lambda m: m.text == '📊 По категориям')
def show_categories(message):
    rows = get_monthly_by_category(message.from_user.id)
    if not rows:
        bot.reply_to(message, "В этом месяце трат пока нет.")
        return
    text = "📊 **Расходы по категориям в этом месяце:**\n\n"
    total = sum(r[1] for r in rows)
    for cat, s in rows:
        percent = (s / total * 100) if total > 0 else 0
        text += f"• {cat}: **{s:.0f} ₽** ({percent:.1f}%)\n"
    text += f"\nИтого: **{total:.0f} ₽**"
    bot.reply_to(message, text, parse_mode='Markdown')

@bot.message_handler(func=lambda m: m.text == '⚙️ API Ключ')
def key_info(message):
    has_key = get_gemini_key(message.from_user.id) is not None
    status = "✅ Ключ установлен" if has_key else "❌ Ключ не задан"
    bot.reply_to(
        message,
        f"Статус ИИ: {status}\n\n"
        "Чтобы обновить ключ:\n`/key ТВОЙ_КЛЮЧ`\n\n"
        "Бесплатный ключ Gemini без карты: https://aistudio.google.com/app/apikey",
        parse_mode='Markdown'
    )

@bot.message_handler(func=lambda m: m.text == '🍎 Настроить Apple Pay' or m.text == '/applepay')
def applepay_guide(message):
    chat_id = message.chat.id
    text = (
        "🍎 **Как настроить авто-запись покупок с Apple Pay:**\n\n"
        "1. Открой приложение **«Команды» (Shortcuts)** на iPhone.\n"
        "2. Перейди во вкладку **«Автоматизация»** (внизу по центру) → нажми **«+»**.\n"
        "3. Выбери триггер: **«Транзакция»** (Кошелек / Apple Pay).\n"
        "4. Выбери карту или оставь *«Любая карта»*, включи **«Запускать немедленно»** → Далее.\n"
        "5. Выбери действие **Telegram: Отправить сообщение**:\n"
        f"   • Кому: `@Company_Hr_bot`\n"
        "   • Текст: `/pay [Сумма] [Продавец]`\n\n"
        "✨ Все траты будут автоматически появляться и в Telegram, и в мобильном приложении!"
    )
    bot.reply_to(message, text, parse_mode='Markdown')

# Обработчик текста и покупок
@bot.message_handler(content_types=['text'])
def handle_text(message):
    text = message.text.strip()

    if any(k in text.lower() for k in ['купил', 'потратил', 'оплата', 'взял', 'чек', 'расход']):
        nums = re.findall(r'\b\d+(?:[\.,]\d+)?\b', text)
        if nums:
            amount = float(nums[0].replace(',', '.'))
            desc = re.sub(r'\b\d+(?:[\.,]\d+)?\b', '', text)
            desc = re.sub(r'(рублей|рубля|руб|р|потратил|купил|на|в|оплата|за)\b', '', desc, flags=re.IGNORECASE).strip()
            merchant = desc if desc else "Покупка"
            category = auto_detect_category(merchant)
            add_expense(message.from_user.id, amount, category, merchant)
            total = get_monthly_total(message.from_user.id)
            bot.reply_to(
                message,
                f"💳 **Записал расход и добавил в приложение!**\n\n"
                f"• Сумма: **{amount:.2f} ₽**\n"
                f"• Категория: {category}\n"
                f"• Заметка: {merchant}\n\n"
                f"📈 Всего за месяц: **{total:.2f} ₽**",
                reply_markup=get_main_keyboard(),
                parse_mode='Markdown'
            )
            return

    bot.send_chat_action(message.chat.id, 'typing')
    ai_response = call_gemini(message.from_user.id, text)
    bot.reply_to(message, ai_response, reply_markup=get_main_keyboard())

if __name__ == '__main__':
    import time
    threading.Thread(target=run_flask, daemon=True).start()
    print("Telegram Bot and Sync API server started on port 5000...")
    while True:
        try:
            bot.infinity_polling(timeout=20, long_polling_timeout=20, skip_pending=True)
        except Exception as e:
            print(f"Network glitch, reconnecting in 5s...")
            time.sleep(5)
