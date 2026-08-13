# 第 7 章 — 效能調校:先量測,再動手

## 鐵律:不量測,不優化

Haskell 的效能直覺特別容易錯(惰性 + 最佳化器都會顛覆猜測)。工具:

```powershell
# 1. 整體時間/記憶體統計(看 maximum residency 抓 space leak)
cabal run app -- +RTS -s

# 2. Profiling:哪個函式吃掉時間/記憶體
cabal run app --enable-profiling -- +RTS -p    # 產生 app.prof

# 3. Benchmark 微觀比較:tasty-bench(輕量)或 criterion
```

先跑 `+RTS -s`:`maximum residency` 異常大 → space leak,
先修洩漏再談速度。`productivity` 低(< 90%)→ GC 壓力大,
通常也是洩漏或過多小配置。

## 三板斧之一:嚴格累加器

Level 2 的老朋友,效能問題的第一嫌疑犯。多欄位累加的標準寫法
是**嚴格欄位的自訂型別**,不要用 tuple(tuple 欄位是惰性的):

```haskell
data SL = SL !Int !Int                    -- 嚴格,不堆 thunk

sumAndLength :: [Int] -> (Int, Int)
sumAndLength xs = case foldl' step (SL 0 0) xs of SL s n -> (s, n)
  where step (SL s n) x = SL (s + x) (n + 1)
```

一趟走完,O(1) 空間。順帶學到:**能一趟就不要兩趟**
(`(sum xs, length xs)` 走兩趟,還各自抓著 list 頭 → 洩漏)。

## 三板斧之二:嚴格容器 + 對的資料結構

```haskell
import Data.Map.Strict qualified as Map   -- 不是 Data.Map.Lazy!

histogram :: [Text] -> Map.Map Text Int
histogram = foldl' (\m w -> Map.insertWith (+) w 1 m) Map.empty
```

lazy Map 的值欄位會堆 `1+1+1+...` 的 thunk 鏈,strict Map 每次插入就算。
選型速查:隨機查找 `Map`/`HashMap`、整數鍵 `IntMap`、
數值大陣列 `vector`(unboxed 版 `Data.Vector.Unboxed` 最快)、
字串一律 `Text`。

## 三板斧之三:讓 fusion 幫你消掉中間 list

```haskell
sumSquaresEven :: Int -> Int
sumSquaresEven n = foldl' (+) 0 [x * x | x <- [1 .. n], even x]
```

看起來會生出一條百萬元素的 list?開 `-O1`(cabal 預設)後 GHC 的
**list fusion** 把「產生 → 過濾 → 映射 → 摺疊」熔成一個迴圈,
不配置任何 list。條件:管線用標準組合子(map/filter/fold/枚舉),
中間結果不要另外命名共享。寫管線風格,讓最佳化器工作。

## 常見洩漏清單(照著檢查)

1. `foldl` → 改 `foldl'`;累加器 tuple → 改嚴格型別。
2. 長壽 record 的欄位沒加 `!` → `StrictData`。
3. `Data.Map` 忘了 `.Strict`;`modifyTVar` 忘了 `'`。
4. 大 list 被兩個消費者共享(list 頭被抓住,整條進不了 GC)。

## 2026 實務準則

1. 順序:量測 → 修洩漏 → 換演算法/資料結構 → 微調。倒著做 = 白工。
2. `-O1` 是 cabal 預設,別急著上 `-O2`(編譯慢很多,收益常有限)。
3. benchmark 用 `tasty-bench` 起步,要統計嚴謹再上 `criterion`。

## 習題

`exercises/Exercises/E07Performance.hs` —— `sumAndLength`(嚴格單趟)、
`histogram`(嚴格 Map)、`sumSquaresEven`(fusion 管線)。
測試餵百萬級輸入,寫出洩漏版會明顯變慢(甚至爆記憶體)。
