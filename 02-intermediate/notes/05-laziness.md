# 第 5 章 — 惰性求值:紅利與代價

## 模型:thunk

Haskell 預設**不算**任何東西,先發一張「欠條」(thunk),
真正需要值的時候才兌現。

```haskell
ghci> x = 1 + 2      -- x 是 thunk,還沒算
ghci> x              -- 需要印出來 → 現在才算
3
```

## 紅利:無限資料、按需計算

```haskell
take 5 [1 ..]                 -- [1,2,3,4,5]:無限 list 只算前 5 個
find (< 0) hugeList           -- 找到第一個就停,後面不碰
takeWhile (< 100) (map (^2) [1 ..])
```

「產生器/迭代器」在別的語言是特殊機制,在 Haskell 是普通 list。
定義搜尋空間和走訪策略可以分開寫 —— 這是惰性的核心價值。

## 代價:space leak

欠條堆太多沒兌現,記憶體就爆了。經典案例你已經在 Level 1 見過:

```haskell
foldl  (+) 0 [1..10^7]   -- 堆一千萬層 (((0+1)+2)+3)... 的 thunk
foldl' (+) 0 [1..10^7]   -- 每步立刻算,O(1) 空間
```

親手體驗一次(記憶體統計看 `maximum residency`):

```powershell
cabal repl level02-intermediate
ghci> :set +s
ghci> foldl (+) 0 [1..10^7]    -- 對比 foldl' 的時間與記憶體
```

## 控制嚴格性的工具

```haskell
-- 1. bang patterns:綁定時就求值(GHC2024 內建)
let !total = expensive

-- 2. 嚴格欄位:資料型別欄位加 !
data Acc = Acc !Int !Int     -- fold 累加器的標準寫法

-- 3. seq / $!:求值到 WHNF
f $! arg                      -- 先算 arg 再呼叫 f

-- 4. 整個模組開 StrictData(讓所有欄位預設嚴格)
{-# LANGUAGE StrictData #-}
```

注意「求值到 WHNF」只剝一層:`seq (Just (1+2))` 只確定它是 `Just`,
裡面的 `1+2` 還是 thunk。要全部算完用 `deepseq` 套件的 `force`。

## 2026 實務準則

1. **長壽的資料要嚴格**:遊戲狀態、累加器、record 欄位 →
   `StrictData` 或手動加 `!`。世界狀態每幀更新,惰性欄位會累積
   整條歷史的 thunk 鏈 —— 這是遊戲最常見的效能殺手。
2. **控制流保持惰性**:list 當管線、搜尋、串流,享受按需計算。
3. 容器用嚴格版:`Data.Map.Strict`、`modifyTVar'`、`foldl'` ——
   帶 `'` 的通常就是嚴格版。

一句話:**資料嚴格,控制惰性**(strict in the spine of your data,
lazy in your control flow)。

## 習題

`exercises/Exercises/E05Laziness.hs` —— 三題分別對應:
嚴格累加器(`average`)、惰性搜尋無限 list(`firstNegative`)、
惰性產出(`takeUntilBudget`)。測試直接餵無限 list,
寫錯策略會逾時,不會默默過。
