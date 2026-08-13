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

這就是 Level 2 說「IO 的邊界要嚴格」的極端案例。
**2026 慣例:lazy IO 不用**,`Data.Text.IO.readFile` 是嚴格的(一次讀完),
小檔案用它就好。

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

## 生態系識讀:streaming 函式庫

手寫 fold 適合「一個來源、一個結果」。當管線變複雜
(多階段轉換、分流、合併、平行),用函式庫:

| 套件 | 定位 |
|------|------|
| `streamly` | 2026 主流:高效能,API 像操作 list |
| `conduit` | 老牌穩定:web/檔案處理生態成熟 |

它們的核心承諾和你手寫的一樣:**定量記憶體 + 確定的資源釋放**,
外加組合子。概念上就是「把 `foldLines` 的迴圈拆成可組合的零件」。

## 2026 實務準則

1. 小檔案:`Data.Text.IO.readFile`(嚴格)最簡單,別過度設計。
2. 大檔案 / 未知大小:逐行 fold(本章模式)或 streaming 函式庫。
3. 資源一律 `withFile`/bracket 風格,不裸 `openFile`。
4. 累加器記得 `!`:串流的 space leak 和 `foldl` 是同一種病。

## 習題

`exercises/Exercises/E06Streaming.hs` —— 實作 `foldLines`,
再組出 `countMatching`、`longestLine`、`sumColumn`。
測試會餵幾萬行的檔案,寫成一次讀完也會過,但你會知道差在哪。
