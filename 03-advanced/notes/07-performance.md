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

## 讀懂 `+RTS -s`:一份真實輸出

拿最經典的洩漏案例跑一次(`-O0`,先不讓最佳化器插手):

```haskell
main = print (foldl (+) 0 [1 .. 10_000_000 :: Int])
```

```
   1,612,381,688 bytes allocated in the heap
   2,430,802,048 bytes copied during GC
     619,451,992 bytes maximum residency (9 sample(s))
            1159 MiB total memory in use (0 MiB lost due to fragmentation)

  MUT     time    0.219s  (  0.174s elapsed)
  GC      time    0.750s  (  1.093s elapsed)
  Total   time    0.969s  (  1.267s elapsed)

  Productivity  22.6% of total user, 13.7% of total elapsed
```

逐行讀:

- **bytes allocated in the heap**:整個執行期間**總共**配置了多少。
  Haskell 程式這個數字天生很大(每個 thunk、每個 box 都算),
  1.6 GB 本身不是問題,要看下面。
- **bytes copied during GC**:GC 搬了多少東西。copying GC 只搬**活著的**
  資料,所以這個數字大 = 有很多東西一直活著 = 洩漏的徵兆。
- **maximum residency**:某一時刻活著的資料最多有多少。**這是抓 space leak
  的關鍵數字**。619 MB 對一個「加總一千萬個數字」的程式,就是那座 thunk 山。
- **total memory in use**:向作業系統要了多少(residency 的兩倍左右是正常的,
  copying GC 需要空間搬家)。
- **MUT / GC time**:mutator(你的程式)vs 垃圾回收各花多少。
  這裡 GC 是 MUT 的三倍多。
- **Productivity**:MUT 佔總時間的比例。22.6% 意思是**四分之三的時間在收垃圾**。

同一支程式換成 `foldl'`:

```
     880,081,400 bytes allocated in the heap
          16,472 bytes copied during GC
          42,920 bytes maximum residency (2 sample(s))
               6 MiB total memory in use (0 MiB lost due to fragmentation)

  MUT     time    0.031s  (  0.036s elapsed)
  GC      time    0.000s  (  0.001s elapsed)
  Productivity 100.0% of total user, 95.3% of total elapsed
```

residency 從 619 MB 掉到 42 KB,總時間快 30 倍。
**先看 residency,再看 productivity**,兩個都正常再談演算法。

(順帶一提:同一支 `foldl` 程式開 `-O1` 之後 residency 也只有 42 KB ——
GHC 的 strictness analysis 看出累加器一定會被用到,自動加了嚴格。
但**不要**指望這件事:下面的 tuple 累加器案例,`-O1` 就救不回來。)

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

### 為什麼 tuple 會漏:實測

```haskell
sumAndLength = foldl' (\(s, n) x -> (s + x, n + 1)) (0, 0)   -- 五百萬個元素
```

| | maximum residency | total memory | Total time |
|--|--|--|--|
| tuple 累加器 `-O0` | 366 MB | 803 MiB | 0.78 s |
| tuple 累加器 `-O1` | 200 MB | 397 MiB | 0.30 s |
| `SL` 嚴格型別 `-O1` | 42 KB | 6 MiB | 0.01 s |

`foldl'` 每步只把累加器求值到 **WHNF**:對 tuple 來說就是「確定它是一個
`(,)`」,裡面的 `s + x` 和 `n + 1` 仍是 thunk,一步一層堆上去。
`-O1` 有幫忙但沒解決。`!Int` 欄位讓「求值到 WHNF」順便把欄位也算掉,
問題消失。這是**資料型別設計**的事,不是最佳化器的事。

### 來龍去脈:為什麼 tuple 和 record 欄位預設惰性

Haskell 是惰性語言,「欄位不求值」是預設一致性的結果:
`data Pair = Pair Int Int` 的欄位和函式引數一樣都是 thunk。
1990 年代這是刻意的,讓 `let (a, b) = expensive in a` 只算 `a`。
實務二十年下來的結論是:**長壽的資料**(累加器、狀態、容器裡的值)
幾乎永遠應該嚴格,惰性只在控制流有價值。所以 2026 慣例是
`StrictData`(或手動 `!`)當預設,需要惰性的欄位再用 `~` 標回來。
tuple 是標準庫的型別,改不了,所以**累加器不用 tuple**。

## 三板斧之二:嚴格容器 + 對的資料結構

```haskell
import Data.Map.Strict qualified as Map   -- 不是 Data.Map.Lazy!

histogram :: [Text] -> Map.Map Text Int
histogram = foldl' (\m w -> Map.insertWith (+) w 1 m) Map.empty
```

lazy Map 的值欄位會堆 `1+1+1+...` 的 thunk 鏈,strict Map 每次插入就算。
實測(兩百萬次 `insertWith`,10 個 key,`-O1`):

| | maximum residency | Total time | Productivity |
|--|--|--|--|
| `Data.Map`(= Lazy) | 79 MB | 0.20 s | 46% |
| `Data.Map.Strict` | 42 KB | 0.00 s | 100% |

只有 10 個 key,卻有 79 MB 活著 —— 每個 key 底下掛著二十萬層的 `(+) 1` thunk。
這個案例 `-O1` 完全救不了,因為最佳化器看不穿 `Map` 內部。

### 來龍去脈:為什麼 `Data.Map` 預設是 lazy

`containers` 是 2000 年代初的函式庫,那時「值欄位惰性」還是整個生態的
預設。`Data.Map.Strict` 直到 2011 年才加進來,為了向後相容,
`Data.Map` 這個名字繼續指向 lazy 版。所以**引用 Map 永遠寫全名**
`Data.Map.Strict`;`Data.IntMap.Strict`、`Data.HashMap.Strict` 同理。
看到裸的 `import Data.Map`,就是舊程式碼或還沒被咬過的人。

選型速查:隨機查找 `Map`/`HashMap`、整數鍵 `IntMap`、
數值大陣列 `vector`(unboxed 版 `Data.Vector.Unboxed` 最快)、
字串一律 `Text`。

### Boxed 與 unboxed:`Int` 裡面是什麼

```haskell
ghci> :i Int
data Int = I# Int#          -- Int 是一個指標,指向裝著 Int# 的盒子
```

`Int#`(讀作 "int magic hash")是 CPU 真正的 64 位元整數;
`Int` 是把它裝進 heap 上一個盒子的**指標**。惰性需要盒子(thunk 也是一種盒子),
但數值運算時盒子是純開銷。`Data.Vector.Unboxed` 之所以快,就是把一百萬個
`Int#` 排成連續記憶體,沒有一百萬個指標。你平常不寫 `Int#`,
但 `!Int` 欄位 + `-O1` 會讓 GHC 自動把盒子拆掉(unboxing),
這也是嚴格欄位快的第二個原因。

## 三板斧之三:讓 fusion 幫你消掉中間 list

```haskell
sumSquaresEven :: Int -> Int
sumSquaresEven n = foldl' (+) 0 [x * x | x <- [1 .. n], even x]
```

看起來會生出一條百萬元素的 list?開 `-O1`(cabal 預設)後 GHC 的
**list fusion** 把「產生 → 過濾 → 映射 → 摺疊」熔成一個迴圈,
不配置任何 list。條件:管線用標準組合子(map/filter/fold/枚舉),
中間結果不要另外命名共享。寫管線風格,讓最佳化器工作。

實測(n = 五千萬):

| | bytes allocated | Total time |
|--|--|--|
| `-O0` | 13,200,081,632 | 1.05 s |
| `-O1` | 81,416 | 0.02 s |
| `-O2` | 81,416 | 0.02 s |

`-O0` 配置了 13 GB(整條 list 真的生出來又丟掉),`-O1` 只配置 81 KB
(RTS 啟動的固定開銷),差六十倍。**而 `-O2` 和 `-O1` 一模一樣。**

### 來龍去脈:`-O2` 迷信

`-O1` 開的是 GHC 幾乎所有的重要最佳化:inlining、strictness analysis、
fusion、worker/wrapper、unboxing。`-O2` 額外開的是幾個**編譯很慢、
收益看情況**的 pass(`-fspec-constr`、`-fliberate-case` 等,主要幫助
遞迴函式的特化)。2010 年代的 benchmark 文章動不動就 `-O2`,
養成了「效能 = -O2」的直覺;實務上先用 `-O1` 量,只有 profiling 指出
某個熱點在 `-O2` 下明顯變快,才針對**那個套件**開。

## Profiling:找到熱點在哪

```powershell
cabal run app --enable-profiling -- +RTS -p     # 產生 app.prof
```

(裸 `ghc` 的話是 `ghc -prof -fprof-auto -rtsopts`。)
`.prof` 檔的開頭是總覽,再來是**依成本排序的 cost centre 表**:

```
	total time  =        0.01 secs   (10 ticks @ 1000 us, 1 processor)
	total alloc = 1,107,811,064 bytes  (excludes profiling overheads)

COST CENTRE  MODULE           SRC                    %time %alloc

histogram.\  Main             P7Prof.hs:6:29-52       70.0   81.2
main         Main             P7Prof.hs:(12,1)-(14,34) 30.0   15.9
$fNumInt_$c+ GHC.Internal.Num ...                      0.0    2.9
```

- **COST CENTRE**:`-fprof-auto` 幫每個頂層(和局部)定義插的計數點;
  `histogram.\` 是 `histogram` 裡的那個 lambda。
- **SRC**:精確到行:欄,直接跳過去。
- **%time / %alloc**:時間與配置的**百分比**。先看 `%alloc` ——
  在 Haskell 裡「配置多」和「慢」高度相關,而且配置數字比 tick 穩定
  (這份只跑了 10 個 tick,時間百分比很粗)。

表下面是**呼叫樹**(inherited 欄位含子孫的成本),用來回答
「這個函式慢,是它自己慢還是它呼叫的東西慢」。

注意:profiling 版本會關掉一部分最佳化(尤其 fusion),
數字是**相對**參考,絕對值別拿去比。

## 微調工具:一句話定位

- `{-# INLINE f #-}`:強迫把 `f` 展開到呼叫處;小函式、
  想讓 fusion 穿過去的組合子才用。
- `{-# SPECIALIZE f :: Int -> Int #-}`:為多型函式生一個單型版本,
  去掉 typeclass 字典的間接呼叫;數值密集的泛型碼才用。
- `-fllvm`:用 LLVM 後端,數值迴圈偶爾快 10–20%,需要另裝 LLVM。

三者都是「profiling 指到了才動」的工具,不是預設姿勢。

## 常見洩漏清單(照著檢查)

1. `foldl` → 改 `foldl'`;累加器 tuple → 改嚴格型別。
2. 長壽 record 的欄位沒加 `!` → `StrictData`。
3. `Data.Map` 忘了 `.Strict`;`modifyTVar` 忘了 `'`。
4. 大 list 被兩個消費者共享(list 頭被抓住,整條進不了 GC)。

## ghci 實驗

ghci 不做最佳化,但可以看 thunk:

```haskell
ghci> let x = 1 + 2 :: Int
ghci> :sprint x            -- 印出「目前算到哪」,不強迫求值
x = _                      -- _ = 還是 thunk
ghci> x
3
ghci> :sprint x
x = 3                      -- 被算過了
ghci> :set +s              -- 之後每個運算式印時間與配置
ghci> foldl (+) 0 [1 .. 10^6]
```

`:sprint` 是理解「什麼時候被算」最直接的工具;`:set +s` 是最便宜的 benchmark。

## 常見誤區

1. 沒量就改 → 通常改錯地方。
2. 看到 `bytes allocated` 很大就慌 → 看 residency 和 productivity。
3. 靠 `-O1` 修 space leak → 有時行(單一累加器),有時不行(tuple、Map),
   資料型別要自己寫嚴格。
4. 一開始就 `-O2` → 編譯變慢,多數情況零收益。
5. 拿 profiling build 的絕對時間當結論 → 只看相對比例。

## 2026 實務準則

1. 順序:量測 → 修洩漏 → 換演算法/資料結構 → 微調。倒著做 = 白工。
2. `-O1` 是 cabal 預設,別急著上 `-O2`(編譯慢很多,收益常有限)。
3. benchmark 用 `tasty-bench` 起步,要統計嚴謹再上 `criterion`。
4. residency 隨輸入線性成長 = 洩漏;先找累加器、容器、record 欄位。

## 習題

`exercises/Exercises/E07Performance.hs` —— `sumAndLength`(嚴格單趟)、
`histogram`(嚴格 Map)、`sumSquaresEven`(fusion 管線)。
測試餵百萬級輸入,寫出洩漏版會明顯變慢(甚至爆記憶體)。
