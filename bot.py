import os
import sys

# Ensure bot directory is in sys.path
bot_dir = os.path.join(os.path.dirname(__file__), 'bot')
if bot_dir not in sys.path:
    sys.path.insert(0, bot_dir)

from bot import *

if __name__ == '__main__':
    import time
    threading.Thread(target=run_flask, daemon=True).start()
    print("Telegram Bot and Sync API server started...")
    while True:
        try:
            bot.infinity_polling(timeout=20, long_polling_timeout=20, skip_pending=True)
        except Exception as e:
            print(f"Network glitch, reconnecting in 5s... Error: {e}")
            time.sleep(5)
