<#
.SYNOPSIS
  在新的 Windows 機器上設定 chezmoi，同步四種 Agent 的全域技能。

.DESCRIPTION
  安裝 chezmoi、拉取 dotfiles repo、顯示將要套用的差異，
  然後等你確認才真的寫入家目錄。詳細說明見 README.md。

.EXAMPLE
  .\bootstrap-new-machine.ps1
#>

[CmdletBinding()]
param(
    [string] $RepoUrl = 'https://github.com/changyiwu/dotfiles-agent-skills.git'
)

$ErrorActionPreference = 'Stop'

function Write-Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }

# --- 1. 安裝 chezmoi ---------------------------------------------------------
Write-Step 1 '檢查 chezmoi'

$chezmoi = (Get-Command chezmoi -ErrorAction SilentlyContinue).Source

if (-not $chezmoi) {
    # 剛用 winget 裝完但沒重開 shell 的話，PATH 還沒生效，先直接找 exe
    $chezmoi = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter chezmoi.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}

if (-not $chezmoi) {
    Write-Host '    未安裝，透過 winget 安裝中…'
    winget install --id twpayne.chezmoi --accept-source-agreements --accept-package-agreements --disable-interactivity

    # winget 剛裝好時 PATH 尚未生效，直接找出 exe 路徑
    $chezmoi = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter chezmoi.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName

    if (-not $chezmoi) {
        throw '安裝後仍找不到 chezmoi.exe，請重開 PowerShell 再跑一次這個腳本。'
    }
    Write-Host "    已安裝：$chezmoi" -ForegroundColor Green
} else {
    Write-Host "    已存在：$chezmoi" -ForegroundColor Green
}

& $chezmoi --version

# --- 2. 初始化來源 repo ------------------------------------------------------
Write-Step 2 "初始化來源 repo（$RepoUrl）"

$sourceDir = Join-Path $env:USERPROFILE '.local\share\chezmoi'

if (Test-Path (Join-Path $sourceDir '.git')) {
    Write-Host '    來源目錄已存在，改成拉取最新版'
    & $chezmoi git -- pull --ff-only
} else {
    # init 只複製 repo，不會動到家目錄
    & $chezmoi init $RepoUrl
}

Write-Host "    來源目錄：$(& $chezmoi source-path)" -ForegroundColor Green

# --- 3. 顯示差異 -------------------------------------------------------------
Write-Step 3 '以下是將要套用到家目錄的變更'

$diff = & $chezmoi diff

if (-not $diff) {
    Write-Host '    沒有差異，家目錄已經是最新狀態。' -ForegroundColor Green
    exit 0
}

$diff | Out-Host

Write-Host @'

    請確認上面的差異。重點提醒：
      * 只有「新增」→ 放心套用。
      * 有「刪除既有內容」→ 表示這台的技能版本和 repo 不同，套用會覆蓋掉本機版。
        想保留本機版就先按 N 中止，改跑：
            chezmoi add --recursive ~/.codex/skills/那個技能
            chezmoi cd; git commit -am "..."; git push; exit
'@ -ForegroundColor Yellow

$answer = Read-Host "`n    要套用嗎？(y/N)"

if ($answer -notmatch '^[Yy]') {
    Write-Host '    已中止，家目錄未變動。' -ForegroundColor Yellow
    exit 0
}

# --- 4. 套用 -----------------------------------------------------------------
Write-Step 4 '套用中'
& $chezmoi apply
Write-Host '    完成' -ForegroundColor Green

# --- 5. 驗收 -----------------------------------------------------------------
Write-Step 5 '驗收'

$status = & $chezmoi status
if ($status) {
    Write-Host '    chezmoi status 仍有輸出，代表有東西沒對上：' -ForegroundColor Yellow
    $status | Out-Host
} else {
    Write-Host '    chezmoi status 乾淨，家目錄與來源一致。' -ForegroundColor Green
}

Write-Host "`n納管的技能目錄："
& $chezmoi managed | Where-Object { $_ -match '/skills/[^/]+$' } | Out-Host

Write-Host @'

日常流程：
  chezmoi edit <檔案>    改技能
  chezmoi apply          套用到家目錄
  chezmoi cd             進來源目錄 commit / push（用 exit 離開）
  chezmoi update         從遠端拉取並套用

其他細節見 README.md。
'@ -ForegroundColor Cyan
