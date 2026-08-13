# Level 3 — 高級

型別系統的進階武器,以及把程式跑得又省又快的工程手藝。
到這一級,型別不再只是「防呆」,而是**設計工具**:
讓不合法的狀態寫不出來、讓 API 自己說明自己。

## 章節

| 章 | 教材 | 習題 |
|----|------|------|
| 1 Phantom types 與 DataKinds | `notes/01-phantom-types.md` | `E01Phantom.hs` |
| 2 GADTs | `notes/02-gadts.md` | `E02Gadts.hs` |
| 3 Type families | `notes/03-type-families.md` | `E03TypeFamilies.hs` |
| 4 DerivingVia | `notes/04-deriving-via.md` | `E04DerivingVia.hs` |
| 5 Optics(lens 的原理) | `notes/05-optics.md` | `E05Optics.hs` |
| 6 串流處理 | `notes/06-streaming.md` | `E06Streaming.hs` |
| 7 效能調校 | `notes/07-performance.md` | `E07Performance.hs` |

## 使用方式

```powershell
cabal repl level03-advanced    # 跟著教材實驗
cabal test level03-advanced    # 驗收(全綠 = 通關)
cabal test level03-advanced -f solutions   # 用參考解答驗證測試
```

## 教學立場(延續前兩級)

- 型別技巧只教「解決真問題」的用法:phantom tag 防止 ID 混用、
  GADT 讓 DSL 不可能組出型別錯的程式、associated type 解決
  「容器沒有型別參數」的真實限制。炫技寫法不教。
- Optics 先教**原理**(van Laarhoven lens 只是 `Functor` 的應用),
  再指路生態系(`optics`、`lens`、`microlens`)——會原理之後,
  任何一套 API 都是查文件的事。
- 串流:lazy IO 是已淘汰的陷阱,本章教嚴格、定量記憶體的
  逐行處理模式,並識讀 `streamly`/`conduit` 的定位。
- 效能:先量測再優化。profiling 與 benchmark 工具在教材中示範,
  習題聚焦最常用的三板斧:嚴格累加器、嚴格容器、單趟演算法。
