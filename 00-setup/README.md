# 00 — 環境建置(Windows)

> 你的機器已裝好:GHC 9.14.1、cabal 3.16、GHCup。本章留作參考與補齊開發體驗工具。

## 工具鏈總覽(2026 現行標準)

| 工具 | 用途 | 安裝方式 |
|------|------|----------|
| **GHCup** | 管理 GHC/cabal/HLS 版本 | 官網一鍵腳本 |
| **GHC** | 編譯器(本課程用 9.14) | `ghcup install ghc 9.14.1` |
| **cabal** | 建置工具(2026 社群主流;Stack 已非首選) | `ghcup install cabal` |
| **HLS** | Haskell Language Server(IDE 支援) | `ghcup install hls` |
| **fourmolu** | 程式碼格式化 | `cabal install fourmolu` |
| **hlint** | Lint 建議 | `cabal install hlint` |

## 編輯器

VS Code + 官方 **Haskell** 擴充套件(依賴 HLS)。開啟本資料夾後,
HLS 會透過 `cabal.project` 自動找到所有子套件,提供型別提示、
即時錯誤、hover 文件、跳轉定義。

## 常用指令

```powershell
cabal update                       # 更新 Hackage 套件索引(第一次必跑)
cabal build all                    # 建置所有套件
cabal repl level01-foundations     # 開 ghci 載入指定套件
cabal test level01-foundations     # 跑該級測試
```

## ghci 快速鍵

| 指令 | 作用 |
|------|------|
| `:t expr` | 查詢型別 |
| `:i name` | 查詢定義/instance 資訊 |
| `:r` | 重新載入 |
| `:doc name` | 查詢文件 |
| `:set -XOverloadedStrings` | 臨時開語言擴充 |

## 檢核

```powershell
ghc --version     # 9.14.1
cabal --version   # 3.16+
```

跑得出來就前進 `01-foundations/`。
