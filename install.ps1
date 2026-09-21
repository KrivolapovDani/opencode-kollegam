# install.ps1 — установка комплекта opencode-kollegam
# Скрипт: копирует промты и скилы, настраивает opencode (учитель + разработчик),
# подключает базу ошибок. Повторный запуск = обновление.
#
# Установка по ссылке (в opencode напишите):
#   Установи комплект по ссылке https://github.com/KrivolapovDani/opencode-kollegam
# Агент выполнит: git clone + этот скрипт.
#
# Режимы запуска:
#   install.ps1              — обычная установка (git, если есть; иначе ZIP)
#   install.ps1 -Offline     — без GitHub: без входа в GitHub, база ошибок ZIP-ом
#   install.ps1 -Offline -SkipOshibki  — совсем без сети: база ошибок не качается

param(
    [switch]$Offline,
    [switch]$SkipOshibki
)

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

# 5. Вход в GitHub (необязательно; пропускается в режиме -Offline)
if ($Offline) {
    Write-Host "[OK] Режим -Offline: вход в GitHub пропущен"
} elseif (Get-Command gh -ErrorAction SilentlyContinue) {
    gh auth status 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[.] Вход в GitHub не выполнен. Откроется браузер — подтвердите вход (или закройте окно, чтобы пропустить)."
        gh auth login --web
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[!] Вход не выполнен. Это не мешает установке: база ошибок скачается ZIP-ом."
        } else {
            Write-Host "[OK] Вход в GitHub выполнен"
        }
    } else {
        Write-Host "[OK] GitHub уже подключён"
    }
} else {
    Write-Host "[OK] gh не установлен — вход в GitHub пропущен (для установки не нужен)"
}

# 6. База ошибок (git, если есть; иначе — ZIP без git)
# Репозиторий принадлежит автору комплекта (KrivolapovDani).
$owner = "KrivolapovDani"
$oshibkiRepo = "oshibki-kollegam"
$oshibkiBranch = "master"

function Update-OshibkiFromZip {
    param([string]$DestDir)
    $zipUrl = "https://github.com/$owner/$oshibkiRepo/archive/refs/heads/$oshibkiBranch.zip"
    $zipPath = Join-Path $env:TEMP "$oshibkiRepo.zip"
    $extractDir = Join-Path $env:TEMP "$oshibkiRepo-extract"
    try {
        Write-Host "[.] Скачиваю базу ошибок ZIP-ом (без git)..."
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        if (Test-Path $extractDir) { Remove-Item -LiteralPath $extractDir -Recurse -Force }
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
        $inner = Get-ChildItem -LiteralPath $extractDir -Directory | Select-Object -First 1
        if (-not $inner) { throw "В архиве нет папки" }
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
        Copy-Item -Path (Join-Path $inner.FullName "*") -Destination $DestDir -Recurse -Force
        Write-Host "[OK] База ошибок скачана ZIP-ом: $DestDir"
        return $true
    } catch {
        Write-Host "[!] Не удалось скачать базу ошибок ZIP-ом: $($_.Exception.Message)"
        Write-Host "    Ядро комплекта установлено. Базу ошибок можно подключить позже (повторный запуск install.ps1)."
        return $false
    }
}

if ($owner) {
    if ($SkipOshibki) {
        Write-Host "[OK] -SkipOshibki: база ошибок пропущена"
    } else {
        $gitAvailable = [bool](Get-Command git -ErrorAction SilentlyContinue)
        $isGitClone = Test-Path (Join-Path $oshibkiDir ".git")
        if ($gitAvailable -and -not $Offline) {
            if (-not (Test-Path $oshibkiDir)) {
                git clone "https://github.com/$owner/$oshibkiRepo.git" $oshibkiDir 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] База ошибок склонирована: $oshibkiDir"
                } else {
                    Write-Host "[!] git clone не удался — пробую ZIP..."
                    Update-OshibkiFromZip -DestDir $oshibkiDir | Out-Null
                }
            } elseif ($isGitClone) {
                git -C $oshibkiDir pull 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] База ошибок обновлена: $oshibkiDir"
                } else {
                    Write-Host "[!] git pull не удался — пробую ZIP..."
                    Update-OshibkiFromZip -DestDir $oshibkiDir | Out-Null
                }
            } else {
                Update-OshibkiFromZip -DestDir $oshibkiDir | Out-Null
            }
        } else {
            Update-OshibkiFromZip -DestDir $oshibkiDir | Out-Null
        }
    }
} else {
    Write-Host "[!] Не удалось определить GitHub-логин. База ошибок не подключена."
}

# 6a. Обновление комплекта (если папка — клон репозитория; в -Offline пропускаем)
if (-not $Offline -and (Test-Path (Join-Path $src ".git"))) {
    git -C $src pull 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Комплект обновлён (git pull)"
    } else {
        Write-Host "[!] Не удалось обновить комплект. Проверьте git в папке $src"
    }
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
