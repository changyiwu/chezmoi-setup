# chezmoi-setup（專案藍圖）

> 本檔為跨 Agent 通用的專案藍圖（AGENTS.md 開放標準）。任何 Agent 的每個 session 都應先讀本檔＋`handoff.md`。

## 專案簡介

用 chezmoi 在三台 Windows 電腦之間同步 Claude Code、Codex、OpenCode、Antigravity 四種 Agent 的**全域技能目錄**。本資料夾放的是**說明文件與新機器 bootstrap 腳本**；被同步的設定本體在另一個 repo `changyiwu/dotfiles-agent-skills`（private，預設分支 `master`），本機來源目錄為 `~/.local/share/chezmoi`。

核心模型是「兩個地方、兩個方向」：source（`~/.local/share/chezmoi`，git repo，真相儲存處）↔ target（家目錄 `C:\Users\chang`，Agent 實際讀取的地方）。`chezmoi apply` 是 source→target，`chezmoi add` 是 target→source。細節見 [README.md](README.md)。

## 關鍵時程

<!-- 尚未設定；之後收工時可補 -->

## 目標與路線圖

> ⚠️ **2026-07-28 現況歸零**：第一台的 chezmoi 設定已移除、遠端 repo 已刪除，三台皆未安裝 chezmoi。
> 下列進度已依現況重新校準，詳見 [README.md](README.md) 開頭的現況區塊與〈從零重建〉。

- [ ] ~~第一台電腦完成 chezmoi 初始化與四個 Agent 技能目錄納管（2026-07-22 曾完成）~~ → **已移除，需依〈從零重建〉重做**
- [x] 撰寫 README 與 `bootstrap-new-machine.ps1`（腳本的預設 repo 網址已失效，待新 repo 建好後更新）
- [x] 撰寫 `chezmoi-sync` 技能（口令「chezmoi 同步」，2026-07-28；尚未納入同步機制）
- [ ] **決定方向**（2026-07-29 待決）：重建 chezmoi ／ 改用 GDrive `check-sync.ps1` 那套涵蓋所有技能 ／ 先不動
- [ ] 第一台電腦走〈從零重建〉：建立來源 repo 並推上 GitHub
- [ ] 第二台電腦跑 bootstrap 完成設定
- [ ] 第三台電腦跑 bootstrap 完成設定
- [ ] 決定是否啟用自動化同步（autoCommit/autoPush、對話觸發 skill、工作排程器）— 2026-07-22 暫緩

## 資料夾結構

```
chezmoi-setup/
├── README.md                    # 主文件：現況、核心概念、納管範圍、從零重建、新機器設定、日常流程、已知的坑、自動化評估
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
