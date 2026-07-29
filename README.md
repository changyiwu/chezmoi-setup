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

## 自動化設計（2026-07-29 定案，待重建完成後實作）

目前是全手動：改完技能自己 `chezmoi add`、自己 `git push`、到另一台自己 `chezmoi update`。
本節是走向自動化的設計。**前提是 chezmoi 已經重建起來**，所以這是〈從零重建〉之後的事。

### 設計原則：風險窗口只有「換電腦」

2026-07-22 的舊版評估提出兩條路（對話觸發 skill／排程器輪詢自動同步），
兩者其實是同一個假設的兩種寫法 —— **讓機器隨時猜你什麼時候想同步**。
但這個專案真正會出事的時刻只有一個：**在 A 機改完技能、跑去 B 機開工**。

而那個時刻已經有東西卡在上面了 —— `cross-device-agent-skills` 的 `startup` / `shutdown`。
它們的步驟 0 已經在跑 `chezmoi status`，只是**只偵測、不處理**。
把那一步從「偵測」延伸成「處理」，自動化就成立了，而且不需要任何新機制。

### 第 1 層（核心）：同步綁在 session 邊界

| 時機 | 動作 | 方向 |
|---|---|---|
| 開工（`startup` 步驟 0） | `chezmoi git -- pull --rebase` → `chezmoi diff` → 確認後 `chezmoi apply` | 拉別台的下來 |
| 收工（`shutdown` 步驟 0） | `chezmoi add --recursive` 四個目錄 → 清 `readonly_` → `pull --rebase` → `push` → **確認 push 真的成功** | 把這台的推上去 |

比舊版兩條路好在三點：

1. **衝突發生時你人在鍵盤前**，而且對話裡就有一個能處理 rebase 衝突的 agent。
   排程器撞上 non-fast-forward 只能寫進日誌等你哪天想起來看。
2. **不會靜默失效。** 排程器被關掉、腳本壞掉是看不見的；`shutdown` 少跑一步會直接印在對話裡。
   下面〈autoPush 的靜默失敗〉那個坑，在這裡是當場可見的。
3. **順序天生就對。** 下面〈開機自動 update 的陷阱〉說「不能只跑 `chezmoi update`，要先推再拉」——
   開工拉、收工推，本來就是這個順序，不用特別記。

> ⚠️ 這需要改的是 `cross-device-agent-skills` 的三技能內容，**不是本專案的檔案**。
> 依〈兩套同步機制的分工邊界〉，三技能的權威來源在對方那邊，改完再由 `Copy-Item` 分發。

### 第 2 層（護欄）：用 chezmoi hooks，別把步驟寫進每支腳本

chezmoi 設定檔支援 `hooks.<command>.pre.command` / `.post.command`（[官方 variables 文件](https://www.chezmoi.io/reference/configuration-file/variables/)）。
把兩個一直復發的步驟掛上去：

- `hooks.add.post` → 清 `readonly_` 的那段 PowerShell（見〈已知的坑 2〉）
- push 前置 → `git pull --rebase`

這樣不管是你手動打指令、agent 代跑、還是排程器跑，**都一定會執行**，
不必在技能和腳本裡各維護一份步驟（那是遲早會走鐘的重複）。

> 🔬 **未實測。** 三台都還沒裝 chezmoi，hook 的實際行為（尤其 post hook 在指令失敗時會不會跑、
> 掛在哪個 command 上最準）要建置完當場驗證，別先照抄。

### 第 3 層（兜底）：排程器降級成唯讀提醒

舊版路線 B 不用整個砍掉，但它唯一補得到的價值是
「你直接用檔案總管把技能資料夾拖進 `~/.codex/skills/`」這種不經過 agent 的改動。
**這件事只需要偵測，不需要修。**

工作排程器每天跑一次 `chezmoi status`，有輸出就跳 Windows 通知，**不做任何寫入**。

因為它不 add、不 push、不 rebase，就不可能弄壞東西 —— 舊版路線 B 要處理的四個雷全部消失：

1. ~~要用 `chezmoi add --recursive` 不能用 `re-add`（`re-add` 只更新已納管檔案，新技能永遠進不來）~~
2. ~~刪除偵測（家目錄刪掉技能，來源不會跟著刪，下次 `apply` 會復活，要 `chezmoi forget`）~~
3. ~~`readonly_` 每輪都要清~~ → 移到第 2 層的 hook
4. ~~push 前要 `pull --rebase`~~ → 移到第 1 層的收工流程

> 其中第 1、2 點仍然適用於**第 1 層的收工流程**：收工要用 `add --recursive`，
> 而「這台刪掉的技能」目前沒有自動處理，得手動 `chezmoi destroy` 或 `chezmoi forget`。

### 第 4 層（設定）：`autoCommit = true`、`autoPush = false`

寫在 `~/.config/chezmoi/chezmoi.toml`：

```toml
[git]
    autoCommit = true
    autoPush = false
```

只要 chezmoi 動到來源目錄（`chezmoi add`、`chezmoi edit`、`chezmoi forget` 等），
就自動 commit，commit 訊息由 chezmoi 產生。commit 是本地的、可逆的、免費的，
開著能保證改動不會漏記。

**push 留給收工一次做完並肉眼確認。** 理由見下面兩個坑。

> 注意 `autoCommit` 只在「chezmoi 被呼叫時」才動作。
> 你直接編輯 `~/.claude/skills/...`（改的是 target，不是 source），chezmoi 根本不知道 ——
> 那是靠第 1 層的收工 `add` 和第 3 層的排程提醒接住的。

### 為什麼 autoPush 要關

**1. autoPush 只 push，不 pull（靜默失敗）**

別台先推過的話會撞上 non-fast-forward。此時狀態很尷尬：
**commit 已經進了本機，只有 push 失敗。**
如果沒仔細看輸出（agent 代跑時很常見），會以為成功了，
然後本機默默累積一堆沒推上去的 commit，直到某天發現別台一直拿不到新技能。

**2. `readonly_` 會被立刻靜默推給另外兩台**

每次 `chezmoi add` 都會重新收進 Windows 唯讀屬性（第一台初始化時清掉了 13 個）。
若 autoPush 開著，這個壞狀態會馬上上 GitHub，另外兩台一 `chezmoi update`
就把 `~/.gemini`、`~/.config/opencode` 設成唯讀，害 agent 寫不進去。
第 2 層的 hook 是為了讓這件事**在 push 之前**一定被清掉。

### 開機自動 update 的陷阱

若哪天想加「登入時自動同步」（工作排程器設登入觸發、延遲 1–2 分鐘等網路就緒），
**不能只跑 `chezmoi update`。** `update` = pull + apply，
而 apply 會拿來源覆蓋家目錄，**會蓋掉這台還沒收進來的本機改動**。
正確順序是「先把這台的改動推上去，再拉別台的下來」—— 也就是第 1 層那個順序。

### 被否掉的替代方案

**「乾脆四個技能目錄做 junction 指到 Google 雲端硬碟，讓 GDrive 自己同步」** —— 不行：

- 沒有版本歷史。技能是手寫的，被覆蓋掉就沒了。
- GDrive 產生的衝突副本會變成 `SKILL (1).md` 直接躺在 skills 目錄裡，影響技能載入。
- 〈已知的坑 5〉的 GDrive vs `.git` 打架問題還在。

### 同步失敗時怎麼辦

**不要自動用某一邊覆蓋。** 技能是手寫的東西，自動選邊很可能默默弄丟剛寫的版本。
第 1 層的設計本來就把衝突推到「你人在鍵盤前」的時刻，停下來處理即可。

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
