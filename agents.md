# chezmoi-setup（專案藍圖）

> 本檔為跨 Agent 通用的專案藍圖（AGENTS.md 開放標準）。任何 Agent 的每個 session 都應先讀本檔＋`handoff.md`。

## 專案簡介

用 chezmoi 在三台 Windows 電腦之間同步 Claude Code、Codex、OpenCode、Antigravity 四種 Agent 的**全域技能目錄**。本資料夾放的是**說明文件與新機器 bootstrap 腳本**；被同步的設定本體要放在另一個 repo `changyiwu/dotfiles-agent-skills`（private，預設分支 `master`）——**該 repo 已於 2026-07-28 前刪除，重建時沿用同名即可**。本機來源目錄為 `~/.local/share/chezmoi`。

核心模型是「兩個地方、兩個方向」：source（`~/.local/share/chezmoi`，git repo，真相儲存處）↔ target（家目錄 `C:\Users\chang`，Agent 實際讀取的地方）。`chezmoi apply` 是 source→target，`chezmoi add` 是 target→source。細節見 [README.md](README.md)。

### 這個專案為誰存在

姊妹專案 `cross-device-agent-skills`（`project-init`／`startup`／`shutdown` 三技能）於 2026-07-29 重新設計後，三技能的「步驟 0」改跑 `chezmoi status` 當前置檢查。**沒有 chezmoi，那道檢查就是永遠的 no-op。** 所以本專案是對方**階段五的前置依賴**，兩者的分工邊界見 [README.md](README.md)〈兩套同步機制的分工邊界〉。

## 關鍵時程

<!-- 尚未設定；之後收工時可補 -->

## 目標與路線圖

> ⚠️ **2026-07-28 現況歸零**：第一台的 chezmoi 設定已移除、遠端 repo 已刪除，三台皆未安裝 chezmoi。
> 各台家目錄的技能檔案本身沒事，但現在只是普通檔案，彼此無同步關係。詳見 [README.md](README.md) 開頭的現況區塊。
>
> ✅ **2026-07-29 方向定案：重建 chezmoi。** 起因是 `cross-device-agent-skills` 於同日重新設計
> （commit `aaf273d`）：刪掉自建的 `check-sync.ps1`，三技能的步驟 0 改跑 `chezmoi status`。
> 原本的三選一因此收斂成一條路——「改用 GDrive check-sync 那套」的腳本已不存在，
> 「先不動」會讓對方的步驟 0 永遠空轉。本專案自此不再是可有可無的獨立專案。

### 已完成

- [x] 撰寫 README 與 `bootstrap-new-machine.ps1`（腳本的預設 repo 網址已失效，待新 repo 建好後更新）
- [x] 撰寫 `chezmoi-sync` 技能（口令「chezmoi 同步」，2026-07-28；尚未安裝、尚未納入同步機制）
- [x] 文件校正到與歸零後的現況一致（2026-07-28）
- [x] 依 cross-device 新設計重新規劃、方向定案（2026-07-29）
- [x] 從源頭消滅 draw 技能的寫死絕對路徑（2026-07-29）—— 改 `claude-code-lazy-packs` 懶人包＋家目錄副本為 `$HOME/`，Antigravity 副本重新同步；chezmoi 因此不必為此開模板（見 [README.md](README.md)〈已知的坑 1〉）
- [ ] ~~第一台電腦完成 chezmoi 初始化與四個 Agent 技能目錄納管（2026-07-22 曾完成）~~ → **已移除，需依〈從零重建〉重做**

### 重建（依序進行）

- [ ] **決定哪一台當「第一台」** —— 2026-07-29 仍未定。這是整個流程**唯一不可逆**的環節：之後另外兩台 `chezmoi apply` 會被第一台的技能內容覆蓋
- [ ] 第一台走〈從零重建〉七步：裝 chezmoi → `chezmoi init`（不帶 URL）→ 先寫 `.gitattributes`／`.chezmoiignore` → `add` 四個技能目錄 → 清 `readonly_` → 驗收 → `gh repo create` 推上去
- [ ] 把〈從零重建〉的實測差異回填 README（該章節目前是從其餘章節推導出來的，尚未實跑驗證）
- [ ] 更新 `bootstrap-new-machine.ps1` 的預設 `$RepoUrl` 指向新 repo
- [ ] 第二台電腦跑 bootstrap 完成設定
- [ ] 第三台電腦跑 bootstrap 完成設定

### 重建之後

- [ ] 把 `chezmoi-sync/` 從本專案 `Copy-Item` 到四家技能目錄，再 `chezmoi add --recursive` 收進來源
- [ ] 回報 `cross-device-agent-skills`：階段五達成，該專案步驟 0 的 `chezmoi status` 從此真的看得見技能副本漂移

## 資料夾結構

```
chezmoi-setup/
├── README.md                    # 主文件：現況、核心概念、納管範圍、與 cross-device 的分工邊界、從零重建、新機器設定、日常流程、已知的坑、速查
├── bootstrap-new-machine.ps1    # 第二/三台用的一鍵腳本（裝 chezmoi → init → diff → 等確認 → apply）※ 預設 repo 網址已失效
├── chezmoi-sync/                # 「chezmoi 同步」技能原始檔（未安裝、未納入同步機制）
│   └── SKILL.md
├── agents.md                    # 本檔，專案藍圖
├── handoff.md                   # 交接檔，每次收工更新
└── .claude/
    └── settings.local.json      # Claude Code 本機設定（不進 git 亦可，視需要）
```

## 同步層級（本專案初始化至第 3 層級）

| 層級 | 平台 | 位置 | 讀取時機 |
|------|------|------|---------|
| L1 | 本地（GDrive） | `agents.md`＋`handoff.md` | 每個 session |
| L2 | GitHub | changyiwu/chezmoi-setup（private） | 指定時 |
| L3 | Obsidian | `chezmoi-setup/專案工作流程.md` | 有需要時 |

## 工作約定

- 任何 Agent、任何電腦：**開工先讀 `handoff.md`，收工必更新 `handoff.md`**
- 修改共用檔案前先讀最新內容，避免覆蓋其他 Agent 的變更
- 所有回應與文件使用繁體中文
- 修改前先確認計畫，優先保留原有資料結構

### 本專案特有

- **不要把 `~/.local/share/chezmoi` 放進 Google 雲端硬碟** — git working tree 會與雲端同步引擎打架
- **不要直接編輯 `~/.claude/skills/...`** — 那是 target，下次 `apply` 會被 source 蓋回去；改用 `chezmoi edit` 或改完 `chezmoi add --recursive`
- 每次 `chezmoi add` 後檢查有無 `readonly_` 前綴目錄跑進來源，有就 `chezmoi chattr noreadonly`
- 憑證檔（`auth.json`、`*.env`、金鑰）一律不納管、不 commit
- **`project-init`／`startup`／`shutdown` 三個技能由 `cross-device-agent-skills` 的 `Copy-Item` 負責，本專案不碰它們的內容**，只在 chezmoi 層面連同整個技能目錄一起納管。跑完對方的 `Copy-Item` 後 `chezmoi status` 第一欄會亮這三個，那是正常的，正解是 `chezmoi add --recursive` 收進來源（見 [README.md](README.md)〈兩套同步機制的分工邊界〉）
