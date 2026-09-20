# install.ps1 — установка комплекта opencode-kollegam
# Скрипт: копирует промты и скилы, настраивает opencode, подключает базу ошибок.
# Повторный запуск = обновление.

$ErrorActionPreference = "Stop"

$src = Split-Path -Parent $MyInvocation.MyCommand.Path
$configDir = Join-Path $env:USERPROFILE ".config\opencode"
$promptsDir = Join-Path $configDir "prompts"
$skillsDir = Join-Path $configDir "skills"
$oshibkiDir = Join-Path $env:USERPROFILE "Documents\oshibki-kollegam"
$configPath = Join-Path $configDir "opencode.jsonc"

Write-Host ""
Write-Host "=== Установка комплекта opencode ==="
Write-Host ""

# 1. Проверка opencode
if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
    Write-Host "[!] opencode не найден. Установите: npm install -g opencode-ai"
    Write-Host "    (или winget install opencode). После установки запустите скрипт снова."
} else {
    Write-Host "[OK] opencode найден"
}

# 2. Копирование промтов
New-Item -ItemType Directory -Path $promptsDir -Force | Out-Null
Copy-Item -Path (Join-Path $src "prompts\*") -Destination $promptsDir -Force -Recurse
Write-Host "[OK] Промты скопированы: $promptsDir"

# 3. Копирование скилов (папки имя\SKILL.md)
New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
Get-ChildItem -Path (Join-Path $src "skills") -Directory | ForEach-Object {
    $dest = Join-Path $skillsDir $_.Name
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item -Path (Join-Path $_.FullName "SKILL.md") -Destination (Join-Path $dest "SKILL.md") -Force
}
Write-Host "[OK] Скилы скопированы: $skillsDir"

# 4. Конфиг opencode.jsonc (создаём только если его нет)
if (-not (Test-Path $configPath)) {
    $user = $env:USERNAME
    $config = @"
{
  "`$schema": "https://opencode.ai/config.json",
  "agent": {
    "teacher": {
      "mode": "primary",
      "description": "Педагог-методист: рабочие программы, уроки, сравнительный анализ методов, оценивание, ОВЗ, внеурочка. Работает по ФГОС/ФОП/ФАОП/СанПиН.",
      "prompt": "{file:./prompts/v6.txt}",
      "temperature": 0.3
    },
    "developer": {
      "mode": "primary",
      "description": "Разработчик: Python, веб, PowerShell/автоматизация, Git/CI-CD, безопасность, обучение программированию.",
      "prompt": "{file:./prompts/dev.txt}",
      "temperature": 0.2
    }
  },
  "mcp": {
    "officecli": {
      "type": "local",
      "command": ["C:\\Users\\$user\\AppData\\Local\\OfficeCLI\\officecli.exe", "mcp"],
      "enabled": true
    },
    "memory": {
      "type": "local",
      "command": ["cmd", "/c", "npx", "-y", "@modelcontextprotocol/server-memory"],
      "environment": { "MEMORY_FILE_PATH": "C:/Users/$user/.config/opencode/memory.jsonl" },
      "enabled": true
    },
    "sequentialthinking": {
      "type": "local",
      "command": ["cmd", "/c", "npx", "-y", "@modelcontextprotocol/server-sequential-thinking"],
      "enabled": true
    },
    "fetch": {
      "type": "local",
      "command": ["C:\\Users\\$user\\.local\\bin\\mcp-server-fetch.exe"],
      "enabled": true
    },
    "time": {
      "type": "local",
      "command": ["C:\\Users\\$user\\.local\\bin\\mcp-server-time.exe"],
      "enabled": true
    }
  }
}
"@
    Set-Content -LiteralPath $configPath -Value $config -Encoding UTF8
    Write-Host "[OK] Создан конфиг opencode: $configPath"
} else {
    Write-Host "[OK] Конфиг opencode уже есть (не трогаем): $configPath"
}

# 5. Вход в GitHub
gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[.] Нужен вход в GitHub. Откроется браузер — подтвердите вход."
    gh auth login --web
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!] Вход не выполнен. Повторите позже: gh auth login --web"
    } else {
        Write-Host "[OK] Вход в GitHub выполнен"
    }
} else {
    Write-Host "[OK] GitHub уже подключён"
}

# 6. База ошибок (клонирование или обновление)
# Репозиторий принадлежит автору комплекта (KrivolapovDani).
# Если репозиторий приватный — нужен доступ от владельца (collaborator).
$owner = "KrivolapovDani"

if ($owner) {
    $repoUrl = "https://github.com/$owner/oshibki-kollegam.git"
    if (-not (Test-Path $oshibkiDir)) {
        git clone $repoUrl $oshibkiDir 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] База ошибок склонирована: $oshibkiDir"
        } else {
            Write-Host "[!] Не удалось склонировать базу ошибок ($repoUrl)."
            Write-Host "    Проверьте, что репозиторий oshibki-kollegam существует у владельца."
        }
    } else {
        git -C $oshibkiDir pull 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] База ошибок обновлена: $oshibkiDir"
        } else {
            Write-Host "[!] Не удалось обновить базу ошибок. Проверьте git в папке $oshibkiDir"
        }
    }
} else {
    Write-Host "[!] Не удалось определить GitHub-логин. База ошибок не подключена."
}

# 7. Проверка officecli (для работы с документами Office)
$officecli = "C:\Users\$env:USERNAME\AppData\Local\OfficeCLI\officecli.exe"
if (Test-Path $officecli) {
    Write-Host "[OK] officecli найден"
} else {
    Write-Host "[!] officecli не найден ($officecli)."
    Write-Host "    Он нужен для работы с документами Word/Excel/PowerPoint."
    Write-Host "    Установите его или спросите у того, кто дал комплект."
}

Write-Host ""
Write-Host "=== Готово ==="
Write-Host "Запустите opencode, выберите агента (teacher или developer) и скажите: самоанализ"
Write-Host ""
