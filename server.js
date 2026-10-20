const { spawn } = require('child_process');

console.log("🚀 Starting Life AI Telegram Bot & API server via server.js...");

// Use python3 on Linux (Render) or python
const pyCmd = process.platform === 'win32' ? 'python' : 'python3';

function startBot(cmd) {
  const botProcess = spawn(cmd, ['bot.py'], {
    stdio: 'inherit',
    env: process.env
  });

  botProcess.on('error', (err) => {
    console.error(`Error spawning ${cmd}:`, err.message);
    if (cmd === 'python3') {
      console.log('Trying fallback to "python"...');
      startBot('python');
    }
  });

  botProcess.on('close', (code) => {
    console.log(`Python bot process exited with code ${code}`);
    process.exit(code);
  });
}

startBot(pyCmd);
