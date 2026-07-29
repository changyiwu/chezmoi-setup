---
name: chezmoi-sync
description: chezmoi 同步狀況檢查（家目錄 ↔ 來源 repo ↔ GitHub 三處比對）。當使用者說「chezmoi 同步」、「chezmoi 狀況」、「檢查 chezmoi」、「技能有沒有同步」、「dotfiles 同步」、「三台技能一致嗎」、「我的技能推上去了嗎」等要確認全域技能同步狀態的請求時，請一定要使用此技能。本技能會比對 target（家目錄）、source（~/.local/share/chezmoi）、remote（GitHub）三個地方的落差，判讀該先收上去還是先拉下來，並產出可執行的建議指令。只讀不動手，任何會改動的指令都先問過才跑。若使用者說的「同步」是收工存檔的意思，那是 shutdown 技能，不是本技能。
---

# chezmoi 同步狀況檢查

一句「chezmoi 同步」，回答三個問題：**現在哪裡跟哪裡不一樣、為什麼、我該先做哪一步。**

搭配專案文件：`我的雲端硬碟/agents/chezmoi-setup/README.md`（核心概念、已知的坑、速查表）。

## 心智模型：三個地方、兩段落差

```
   remote                    source                      target
GitHub repo    ←─push─    ~/.local/share/chezmoi   ←─add──   C:\Users\chang
dotfiles-      ──pull─→    （git working tree）     ──apply─→  .claude/skills/
agent-skills                                                  .agents/skills/
                                                              .config/opencode/skills/
                                                              .gemini/config/skills/
        └── 落差 B：git ──┘         └── 落差 A：chezmoi ──┘
```

- **落差 A（source ↔ target）**：`chezmoi status` / `chezmoi diff` 看得到
- **落差 B（source ↔ remote）**：`chezmoi git -- ...` 問 git

**最重要的一條規則 —— 順序不能反：**

> **先把這台的改動收上去（add → commit → push），再把別台的拉下來（pull → diff → apply）。**

因為 `apply` 是 source 蓋 target，先拉後套會**直接蓋掉這台還沒收進來的改動**。`chezmoi update` 是 pull + apply 兩步合一，同樣有這個風險 —— 所以只有在確認 target 乾淨時才建議用它。

## 步驟 0：環境檢查（沒過就不用往下做）

> ⚠️ **2026-07-29 現況：三台都還沒有 chezmoi，遠端 repo `changyiwu/dotfiles-agent-skills` 已刪除。**
> 方向已定案要重建，但還沒動工。在重建完成前，這個技能在任何一台都只會走到「尚未建置」那格就停住 ——
> 這是預期行為，不是壞掉。重建步驟見 `chezmoi-setup/README.md`〈從零重建〉。

```powershell
Get-Command chezmoi -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
Test-Path "$HOME\.local\share\chezmoi"
```

| 情況 | 怎麼做 |
|------|--------|
| 兩者都有 | 往下走 |
| 找不到 `chezmoi` 但**剛用 winget 裝過** | PATH 還沒生效（README 已知的坑 4）。去 `$HOME\AppData\Local\Microsoft\WinGet\Packages\` 找 `chezmoi.exe` 直接用完整路徑跑，並告訴使用者「這個 session 之後要重開才吃得到 PATH」 |
| 找不到 `chezmoi`，也沒裝過 | **先確認整體是否已重建**（見上方警告）。若遠端 repo 仍不存在 → 回報「尚未建置」，指向〈從零重建〉，到此為止。若已重建 → 這台是第 2／3 台，建議跑 `chezmoi-setup\bootstrap-new-machine.ps1`。兩種情況都**不要**自己 winget install |
| 有 `chezmoi` 但來源目錄不存在 | 裝了沒 init。建議 `chezmoi init https://github.com/changyiwu/dotfiles-agent-skills.git`（只複製 repo，不動家目錄），然後**先 diff 再說**。若該 repo 尚未重建，`init` 會失敗 —— 那就是「尚未建置」，改走〈從零重建〉 |

## 步驟 1：落差 A —— 家目錄 vs 來源

```powershell
chezmoi status
```

沒有輸出 = 兩邊一致。有輸出的話是兩欄格式，**兩欄意義不同，是本技能判讀的關鍵**：

| 欄位 | 意義 | 代表什麼 |
|------|------|---------|
| **第一欄** | 家目錄實際狀態 vs chezmoi 上次寫入的狀態 | **你直接改了 target** —— 這些改動只存在這台，`apply` 會把它蓋掉 |
| **第二欄** | 家目錄實際狀態 vs 來源的目標狀態 | **`apply` 會動它** —— 別台推來的新東西，或你在 source 改的 |

字母：`M` 修改、`A` 新增、`D` 刪除、`R` 腳本會被執行。

判讀不確定時就跑 `chezmoi diff`（唯讀、安全，可以隨便跑）看實際內容差異。**`diff` 才是「apply 到底會做什麼」的權威**，status 只是快照。

## 步驟 2：落差 B —— 來源 vs GitHub

```powershell
chezmoi git -- fetch --quiet
chezmoi git -- rev-list --count '@{u}..HEAD'   # ahead：有 commit 沒推
chezmoi git -- rev-list --count 'HEAD..@{u}'   # behind：遠端有新東西沒拉
chezmoi git -- status --porcelain              # 來源 worktree 有沒有沒 commit 的改動
```

> ⚠️ `'@{u}'` **一定要用單引號包起來**。PowerShell 會把裸的 `@{` 當成 hashtable 語法，直接噴解析錯誤。若這個分支沒有 upstream，改用 `origin/master`（本 repo 預設分支是 `master`）。

fetch 失敗（離線、憑證過期）時：**把遠端狀態標為「未知」照實回報，不要猜、不要拿本地資訊冒充**。落差 A 的結論仍然有效，照樣報。

## 步驟 3：兩個容易漏掉的體檢

**A. `readonly_` / `private_` 前綴**（README 已知的坑 2 —— 每次 `chezmoi add` 都會復發）

```powershell
Get-ChildItem "$HOME\.local\share\chezmoi" -Recurse -Force -Directory |
  Where-Object { $_.Name -match '^(readonly_|private_)' }
```

有東西 = 這個壞狀態會被推給另外兩台，害 `~/.gemini`、`~/.config/opencode` 變唯讀、agent 寫不進去。建議 `chezmoi chattr noreadonly <路徑>`（要寫 `noreadonly`，寫 `-readonly` 會被 PowerShell 當成自己的參數）。

**B. 刪除偵測**（在家目錄刪掉的技能，下次 apply 會復活）

```powershell
chezmoi managed | ForEach-Object {
  $p = Join-Path $HOME $_
  if (-not (Test-Path -LiteralPath $p)) { $_ }
}
```

列出來的是「來源還管著、但家目錄已經沒有」的路徑。問使用者是**故意刪的**（→ `chezmoi forget` 脫離納管，或 `chezmoi destroy` 三台都刪）還是**誤刪**（→ `chezmoi apply` 讓它回來）。**不要自己決定。**

## 步驟 4：判讀與建議

把落差 A、B 交叉起來對照。**先收上去、再拉下來**是所有建議的排序依據：

| 狀況 | 建議 |
|------|------|
| A、B 都乾淨 | 三處一致，沒事做 |
| 第一欄有字母（target 被直接改過） | **先收回來**：`chezmoi add --recursive <路徑>` → 檢查 `readonly_` → commit + push。**這種狀況下絕對不要先 apply** |
| 只有第二欄有字母 | `chezmoi diff` 看清楚 → 確認後 `chezmoi apply` |
| 兩欄都有字母 | 危險：兩邊各自改過。**逐檔 `chezmoi diff` 攤開給使用者選**，不要整批 apply |
| behind > 0 | 別台推了新東西。target 乾淨 → `chezmoi update`；target 不乾淨 → 先收上去，再 `chezmoi git -- pull --rebase` → `diff` → `apply` |
| ahead > 0 | 有 commit 沒推：`chezmoi git -- push`。順便提醒：commit 成功不等於 push 成功（README 自動化那節的坑 2） |
| ahead 且 behind | 兩台分岔了。`chezmoi git -- pull --rebase` 可能撞衝突；先講清楚衝突了要怎麼收（`git rebase --abort` 隨時可以全身而退） |
| 來源 worktree dirty | 有改動沒 commit：列出檔名，問是不是要一起 commit |

**憑證檢查（每次都做）**：要建議 commit 前，掃一眼待提交的檔案有沒有 `auth.json`、`*.env`、`*token*`、`*key*`、`.sqlite`。有的話**先停下來警告**，不要納入 commit —— 這類東西一律不納管（README〈刻意不納管〉）。

## 報告格式

```
🏠 家目錄（target）：<一致｜N 個檔案被直接改過｜apply 會動 N 個檔案>
📦 來源（source）：<clean｜N 個未 commit 改動>
☁️ 遠端（remote）：<同步｜落後 N｜超前 N｜分岔｜未知（fetch 失敗）>
🔍 體檢：<readonly_ 前綴 N 個｜刪除偵測 N 筆｜都正常>

📖 白話說明：<一到兩句，說明現在是什麼情況、為什麼會這樣>

➡️ 建議照這個順序做：
   1. <指令>   ← <為什麼是這步>
   2. <指令>

要我從第 1 步開始跑嗎？
```

最後**停下來等使用者點頭**。

## 執行權限

使用者確認後可以直接跑：`chezmoi add`、`chezmoi chattr noreadonly`、`chezmoi git -- pull --rebase` / `commit` / `push`、`chezmoi diff`、`chezmoi status`、`chezmoi managed`、`chezmoi doctor`。

**跑完 `push` 一定要確認回傳結果**，不能只看 commit 成功就回報「已推上去」。

### 不該做的事

- ❌ **不主動** `chezmoi apply` / `chezmoi update` —— 會覆蓋家目錄，一律先 diff 再等確認
- ❌ **不主動** `chezmoi destroy` / `chezmoi forget` —— 刪除的事只有使用者能決定
- ❌ 不建議使用者直接編輯 `~/.claude/skills/...` —— 那是 target，改用 `chezmoi edit` 或改完 `chezmoi add --recursive`
- ❌ 不把憑證檔納管、不 commit
- ❌ 沒裝 chezmoi 就別硬跑，也別自己 winget install —— 走 `bootstrap-new-machine.ps1`
- ❌ fetch 失敗時不要假裝知道遠端狀態

## 兩套同步機制的接縫（重要）

`project-init` / `startup` / `shutdown` 這三個技能**同時被兩套機制碰到**：

1. **GDrive `Copy-Item`** —— 原始檔在 `我的雲端硬碟/agents/cross-device-agent-skills/`，用 README 那段 `Copy-Item` **單向**覆蓋四份安裝副本。那是這三個技能的權威來源
2. **chezmoi** —— 家目錄四個技能目錄整包納管，負責三台之間的**雙向**同步

`Copy-Item` 是從 chezmoi 背後直接寫 target。所以跑完那段同步之後，`chezmoi status` 第一欄**必然**會出現這三個技能（意思是「你直接改了 target」）。**這不是壞事**，正解是 `chezmoi add --recursive` 把新版收進來源再推。看到這個組合直接這樣解釋，不要當成異常。

反過來要小心：**`chezmoi apply` 會把這三個技能蓋成 source 的版本，可能比 GDrive 原始檔舊。** 有疑慮時先 `chezmoi diff` 看清楚，再去 `cross-device-agent-skills` 跑 `git diff HEAD --stat` 與 `git status -sb` 確認原始檔本身是不是最新（GDrive 偶爾會餵出過期內容，這種「兩邊一起舊」只有拿 git origin 當權威才看得出來）。

> 反向依賴也要知道（2026-07-29 起）：那三個技能的「步驟 0」**直接委派本技能**——載入後跑到「步驟 2：落差 B」為止，三處都乾淨就靜靜往下做，任一段有落差才升級成完整流程（步驟 3、4）並暫停對方。所以本技能是那三個技能的前置關卡，動到步驟 1、2 的判讀時要想到那邊會一起受影響。而 **chezmoi 沒建起來、或本技能還沒安裝到該台的技能目錄之前，對方那道前置檢查是空轉的**（沒裝就整步略過）。這是本專案存在的理由，見 `chezmoi-setup/agents.md`。

## 納管範圍的兩個常見漏項（順手檢查）

- **Codex 在 `~/.agents/skills/`，不是 `~/.codex/skills/`**（後者只有不納管的 `.system/`）。若 `chezmoi managed` 裡沒有對應 `.agents/skills/` 的項目，代表 Codex 那份**根本沒被同步**，回報給使用者決定要不要補納管
- 四個目錄的技能**數量本來就不同**（各家有各家專屬的 `claude-*`／`codex-*`／`opencode-*`／`antigravity-*`），不要把數量差異當成漏同步

## 注意事項

- 所有訊息使用**繁體中文**
- **原始檔位置（2026-07-28 起）**：`我的雲端硬碟/agents/chezmoi-setup/chezmoi-sync/`，隨本專案 repo 版控。
  目前**未安裝到任何 Agent 的技能目錄，也未納入任何同步機制** —— 要用的話手動 `Copy-Item` 到該台的技能目錄。
  **既定規劃（2026-07-29 定案）**：chezmoi 重建完成後，`Copy-Item` 到四家技能目錄，再 `chezmoi add --recursive` 交給 chezmoi 納管。
  **不要**放進 `cross-device-agent-skills`，那是另一套機制、另一個受眾（公開教學專案）
- 來源 repo `~/.local/share/chezmoi` **不可放進 Google 雲端硬碟**（git working tree 會跟同步引擎打架）
