# 第 5 章 — 惰性求值:紅利與代價

## 模型:thunk

Haskell 預設**不算**任何東西,先發一張「欠條」(thunk),
真正需要值的時候才兌現。ghci 的 `:sprint` 可以把欠條照出來
(`_` 代表「還沒算」):

```haskell
ghci> let x = 1 + 2 :: Int
ghci> :sprint x
x = _                        -- 還是欠條
ghci> x
3
ghci> :sprint x
x = 3                        -- 兌現了,而且結果被記住(不會算第二次)
```

對 list 更有趣——它是一格一格兌現的:

```haskell
ghci> let ys = map (*2) [1,2,3] :: [Int]
ghci> :sprint ys
ys = _                       -- 整條都是欠條
ghci> ys `seq` ()
()
ghci> :sprint ys
ys = _ : _                   -- seq 只確定「它是 (:) 開頭」:WHNF
ghci> length ys
3
ghci> :sprint ys
ys = [_,_,_]                 -- length 走完骨架,但每格的 (*2) 還沒算
ghci> sum ys
12
ghci> :sprint ys
ys = [2,4,6]                 -- 現在全算完了
```

這四個階段就是理解 Haskell 記憶體行為的全部基礎:
**骨架(spine)和元素可以分開兌現,`seq` 只剝最外面一層。**
「最外面一層」有個名字:**WHNF**(weak head normal form)——
求值到最外層建構子(`(:)`、`Just`、`(,)`……)為止。

## 為什麼 Haskell 選擇預設惰性

1987 年組成的 Haskell 委員會要統一當時十幾種相似的函數式語言
(Miranda、Lazy ML、Orwell……),而它們**全部是惰性的**——所以惰性是
歷史繼承,不是憑空決定。但它後來成了 Haskell 純度的守護者:
如果一個語言預設惰性,「什麼時候執行」就不可預測,你就**不可能**允許
任意副作用(印東西的順序會亂掉),於是副作用只能被關進 `IO` 型別裡。
Simon Peyton Jones 的說法是「laziness kept us pure」——
惰性逼出了純函式,純函式又讓惰性安全。

代價是本章後半的 space leak,以及效能直覺變得困難。
2026 的共識不是「惰性錯了」,而是**惰性該用在控制流,不該用在長壽資料**。

## 紅利:無限資料、按需計算

```haskell
take 5 [1 ..]                 -- [1,2,3,4,5]:無限 list 只算前 5 個
find (< 0) hugeList           -- 找到第一個就停,後面不碰
takeWhile (< 100) (map (^2) [1 ..])
```

「產生器/迭代器」在別的語言是特殊機制,在 Haskell 是普通 list。
定義搜尋空間和走訪策略可以分開寫 —— 這是惰性的核心價值。
沒有惰性,`any p (map f xs)` 就得先把整個 `map` 算完;有惰性,
它找到第一個就停。

## 代價:space leak

欠條堆太多沒兌現,記憶體就爆了。經典案例你已經在 Level 1 見過:

```haskell
foldl  (+) 0 [1..10^7]   -- 堆一千萬層 (((0+1)+2)+3)... 的 thunk
foldl' (+) 0 [1..10^7]   -- 每步立刻算,O(1) 空間
```

在 ghci 裡親手量一次(ghci 沒有最佳化,差異最赤裸):

```haskell
ghci> :set +s
ghci> foldl (+) 0 [1..10^7]
50000005000000
(1.56 secs, 1,613,077,768 bytes)     -- 配置 1.6 GB
ghci> foldl' (+) 0 [1..10^7]
50000005000000
(0.23 secs, 880,777,488 bytes)       -- 快 7 倍
```

`+s` 顯示的是總配置量,不是同時佔用的記憶體;要看 space leak 的
真正指標 `maximum residency`,編譯後用 `+RTS -s` 跑(第 3 級效能章)。

### 一個重要但危險的事實:`-O` 常會偷偷救你

同一段 `foldl (+) 0 [1..10^7]` 編譯後開 `-O1`(cabal 預設),
GHC 的 strictness analysis 看出累加器一定會被用到,**自動把它改成嚴格的**,
`+RTS -s` 顯示 maximum residency 只有 44 KB——和 `foldl'` 一樣。

這不代表 `foldl` 沒問題。它代表:

- 你在 ghci 看到的洩漏,編譯後可能消失;反之,累加器一複雜
  (tuple、record、`Maybe`),分析就救不了,洩漏會在正式環境才出現。
- **不要依賴最佳化器猜對**。`foldl'` 與嚴格欄位讓意圖寫在程式碼裡,
  不論最佳化等級都成立。

## 舊做法 → 新做法:`foldl` 為什麼還在 Prelude

`foldl` 從 Haskell 1.0 就存在,那時記憶體小、list 短,沒人在意。
`foldl'` 是後來才加進 `Data.List` 的補救,而 Prelude 裡的 `foldl`
因為向後相容從來沒被改嚴格。**base 4.20(GHC 9.10,2024)終於把 `foldl'`
放進 Prelude**——這是 30 年來社群對這個問題的正式答案:
「`foldl` 留著相容,`foldl'` 才是你該用的」。

同樣的歷史包袱還有:`sum`/`product` 在很久以前是用 `foldl` 定義的
(會洩漏),GHC 9.x 已改成嚴格;`Data.Map` 的預設模組是 lazy 版
(`Data.Map.Strict` 是後來加的);`modifyIORef`/`modifyTVar` 是 lazy 版,
帶 `'` 的才嚴格。規律:**沒有 `'` 的、名字最短的,通常是歷史遺留的惰性版**。

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
裡面的 `1+2` 還是 thunk:

```haskell
ghci> let p = Just (1 + 2 :: Int)
ghci> p `seq` ()
()
ghci> :sprint p
p = Just _                   -- 外殼確定了,內容還是欠條
```

要全部算完用 `deepseq` 套件的 `force`/`deepseq`(要求型別有 `NFData` instance,
一般 `deriving anyclass (NFData)` 加 `Generic` 即可):

```haskell
ghci> import Control.DeepSeq
ghci> let zs = map (*2) [1,2,3] :: [Int]
ghci> zs `deepseq` ()
()
ghci> :sprint zs
zs = [2,4,6]                 -- 一次到底
```

`seq` 與 `deepseq` 的差別用一個會炸的 list 最清楚:

```haskell
let xs = [1, 2, error "boom"] :: [Int]
xs `seq` putStrLn "seq 過了"          -- 印出來:只看了 (:)
evaluate (force xs)                   -- 丟例外 "boom":force 走到第三格
```

### `StrictData` 與 `Strict` 的差別

| 擴充 | 影響範圍 | 建議 |
|---|---|---|
| `StrictData` | 只有 `data`/`newtype` 的**欄位**預設嚴格(等於每個欄位加 `!`) | 長壽資料的模組直接開,2026 常見做法 |
| `Strict` | 上面那些 **加上** 所有函式引數、`let`/`where` 綁定都預設嚴格 | 幾乎不用:把控制流也變嚴格,無限 list、短路全壞 |

`Strict` 把 Haskell 變成另一個語言;`StrictData` 只是把「資料要嚴格」
這條準則變成預設,兩者差很多。

## 2026 實務準則

1. **長壽的資料要嚴格**:遊戲狀態、累加器、record 欄位 →
   `StrictData` 或手動加 `!`。世界狀態每幀更新,惰性欄位會累積
   整條歷史的 thunk 鏈 —— 這是遊戲最常見的效能殺手。
2. **控制流保持惰性**:list 當管線、搜尋、串流,享受按需計算。
3. 容器用嚴格版:`Data.Map.Strict`、`modifyTVar'`、`foldl'` ——
   帶 `'` 的通常就是嚴格版。

一句話:**資料嚴格,控制惰性**(strict in the spine of your data,
lazy in your control flow)。

## 你會看到的錯誤訊息

惰性的錯誤不在編譯期,在執行期,而且長得像這樣:

```
myapp.exe: Heap exhausted;
myapp.exe: Current maximum heap size is 104857600 bytes (100 MB).
myapp.exe: Use `+RTS -M<size>' to increase it.
```

(這是 `-O0` 編譯的 `foldl (+) 0 [1..10^7]` 加上 `+RTS -M100m` 的真實輸出;
沒有 `-M` 限制時它會一路吃到系統記憶體用完。)

或者更常見的是**沒有錯誤訊息**,只有記憶體持續上漲、GC 時間佔比飆高。
所以這章的「錯誤訊息」是 `+RTS -s` 的統計:

```
      38,551,856 bytes maximum residency (5 sample(s))   -- 洩漏版
          44,480 bytes maximum residency (1 sample(s))   -- 修好的版本
```

`maximum residency` 是「某個瞬間同時活著的資料量」。它應該和你的
**問題規模**成正比(遊戲狀態大小),而不是和**跑了多久**成正比。
一路上漲就是洩漏,去找沒加 `'`、沒加 `!` 的累加點。

## ghci 實驗

```haskell
ghci> let x = undefined :: Int
ghci> let pair = (x, 5)
ghci> snd pair                     -- 惰性:沒碰 fst,不會炸
5
ghci> let t = (1 + 1, 2 + 2) :: (Int, Int)
ghci> :sprint t
t = (_,_)                          -- tuple 殼已建好,兩格都是欠條
ghci> fst t
2
ghci> :sprint t
t = (2,_)                          -- 只算了用到的那一半
```

## 常見誤區

- **以為 `seq` 會「全部算完」。** 只到 WHNF。要全部用 `deepseq`/`force`。
- **累加器用 tuple。** `(sum, count)` 兩個欄位都是惰性的,`foldl'` 只會把
  tuple 本身算到 WHNF,裡面照樣堆 thunk。用嚴格欄位的自訂型別(第 3 級效能章)。
- **在 ghci 量效能就下結論。** ghci 沒有最佳化;正式數字要編譯後 `+RTS -s`。
- **全開 `Strict` 想一勞永逸。** 會殺掉無限 list 與短路求值,而且效能未必變好。

## 習題

`exercises/Exercises/E05Laziness.hs` —— 三題分別對應:
嚴格累加器(`average`)、惰性搜尋無限 list(`firstNegative`)、
惰性產出(`takeUntilBudget`)。測試直接餵無限 list,
寫錯策略會逾時,不會默默過。
