# 第 6 章 — 串流處理:定量記憶體吃大檔

## 先處決一個淘汰做法:lazy IO

```haskell
readFile :: FilePath -> IO String   -- 惰性讀檔(String 版)
```

看起來優雅:「讀整個檔」但實際按需讀。問題:

1. **關檔時機不可預測**:檔案 handle 被 thunk 抓著,何時讀完何時關,
   誰都說不準 → handle 耗盡、Windows 上檔案鎖住刪不掉。
2. **例外冒出的位置不可預測**:讀檔錯誤在「消費 list 的任何地方」炸開,
   而不是在 `readFile` 那行。

### 來龍去脈:lazy IO 是怎麼來的,又怎麼炸的

Haskell 98 報告裡的 `readFile`、`getContents`、`hGetContents` 全是惰性的。
當年的想法很美:既然 list 是惰性的,「整個檔案的內容」就該是一條
惰性 `String`,程式寫成 `interact (unlines . map process . lines)`
就是一個串流處理器,記憶體 O(1),一行程式碼。

它靠的是 `unsafeInterleaveIO`:把「讀下一塊」的 IO 動作藏進 thunk,
誰強迫 thunk 誰觸發讀檔。IO 的**順序**因此不再由 `do` 區塊決定,
而是由**求值順序**決定 —— 這正是 Haskell 最難預測的東西。親手炸一次:

```haskell
main = do
  h <- openFile "lazy.txt" ReadMode
  contents <- hGetContents h      -- 惰性:此時什麼都還沒讀
  hClose h                        -- 「用完了」先關檔
  putStrLn (take 5 contents)      -- 現在才真的去讀 → 炸
```

```
p6lazy.exe: Uncaught exception ghc-internal:GHC.Internal.IO.Exception.IOException:

lazy.txt: hGetContents: illegal operation (delayed read on closed handle)
```

`delayed read on closed handle`:「延遲的讀取」撞上「已關閉的 handle」。
更陰險的版本是**讀了一半才關**:前面 buffer 裡的內容印得出來,
後面才炸,而且炸在離 `hClose` 很遠的某一行 `putStrLn`。

2008 年 Oleg Kiselyov 用 **iteratee** 正式提出替代方案:
把「資料來源」和「消費者」都做成一等值,由一個明確的驅動迴圈推動,
資源開關回到 IO 的順序裡。之後的每一代串流函式庫都是這個想法的
易用化(見文末)。

這就是 Level 2 說「IO 的邊界要嚴格」的極端案例。
**2026 慣例:lazy IO 不用**,`Data.Text.IO.readFile` 是嚴格的(一次讀完),
小檔案用它就好:

```haskell
ghci> :t Data.Text.IO.readFile
Data.Text.IO.readFile :: FilePath -> IO Text     -- 回來時檔案已經關了
ghci> :t System.IO.hGetContents
hGetContents :: Handle -> IO String              -- 認得它:這是惰性的那個
```

## 大檔案:一次讀完也不行

log 檔 10 GB,`readFile` 直接把記憶體吃爆。我們要的是:
**一次只在記憶體裡放一行**,處理完就丟。模式長這樣:

```haskell
foldLines :: (a -> Text -> a) -> a -> Handle -> IO a
foldLines step = go
  where
    go !acc h = do                    -- !acc:累加器嚴格,不堆 thunk
      eof <- hIsEOF h
      if eof
        then pure acc
        else do
          line <- TIO.hGetLine h      -- 只有這一行在記憶體
          go (step acc line) h
```

這就是 `foldl'` 的 IO 版:嚴格累加器 + 逐塊讀取 = O(1) 記憶體,
檔案多大都一樣。用它可以組出各種分析:

```haskell
countMatching p = withFile' (foldLines (\n l -> if p l then n + 1 else n) 0)
longestLine     = withFile' (foldLines (\m l -> max m (T.length l)) 0)
```

`withFile` 負責「用完一定關檔」(bracket 模式,例外也關)——
資源的生命週期明確,正是 lazy IO 做不到的。

## `bracket`:資源管理的原型

```haskell
ghci> :t bracket
bracket :: IO a -> (a -> IO b) -> (a -> IO c) -> IO c
--         取得      釋放           使用
ghci> :t withFile
withFile :: FilePath -> IOMode -> (Handle -> IO r) -> IO r
```

`bracket acquire release use` 保證:`use` 正常結束**或丟例外**,`release`
都會跑;而且 `release` 期間屏蔽非同步例外,不會被中途打斷。
`withFile path mode body` 大致就是 `bracket (openFile path mode) hClose body`。

自己寫資源管理時照這個形狀:「取得」與「釋放」成對出現在同一個函式裡,
把「使用」當引數傳進來。這就是為什麼 API 都叫 `withXxx`。

## 生態系識讀:streaming 函式庫

手寫 fold 適合「一個來源、一個結果」。當管線變複雜
(多階段轉換、分流、合併、平行),用函式庫:

| 套件 | 定位 |
|------|------|
| `streamly` | 2026 主流:高效能,API 像操作 list |
| `conduit` | 老牌穩定:web/檔案處理生態成熟 |

它們的核心承諾和你手寫的一樣:**定量記憶體 + 確定的資源釋放**,
外加組合子。概念上就是「把 `foldLines` 的迴圈拆成可組合的零件」。

### 演進史:每一代解決了上一代的什麼

| 年代 | 函式庫 | 帶來什麼 | 卡在哪 |
|------|--------|----------|--------|
| 2008 | iteratee(Kiselyov) | 消費者是一等值,資源由驅動迴圈掌控 | API 極難用,型別嚇人 |
| 2010 | enumerator | iteratee 的整理版 | 仍然要理解 enumerator/enumeratee/iteratee 三層 |
| 2012 | conduit(Snoyman)、pipes(Gonzalez) | 「來源 → 轉換 → 匯集」三段式,`.\|` 或 `>->` 串接;資源用 `ResourceT` | 每個元素經過一層 monad 分派,吞吐量有限 |
| 2015 | streaming | 更輕的表示,和 list 更像 | 沒有大生態 |
| 2017 | streamly(Composewell) | 靠 GHC fusion 把管線熔成迴圈,速度接近手寫;API 幾乎等於 list 函式 | 型別/模組拆得細,初學要花時間認路 |

共同點:資料是「一次一塊」流過去,**開關資源的時機在型別/API 裡明確**,
而不是藏在 thunk 裡。`conduit` 在 web 生態(`yesod`、`http-conduit`)
依舊是主力;新的資料處理程式多半直接上 `streamly`。

### `Data.Text.Lazy` 不是串流

`Data.Text.Lazy` 是「一串 chunk 組成的 Text」,適合**在記憶體裡**
逐段建構大文本(例如 `Builder` 產生輸出)。它本身不管 IO;
`Data.Text.Lazy.IO.readFile` 又回到 lazy IO 的老路。
所以:lazy Text 拿來組字串可以,**拿來讀檔不行**。

## 用真套件:streamly-core

手寫 `foldLines` 把「讀下一行」和「拿這行做什麼」綁在同一個迴圈裡。
streaming 函式庫做的事,就是把這個迴圈拆成三種可以獨立組合的零件:

| 零件 | streamly 型別 | 對應 `foldLines` 的哪一段 |
|------|------|------|
| 來源 | `Stream IO Text` | `hIsEOF` + `hGetLine` 的迴圈 |
| 轉換 | `fmap` / `Stream.filter` / `Stream.mapMaybe` | 你塞進 `step` 裡的判斷 |
| 消費 | `Fold IO a b` | 嚴格累加器 `!acc` 與 `step` |

本套件已把 `streamly-core` 加進 `build-depends`
(`streamly-core` 是無並行的核心;`streamly` 套件再加平行組合子)。

```haskell
import Data.Function ((&))
import Streamly.Data.Fold qualified as Fold
import Streamly.Data.Stream (Stream)
import Streamly.Data.Stream qualified as Stream

-- 來源:unfoldrM 每呼叫一次 step 產生一個元素,Nothing 就結束。
-- 一次只有一行在記憶體裡 —— 和 foldLines 的 go 是同一個迴圈。
linesOf :: Handle -> Stream IO Text
linesOf = Stream.unfoldrM step
  where
    step h = do
      eof <- hIsEOF h
      if eof
        then pure Nothing
        else do
          line <- TIO.hGetLine h
          pure (Just (line, h))

-- 管線:來源 & 轉換 & 消費。withFile 仍然負責資源的生命週期。
sumColumnS :: FilePath -> IO Int
sumColumnS path = withFile path ReadMode $ \h ->
  linesOf h
    & Stream.mapMaybe parseCol
    & Stream.fold Fold.sum
```

`&` 是反向套用(`x & f = f x`),讓管線由上往下讀,是 streamly 慣用寫法。

### 為什麼要拆:Fold 可以組合

手寫版要「一趟同時算行數和最長行」,就得自己設計一個雙欄位的嚴格累加器。
streamly 的 `Fold` 是一等值,`Fold.tee` 直接把兩個 Fold 併成一個,
資料仍然只走一趟:

```haskell
lineStats :: FilePath -> IO (Int, Int)
lineStats path = withFile path ReadMode $ \h ->
  linesOf h
    & fmap T.length
    & Stream.fold (Fold.tee Fold.length (Fold.foldl' max 0))
```

`Fold.foldl' max 0` 和 Level 2 的 `foldl'` 是同一個東西,只是被包成可組合的值;
`Fold.sum`、`Fold.length` 也都是嚴格的,不會重演 `foldl` 的 space leak。

### 無限串流

來源不必是檔案。`Stream.enumerateFrom 1` 是無限的,
`Stream.take` 決定要多少,和 Level 2 惰性 list 的 `take 5 [1 ..]` 同一種思維,
但每一步都在 IO 裡、記憶體可控:

```haskell
firstSquaresOver :: Int -> Int -> IO [Int]
firstSquaresOver limit n =
  Stream.enumerateFrom (1 :: Int)
    & fmap (\x -> x * x)
    & Stream.filter (> limit)
    & Stream.take n
    & Stream.toList
```

```haskell
ghci> import Exercises.E09Streamly
ghci> firstSquaresOver 50 3
[64,81,100]
```

### 什麼時候值得引 streamly

- 一個來源、一個結果:手寫 `foldLines` 就好,不要為了三行程式多一個依賴。
- 多階段轉換、要同時算好幾個統計、來源會換(檔案 / socket / 產生器):
  用 streamly,零件可以各自測試、各自替換。
- 要平行處理:`streamly`(非 core)的平行組合子是它 2019 年後成為主流的原因。
- streamly 的極致效能依賴 `-O2` 與 fusion;本課程用預設 `-O1` 就夠,
  習題的五萬行檔案照樣瞬間跑完。

進一步:`streamly-core` 也提供位元組層級的來源與 UTF-8 解碼
(`Streamly.FileSystem.Handle`、`Streamly.Unicode.Stream`),
本章用逐行 `hGetLine` 當來源是為了讓你看清楚「來源」只是一個 `unfoldrM`。

## 你會看到的錯誤訊息

除了上面的 `delayed read on closed handle`,常見的還有:

```
error: [GHC-83865]
    • Couldn't match type ‘[Char]’ with ‘Text’
      Expected: Text
        Actual: String
```

來源幾乎都是混用了 `System.IO` 的 `String` 版函式(`hGetLine`、
`readFile`)和 `Data.Text.IO` 的版本。規則:檔案 IO 一律
`import Data.Text.IO qualified as TIO`,只有 `Handle`、`IOMode`、
`hIsEOF`、`withFile` 這些**不碰內容**的東西才從 `System.IO` 拿。

另外,忘了 `!acc` 不會有錯誤訊息 —— 只有大檔案時的 `+RTS -s`
會告訴你 `maximum residency` 隨檔案大小線性成長。下一章教你看。

## ghci 實驗

```haskell
cabal repl level03-advanced
ghci> import System.IO
ghci> :i IOMode
data IOMode = ReadMode | WriteMode | AppendMode | ReadWriteMode
ghci> :t hIsEOF
hIsEOF :: Handle -> IO Bool
ghci> import Exercises.E06Streaming
ghci> :t foldLines
foldLines :: (a -> Text -> a) -> a -> Handle -> IO a
ghci> withFile "notes/06-streaming.md" ReadMode
        (\h -> hSetEncoding h utf8 >> foldLines (\n _ -> n + 1) (0 :: Int) h)
-- 印出這份教材的行數
```

最後那行的 `hSetEncoding h utf8` 不是裝飾:Windows 的 handle 預設用
console codepage(CP950)解碼,讀 UTF-8 的中文檔案會在第一個非 ASCII 位元組
炸出 `hGetLine: invalid argument (cannot decode byte sequence ...)`。
本課程的測試檔用 `setLocaleEncoding utf8` 一次設定全部;
自己寫工具時記得這件事(Level 1 第 7 章有完整說明)。

## 常見誤區

1. `Prelude.readFile`/`hGetContents` 出現在新程式碼 → 換 `Data.Text.IO`。
2. `openFile` 沒配 `hClose`(或配了但例外時跳過)→ 一律 `withFile`/`bracket`。
3. 累加器忘了 `!` → 記憶體隨檔案大小成長。
4. 拿 `Data.Text.Lazy.IO.readFile` 當串流 → 它就是 lazy IO。
5. 小檔案硬上 streaming 函式庫 → 過度設計,`TIO.readFile` 三行搞定。

## 2026 實務準則

1. 小檔案:`Data.Text.IO.readFile`(嚴格)最簡單,別過度設計。
2. 大檔案 / 未知大小:逐行 fold(本章模式)或 streaming 函式庫。
3. 資源一律 `withFile`/bracket 風格,不裸 `openFile`。
4. 累加器記得 `!`:串流的 space leak 和 `foldl` 是同一種病。

## 習題

`exercises/Exercises/E06Streaming.hs` —— 實作 `foldLines`,
再組出 `countMatching`、`longestLine`、`sumColumn`。
測試會餵幾萬行的檔案,寫成一次讀完也會過,但你會知道差在哪。

接著 `exercises/Exercises/E09Streamly.hs` —— 同樣的任務改用 `streamly-core`:
`linesOf`(來源,`unfoldrM`)、`sumColumnS`(管線)、`lineStats`
(`Fold.tee` 一趟兩個統計)、`firstSquaresOver`(無限串流)。
