# 用 chezmoi 同步四種 Agent 的全域技能

三台 Windows 電腦之間，同步 Claude Code / Codex / OpenCode / Antigravity 的**全域技能目錄**。

> ## ⚠️ 現況：尚未建置，方向已定案為「重建」（2026-07-29）
>
> 這份文件描述的架構**目前沒有在運作**：
>
> - **三台電腦都沒有安裝 chezmoi**，`~/.local/share/chezmoi` 不存在（先前裝過的已移除）
> - **遠端 repo `changyiwu/dotfiles-agent-skills` 已刪除** —— 2026-07-28 以 `gh repo view` 確認查無此 repo（以 `changyiwu` 身分登入，不是權限問題）
>
> 也就是說，**沒有任何一份被 chezmoi 納管的設定還存在**。各台家目錄裡的技能檔案本身沒事，
> 但它們現在只是普通檔案，彼此之間沒有任何同步關係。
>
> 連帶失去的還有來源 repo 根目錄的 **`.chezmoiignore` 與 `.gitattributes`** —— 排除憑證檔的規則
> 和關掉 CRLF 轉換的設定都要重寫，重建時不能漏（見〈從零重建〉）。
>
> 要重新啟用，**不能**走〈新機器設定〉（那條路的前提是遠端 repo 已存在），要先走〈從零重建〉。
> 其餘章節的**觀念與指令仍然有效**，只是現在還沒有東西可以套用。
>
> ### ✅ 為什麼決定重建（2026-07-29）
>
> 姊妹專案 `cross-device-agent-skills` 於同日重新設計（commit `aaf273d`）：**刪掉自建的
> `check-sync.ps1`，`project-init`／`startup`／`shutdown` 三技能的「步驟 0」改跑 `chezmoi status`。**
>
> 這讓原本擱置的三選一收斂成一條路：
>
> | 原選項 | 結果 |
> |---|---|
> | 改用 GDrive `check-sync.ps1` 那套涵蓋所有技能 | **路已封** —— 腳本自己被刪了 |
> | 先不動 | 讓對方的步驟 0 **永遠空轉**（沒裝 chezmoi 就整步略過） |
> | **重建 chezmoi** | **只剩這條** |
>
> 性質也跟著變了：本專案從「可有可無的獨立專案」變成 cross-device **階段五的前置依賴**。
> 原本「安裝副本落後就照舊版邏輯默默跑完」這個盲點，`check-sync.ps1` 走掉之後**現在沒人在守**，
> 要等 chezmoi 建起來才補得回去。
>
> **下一個待決事項：哪一台當「第一台」。** 這是整個流程唯一不可逆的環節，見〈從零重建〉第 0 步。

- **本機來源目錄（重建後）**：`~/.local/share/chezmoi`

---

## 核心概念：source 與 target

chezmoi 的整個模型就是**兩個地方 + 兩個方向**。搞懂這張圖，後面所有指令都不用背。

**source（來源）= `~/.local/share/chezmoi`**
那個 git repo。裡面是 `dot_claude/skills/...` 這種怪名字的檔案。這是真相的儲存處，
是會被 push 到 GitHub、三台共享的東西。

**target（目標）= 家目錄 `C:\Users\chang`**
四個 agent 實際讀取的地方。agent 不知道 chezmoi 存在，它只讀這裡。

```
                       chezmoi add --recursive
                            （回收，←）
   source                                              target
~/.local/share/chezmoi                            C:\Users\chang
   dot_claude/skills/            ──────────►        .claude/skills/
   dot_codex/skills/                                .codex/skills/
   dot_config/opencode/skills/     chezmoi apply    .config/opencode/skills/
   dot_gemini/config/skills/       （套用，→）       .gemini/config/skills/
```

| 指令 | 方向 | 做什麼 |
|---|---|---|
| `chezmoi apply` | source → target | 拿來源蓋家目錄。**會覆蓋你在家目錄的改動。** |
| `chezmoi add` | target → source | 把家目錄的改動收進 repo |
| `chezmoi diff` | 只比對 | 不動任何東西，先看再說 |
| `chezmoi status` | 只比對 | 沒輸出 = 兩邊一致 |
| `chezmoi update` | 遠端 → source → target | `git pull` + `apply` 兩步合一 |

**這張圖能解釋本文件後面兩個提醒：**

- 「不要直接編輯 `~/.claude/skills/...`」— 那是改 target，下次 `apply` 就被 source 蓋回去。
- 「刪除偵測」— 在 target 刪掉一個技能，source 那份還在，下次 `apply` 它會復活。

> 補充：chezmoi 官方文件裡還有第三個詞。source 經過模板運算後產生的理想狀態叫
> **target state**，家目錄本身叫 **destination directory**。目前沒用模板，
> 所以這兩個是同一件事，可以先不管。等哪天把 `claude-draw/SKILL.md` 改成模板
> （見〈已知的坑 1〉），差別才會浮現：source 存的是 `{{ .chezmoi.homeDir }}`，
> target state 是算完的 `C:/Users/chang`。

---

## 納管範圍

| Agent | 全域技能路徑 | chezmoi 來源路徑 |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `dot_claude/skills/` |
| Codex | `~/.agents/skills/` | `dot_agents/skills/` |
| OpenCode | `~/.config/opencode/skills/` | `dot_config/opencode/skills/` |
| Antigravity | `~/.gemini/config/skills/` | `dot_gemini/config/skills/` |

`dot_` 是 chezmoi 對開頭 `.` 的編碼，不是打錯字。

> **2026-07-28 更正**：Codex 那格原本寫 `~/.codex/skills/`，是錯的。Codex 的使用者技能一律放在
> **`~/.agents/skills/`**；`~/.codex/skills/` 底下只有 Codex 隨附的 `.system/`（不納管）。
> 重建時別再照舊版抄。

### 刻意不納管

| 不納管的東西 | 原因 |
|---|---|
| `~/.claude/`、`~/.codex/` 等目錄的其餘部分 | 裡面有 `auth.json`、`sessions/`、`*.sqlite`、`projects/`、`installation_id` — 憑證與機器專屬狀態，同步會出事 |
| `~/.codex/skills/.system/` | Codex 隨附並自行更新的內建技能（imagegen、skill-creator…），同步只會一直打架 |
| `~/.openai.env` 等金鑰檔 | 每台機器手動建立，或用 `chezmoi add --encrypt` 搭配 age |

排除規則寫在來源目錄的 `.chezmoiignore`。

### 這台（PC-YI-SL）現有的技能盤點（2026-07-29 實測）

| 目錄 | 數量 | 內容 |
|---|---|---|
| `~/.claude/skills/` | 9 | `claude-draw`／`-env-setup`／`-firebase`／`-github`／`-notebooklm`／`-obsidian` ＋ 三技能 |
| `~/.agents/skills/` | 10 | `codex-draw`／`-env-setup`／`-essentials`／`-firebase`／`-github`／`-notebooklm`／`-obsidian` ＋ 三技能 |
| `~/.config/opencode/skills/` | 11 | `opencode-browser`／`-draw`／`-env-setup`／`-firebase`／`-github`／`-install-all`／`-notebooklm`／`-obsidian` ＋ 三技能 |
| `~/.gemini/config/skills/` | 8 | `antigravity-draw`／`-firebase`／`-github`／`-notebooklm`／`-obsidian` ＋ 三技能 |

「三技能」= `project-init`＋`startup`＋`shutdown`，四家都有、內容相同。

> **四個目錄數量不一樣是正常的，不要「修正」它。** 各家有各家專屬的技能
> （`opencode-browser`、`codex-essentials` 只有那一家有），chezmoi 是四個目錄各自納管、
> 不做交叉比對。`chezmoi-sync` 目前四家都沒有（本專案還沒安裝它）。

---

## 兩套同步機制的分工邊界

技能檔案同時被**兩套機制**碰到，兩者管的東西不同、方向也不同。搞混就會互相覆蓋。

```
   cross-device-agent-skills（GDrive 原始檔）
                │
                │  Copy-Item（單向，只有三技能）
                ▼
   家目錄四個技能目錄 ── chezmoi add ──► source ── git push ──► GitHub
   （target）          ◄── apply ────         ◄── pull ────
                                        （雙向，四個目錄全部）
```

| | 誰負責 | 管什麼 | 方向 |
|---|---|---|---|
| **A** | `cross-device-agent-skills` 的 `Copy-Item` 段 | 只有 `project-init`／`startup`／`shutdown` | GDrive 原始檔 → 四份安裝副本，**單向** |
| **B** | chezmoi（本專案） | 四個技能目錄的**全部**內容 | 家目錄 ↔ 來源 repo ↔ GitHub，**雙向、跨三台** |

### 接縫：跑完 A 之後 B 一定會亮

`Copy-Item` 是從 chezmoi 背後直接寫 target。所以每次同步完三技能，`chezmoi status` 的
**第一欄必然出現那三個技能**（意思是「你直接改了 target」）。

**這不是異常，正解是把新版收進來源：**

```powershell
chezmoi add --recursive ~/.claude/skills/project-init  # 四家、三個技能各一次
chezmoi cd; git commit -am "sync 三技能 vX"; git push; exit
```

反過來的風險更需要留意：**`chezmoi apply` 會把三技能蓋成 source 的版本，可能比 GDrive 原始檔舊。**
有疑慮時先 `chezmoi diff` 看清楚，並回 `cross-device-agent-skills` 用 `git diff HEAD --stat`
確認原始檔本身是不是最新的（GDrive 偶爾會餵出過期內容）。

### 為什麼不把三技能也交給 chezmoi 一家管

`cross-device-agent-skills` 是**公開的教學專案**（EP06 懶人包），原始檔要留在 GDrive 讓人 clone；
chezmoi 來源 repo 是 private 的個人 dotfiles。兩者受眾不同，維持 A 為權威來源、B 只做跨機分發最單純。

---

## 從零重建（2026-07-28 現況該走的路）

遠端 repo 已刪除，所以現在**沒有可以 `init` 的來源**。要重新啟用，得先挑一台當「第一台」，
把它家目錄的技能收成新的來源 repo，推上 GitHub，另外兩台才有東西可拉。

> ⚠️ 下面的步驟是**依本文件其餘章節的觀念推導出來的，尚未實際跑過驗證**（2026-07-28 三台都沒裝
> chezmoi，無法當場測）。第一次做的時候逐步確認，跑完把實際遇到的差異回填進這一節。

**第 0 步：先決定哪一台的技能是「正確版本」。** 這一步比任何指令都重要 —— 之後另外兩台
`chezmoi apply` 會被這一台的內容覆蓋。三台的技能目錄若已經各自長歪，先人工比對決定要留哪些。

> 💡 **三技能可以先不用煩惱。** `project-init`／`startup`／`shutdown` 有獨立的權威來源
> （GDrive 的 `cross-device-agent-skills`），第一台開跑前先在那邊跑一次 `Copy-Item` 段
> 把四份副本刷成最新，就不必比對了。第 0 步真正要人工判斷的只有**各家專屬技能**
> （`claude-*`／`codex-*`／`opencode-*`／`antigravity-*`），以及 lazy-packs 那些來源。

```powershell
# 1. 安裝，然後重開 PowerShell（PATH 才會生效，見〈已知的坑 4〉）
winget install --id twpayne.chezmoi

# 2. 建立空的來源目錄（不帶 URL = 從零開始，會順便 git init）
chezmoi init

# 3. 把四個技能目錄收進來源
chezmoi add --recursive ~/.claude/skills
chezmoi add --recursive ~/.agents/skills
chezmoi add --recursive ~/.config/opencode/skills
chezmoi add --recursive ~/.gemini/config/skills

# 4. 清掉這次 add 帶進來的 Windows 唯讀屬性（見〈已知的坑 2〉，一定要做）
Get-ChildItem "$HOME\.local\share\chezmoi" -Recurse -Force -Directory |
  Where-Object { $_.Name -match '^(readonly_|private_)' }
# 有列出東西就對各該路徑跑 chezmoi chattr noreadonly <路徑>
```

**第 5 步：重寫兩個被刪掉的設定檔**（舊 repo 沒了，這兩個要從頭寫）。

`~/.local/share/chezmoi/.chezmoiignore` —— 排除憑證與機器專屬狀態，內容依〈刻意不納管〉那節；
至少要擋掉 `auth.json`、`sessions/`、`*.sqlite`、`projects/`、`installation_id`、
`.codex/skills/.system/` 與各類 `*.env`／金鑰檔。**寫完務必 `chezmoi managed` 確認憑證檔沒被收進去。**

`~/.local/share/chezmoi/.gitattributes` —— 一行 `* -text`，關掉 git 的 CRLF 自動轉換
（見〈已知的坑 3〉）。

```powershell
# 6. 建立遠端 repo 並推上去（private）
chezmoi cd
gh repo create changyiwu/dotfiles-agent-skills --private --source=. --remote=origin --push
exit
```

推完之後，另外兩台就可以照〈新機器設定〉走了。

---

## 新機器設定（第二、三台）

> **前提：遠端 repo 已經存在。** 2026-07-28 現況是 repo 已刪除，所以這一節現在**還不能用** ——
> 先完成上面的〈從零重建〉。

最快的方式是跑本資料夾的腳本：

```powershell
.\bootstrap-new-machine.ps1
```

它會安裝 chezmoi、init、顯示 diff，然後**停下來等你確認**才套用。

若要手動做，等同於下列步驟：

### 1. 安裝 chezmoi

```powershell
winget install --id twpayne.chezmoi
```

裝完**要重開 PowerShell** 才吃得到 PATH。

### 2. 拉取設定

```powershell
chezmoi init https://github.com/changyiwu/dotfiles-agent-skills.git
```

這只會把 repo 複製到 `~/.local/share/chezmoi`，**還不會動到你的家目錄**。

### 3. 先看 diff（不能跳過）

```powershell
chezmoi diff
```

看清楚會改動什麼。三種情況：

- **只有新增** → 直接進第 4 步。
- **這台有 repo 沒有的技能** → chezmoi 不會刪掉它們（它不碰未納管的檔案）。想讓其他機器也拿到，先收進來再推：
  ```powershell
  chezmoi add --recursive ~/.codex/skills/那個技能
  chezmoi cd; git commit -am "add 那個技能 from 這台"; git push; exit
  ```
- **同名技能內容不同** → `apply` 會直接覆蓋成 repo 版本。想保留本機版就先照上面 `chezmoi add` 收進來（會蓋掉 repo 版），或先手動備份再決定。

### 4. 套用

```powershell
chezmoi apply
```

### 5. 驗收

```powershell
chezmoi status      # 沒輸出 = 家目錄與來源一致
chezmoi managed     # 列出所有被納管的路徑
```

---

## 日常流程

### 改技能

**不要直接編輯 `~/.claude/skills/...`** — 那樣 chezmoi 不知道你改了。兩種正確做法：

```powershell
# A. 直接改來源（推薦）
chezmoi edit ~/.claude/skills/claude-draw/SKILL.md
chezmoi apply

# B. 照舊在原位置改，改完回收進來源
chezmoi add --recursive ~/.claude/skills/claude-draw
```

### 新增一個技能

```powershell
chezmoi add --recursive ~/.claude/skills/新技能
```

### 刪除一個技能（三台都刪）

```powershell
chezmoi destroy ~/.claude/skills/舊技能    # 同時從來源和家目錄移除
```

只想脫離納管、保留本機檔案的話用 `chezmoi forget`。

### 推上去

```powershell
chezmoi cd
git add -A
git commit -m "說明改了什麼"
git push
exit
```

### 在另一台拉下來

```powershell
chezmoi update       # = git pull + chezmoi apply
```

想先看再套用：

```powershell
chezmoi git pull
chezmoi diff
chezmoi apply
```

---

## 已知的坑

### 1. 寫死的絕對路徑

`~/.claude/skills/claude-draw/SKILL.md` 裡有：

```
C:/Users/chang/.claude/skills/claude-draw/draw.py
```

三台使用者名稱都是 `chang` 就沒問題。若哪天不是，把該檔轉成模板：

```powershell
chezmoi chattr +template ~/.claude/skills/claude-draw/SKILL.md
chezmoi edit ~/.claude/skills/claude-draw/SKILL.md
```

路徑改成：

```
{{ .chezmoi.homeDir | replace "\\" "/" }}/.claude/skills/claude-draw/draw.py
```

其他三個 agent 的 draw 技能也各自檢查。

### 2. Windows 唯讀屬性

`chezmoi add` 會把 Windows 目錄的唯讀屬性一起收進來，變成來源裡的 `readonly_` 前綴。套用到別台會把 `~/.gemini`、`~/.config/opencode` 設成唯讀，害 agent 寫不進去。2026-07-22 那次初始化清掉了 13 個，但**那個來源 repo 已刪除**，
重建時會整批重來一次，所以每次 `chezmoi add` 完都要檢查：

```powershell
Get-ChildItem "$HOME\.local\share\chezmoi" -Recurse -Force -Directory |
  Where-Object { $_.Name -match '^(readonly_|private_)' }
```

有東西的話就清掉：

```powershell
chezmoi chattr noreadonly ~/那個路徑
```

（注意要寫 `noreadonly`，不能寫 `-readonly` — PowerShell 會把它當成自己的參數。）

### 3. 換行字元

來源 repo 有 `.gitattributes` 設 `* -text`，關掉 git 的 CRLF 自動轉換，確保 `draw.py` 這類腳本在三台之間位元組完全一致。別刪掉它。

### 4. 裝完 chezmoi 要重開 shell / agent

winget 把 chezmoi 加進了**使用者 PATH**，但已經開著的 process 拿的是舊的環境變數。
所以剛裝完的那個視窗（含正在跑的 agent）會找不到 `chezmoi` 指令，重開就好。
`bootstrap-new-machine.ps1` 有處理這種情況（直接去 WinGet Packages 找 exe），
但如果是 agent 要替你跑 chezmoi，記得先重開它。

### 5. 不要把來源 repo 放進 Google Drive

`~/.local/share/chezmoi` 是 git working tree，雲端硬碟的同步引擎會跟 `.git` 打架、產生「衝突副本」。本資料夾（在雲端硬碟裡）只放這份說明和腳本，不放 repo 本身。

---

## 未來可能做的自動化（尚未啟用，2026-07-22 暫緩決定）

目前是全手動：改完技能自己 `chezmoi add`、自己 `git push`、到另一台自己 `chezmoi update`。
以下是要走向自動化時的評估結果，先記著，之後再決定要不要做。

### chezmoi 內建的 autoCommit / autoPush

寫在 `~/.config/chezmoi/chezmoi.toml`：

```toml
[git]
    autoCommit = true
    autoPush = true
```

效果：**只要 chezmoi 動到來源目錄（`chezmoi add`、`chezmoi edit`、`chezmoi forget` 等），
它就會自動 commit 並 push。** commit 訊息由 chezmoi 自動產生。

這兩個是合法設定但目前沒寫進 `chezmoi.toml`，所以是關的。要開只需加上面那三行，
不需要任何腳本。

**但它只解決一半。** 它是在「chezmoi 被呼叫時」才動作 —
如果你直接去編輯 `~/.claude/skills/...`（改的是 target，不是 source），
chezmoi 根本不知道發生過這件事，autoCommit 也不會被觸發。
要讓「改動 → 自動入庫」成立，還是需要有東西去呼叫 `chezmoi add`。

那個「東西」有兩條路，可以並存，也可以只做其中一條。

### 路線 A：對話觸發式（寫成 skill）

在任何資料夾對 agent 說「把這個技能加到全域技能，再加到 chezmoi」，
由 agent 替你呼叫 `chezmoi add` — 一樣會觸發 autoCommit / autoPush，直接推上 GitHub。

skill 不能自動觸發（它只在對話進行中被模型載入時才執行），
但它可以確保**你觸發時做對**，這才是它的價值。所以 skill 的內容不是「跑 `chezmoi add`」一句話，
而是這套完整程序：

1. 先 `chezmoi git -- pull --rebase`
2. 寫進正確的 agent 目錄，遵守命名慣例（`claude-*` / `codex-*` / `opencode-*` / `antigravity-*`）
3. `chezmoi add --recursive <技能路徑>`
4. `chezmoi chattr noreadonly <技能路徑>` — 清掉這次 add 帶進來的唯讀屬性
5. 確認 push **真的成功了**，不是只有 commit 成功

第 4、5 步不能省，理由見下面〈自動化讓兩個舊坑變更糟〉。

**這條路蓋不到的情況**：你直接在檔案總管把技能資料夾拖進 `~/.codex/skills/`，
或用別的編輯器改了 SKILL.md — 你沒開口，就沒人會呼叫 chezmoi。那要靠路線 B。

### 路線 B：排程器（改動就自動同步）

需要 **Windows 工作排程器 + 一支同步腳本**。
這條才蓋得到「不經過 agent 的改動」。

觸發方式建議用**定時輪詢（每 15 分鐘）**而不是 FileSystemWatcher：
watcher 是即時的，但要處理去彈跳、編輯器暫存檔噪音，而且常駐行程被關掉就靜默失效。
技能檔案不是每秒在變的東西，定時輪詢便宜又看得見。

腳本必須處理這四個雷（都是在第一台實際踩過或確認過的）：

1. **要用 `chezmoi add --recursive`，不能用 `chezmoi re-add`** —
   `re-add` 只更新已納管的檔案，新增的技能永遠不會進來。
2. **刪除偵測** — 在家目錄刪掉一個技能，來源不會跟著刪，下次 `apply` 會讓它復活。
   腳本得找出「已納管但目標已不存在」的路徑並 `chezmoi forget`。
3. **`readonly_` 屬性會一直復發** — 每次 `add` 都會把 Windows 唯讀屬性重新收進來
   （見上面〈已知的坑 2〉），腳本每輪都要清一次。
4. **push 前要 `git pull --rebase`** — 三台都在自動推，遲早撞上 non-fast-forward，
   撞到就會靜默失敗直到你發現時已經歪很久。

### 自動化讓兩個舊坑變更糟（A、B 兩條路都適用）

手動流程至少在 push 前還有機會看到問題。一旦 autoPush 開著，就沒有那個空檔了。

**1. `readonly_` 會被立刻靜默推給另外兩台**

每次 `chezmoi add` 都會重新收進 Windows 唯讀屬性（第一台初始化時清掉了 13 個）。
加上 autoPush，這個壞狀態會馬上上 GitHub，另外兩台一 `chezmoi update`
就把 `~/.gemini`、`~/.config/opencode` 設成唯讀，害 agent 寫不進去。
所以每次 add 後都要接 `chezmoi chattr noreadonly <路徑>`。

**2. autoPush 只 push，不 pull**

別台先推過的話會撞上 non-fast-forward。此時狀態很尷尬：
**commit 已經進了本機，只有 push 失敗。**
如果沒仔細看輸出（agent 代跑時很常見），會以為成功了，
然後本機默默累積一堆沒推上去的 commit，直到某天發現別台一直拿不到新技能。
所以動手前先 `chezmoi git -- pull --rebase`，動完確認 push 真的成功。

### 如果要做到「開機自動 update」

工作排程器設登入觸發、延遲 1–2 分鐘等網路就緒。

**但不能只跑 `chezmoi update`。** `update` = pull + apply，
而 apply 會拿來源覆蓋家目錄，**會蓋掉這台還沒收進來的本機改動**。
正確順序是「先把這台的改動推上去，再拉別台的下來」。

### 尚未決定的問題

**同步失敗時（例如 rebase 遇到衝突）該怎麼辦？**
建議是停下來、寫進日誌、跳 Windows 通知，而不是自動用某一邊覆蓋 —
技能是手寫的東西，自動選邊很可能默默弄丟剛寫的版本。

**為什麼是 rebase 而不是 merge？** 三台從同一個 commit 各自長出新 commit 時，
後推的那台會被 git 擋下（non-fast-forward）。`merge` 會生一個合併 commit 把兩條線接起來，
`rebase` 則是把你的 commit 拆下來重新接到遠端最新的後面，維持一條直線。
這個 repo 是一個人的三台機器，歷史應該是一條「什麼時候改了什麼技能」的直線；
用 merge 的話每次自動同步都會生一個空的 `Merge branch 'master'...`，
跑幾個月後想查某個技能上次改動時間會被雜訊淹沒。

代價是 rebase 不保證成功：兩台改到同一個檔案的同一行時，git 無法自行決定，會停下來等人處理。

rebase 衝突的手動處理：

```powershell
chezmoi cd
git status                  # 看哪些檔案衝突
# 手動編輯，處理掉 <<<<<<< ======= >>>>>>> 標記
git add .
git rebase --continue
exit
```

不想處理就 `git rebase --abort`，退回 pull 之前的狀態，什麼都沒發生。

---

## 速查

| 想做什麼 | 指令 |
|---|---|
| 看家目錄與來源的差異 | `chezmoi diff` |
| 看有沒有未同步的改動 | `chezmoi status` |
| 列出納管的所有路徑 | `chezmoi managed` |
| 進來源目錄操作 git | `chezmoi cd` … `exit` |
| 拉遠端並套用 | `chezmoi update` |
| 檢查安裝健康度 | `chezmoi doctor` |
| 來源目錄在哪 | `chezmoi source-path` |
