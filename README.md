# 🌐 Life AI Ecosystem (ЖизньАИ)

Универсальная автономная экосистема для личной продуктивности, автоматического трекинга финансов через **Apple Pay**, ведения дневника, задач и чата с искусственным интеллектом с умной системой защиты от лимитов (**Multi-AI Fallback 429 Guard**).

---

## 🏗 Структура проекта

```text
life-ai-ecosystem/
├── .github/
│   └── workflows/
│       └── deploy.yml          # Автоматический деплой Flutter Web на GitHub Pages
├── bot/
│   ├── bot.py                  # Telegram бот + синхронизационный REST API (Flask)
│   ├── requirements.txt        # Зависимости для Python
│   └── Procfile                # Конфиг для запуска в облаке (Render / Railway)
├── frontend/                   # Кроссплатформенное приложение на Flutter
│   ├── lib/
│   │   ├── models/             # Модели данных (траты, задачи, дневник, чат)
│   │   ├── providers/          # Управление состоянием (AppProvider)
│   │   ├── screens/            # Экраны (Обзор, Чат, Траты, Задачи, Дневник, Настройки)
│   │   ├── services/           # Multi-AI Service, Storage & Bot Sync Service
│   │   └── widgets/            # Компоненты интерфейса
│   ├── web/                    # Веб-манифест, иконки и оболочка
│   └── pubspec.yaml
├── render.yaml                 # 1-Click Blueprint деплоя бота на Render.com
├── Procfile                    # Запуск корневого процесса
└── README.md
```

---

## ⚡ Ключевые возможности

1. **Multi-AI Fallback 429 Guard**:
   - Приложение и бот используют цепочку нейросетей: **Google Gemini (3.8-Flash)** ➔ **Groq (GPT-OSS-120B / Llama 3)** ➔ **OpenAI** ➔ **Claude** ➔ **OpenRouter**.
   - Если один провайдер выдает `429 Too Many Requests` (исчерпан лимит или квота) или `503 Unavailable`, система автоматически и мгновенно переключается на резервную модель без прерывания диалога.
   - В чате визуально отображается бейдж активной модели и статус `(резервный)`.

2. **Apple Pay ➔ Telegram ➔ Flutter Синхронизация трат**:
   - Быстрые команды iOS автоматически отправляют сумму и данные терминала сразу после касания карточки.
   - Бот поддерживает суммы в тенге (`₸`), рублях (`₽`) и автоматически определяет категории трат (Транспорт, Еда, Кафе, Подписки и т.д.).
   - Данные мгновенно отображаются и в Telegram, и в веб-приложении.

---

## 🚀 Развёртывание (24/7 доступ без включенного ноутбука)

### 1. Веб-приложение (GitHub Pages)

Проект настроен на автоматическую сборку и публикацию через **GitHub Actions**:
1. Откройте ваш репозиторий на GitHub: `https://github.com/Alik200000/life-ai-ecosystem`.
2. Перейдите во вкладку **Settings** ➔ **Pages**.
3. В разделе **Build and deployment** выберите источник **Source: GitHub Actions**.
4. После пуша в ветку `main` GitHub Actions автоматически соберет Flutter Web и опубликует его по адресу:
   👉 **`https://Alik200000.github.io/life-ai-ecosystem/`**

---

### 2. Telegram Бот + API синхронизации (Render.com / Railway)

Чтобы бот и сервер синхронизации работали 24/7 в облаке бесплатно:

#### Вариант А: Быстрый запуск на [Render.com](https://render.com) (Рекомендуется)
1. Зарегистрируйтесь на [Render.com](https://render.com) (через GitHub).
2. Нажмите **New +** ➔ **Web Service**.
3. Подключите ваш репозиторий `Alik200000/life-ai-ecosystem`.
4. Заполните настройки:
   - **Root Directory:** `bot`
   - **Environment:** `Python 3`
   - **Build Command:** `pip install -r requirements.txt`
   - **Start Command:** `python bot.py`
   - **Plan:** `Free`
5. Добавьте переменную окружения (Environment Variables):
   - `TELEGRAM_BOT_TOKEN` = `8906685761:AAFr-u6JvXQPJBSOxBO17fSeAFDyEbFpvBg`
6. Нажмите **Create Web Service**.
7. Render выдаст вам постоянный публичный HTTPS-адрес (например, `https://life-ai-bot.onrender.com`).
8. В настройках Flutter приложения вставьте этот URL в поле **"Синхронизация с Telegram ботом"**:
   `https://life-ai-bot.onrender.com/api/expenses`.

---

## 📱 Настройка быстрой команды Apple Pay на iPhone

1. Откройте приложение **Команды** (Shortcuts) на iPhone.
2. Перейдите во вкладку **Автоматизация** ➔ Нажмите `+` (Новая автоматизация).
3. Выберите событие **"Транзакция" (Transaction)**:
   - Карта: Любая
   - Категория: Любая
   - Выполнять: **Немедленно (Run Immediately)**.
4. Добавьте действие **"Открыть URL" (Open URL)** или **"Получить содержимое URL" (Get contents of URL)**:
   ```text
   https://api.telegram.org/bot8906685761:AAFr-u6JvXQPJBSOxBO17fSeAFDyEbFpvBg/sendMessage?chat_id=6456555935&text=/pay[Сумма][Продавец]
   ```
5. Теперь при любой оплате через Apple Pay чек мгновенно отправляется в бот и синхронизируется с приложением!

---

## 💻 Локальный запуск (для разработки)

### Бот:
```bash
cd bot
pip install -r requirements.txt
python bot.py
```

### Flutter Frontend:
```bash
cd frontend
flutter pub get
flutter run -d chrome
```
