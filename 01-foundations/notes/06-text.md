# 第 6 章 — Text:2026 的預設字串型別

## String 已淘汰,原因很簡單

`String = [Char]` —— 字元的 linked list。每個字元一個節點、兩個指標,
記憶體開銷約 20 倍,操作全是 O(n) 遍歷。教學書用它是歷史因素,
**實務程式一律用 `Data.Text`**(緊湊的 UTF-8 陣列)。

`String` 只在跟舊 API 打交道時出現(如 `show`、`getArgs`),
拿到就立刻 `T.pack` 成 `Text`。

### 為什麼 Haskell 98 會選 `[Char]`

1990 年代設計 Haskell 時,語言的核心賣點是「list 是萬用結構,
`map`/`filter`/pattern matching 全部通用」。把字串定義成 `[Char]` 意味著
所有 list 函式免費適用於字串、字串可以惰性地無限長、pattern match 可以直接拆第一個字元。
對一個研究型語言這是漂亮的選擇;對要處理 MB 級文字的程式,
一個字元 40 bytes(64 位元機器上一個 cons 節點加一個 boxed `Char`)是災難。

修補的歷史:

- **`bytestring`**(2005):先解決「位元組陣列」,但它不是文字。
- **`text`**(2009):真正的 Unicode 文字型別,內部用 UTF-16。
- **`text` 2.0**(2021):內部改成 **UTF-8**,和檔案、網路、其他語言零轉換,
  `T.length` 之類要走完全部位元組的操作也因此更快。這是 2026 你用的版本。
- `String` 沒有被移除:`show`、`read`、`getArgs`、`error` 訊息、`FilePath`……
  base 裡太多 API 用它,移除會砸掉整個生態系。所以它會一直在**邊界**出現,
  策略是「進來就 `T.pack`,出去才 `T.unpack`」。

## 標準 import 樣板

```haskell
import Data.Text (Text)
import Data.Text qualified as T     -- GHC2024 的 import 後置寫法
```

慣例:型別 `Text` 直接用,函式都掛 `T.` 前綴(因為 `T.length`、`T.map`
會跟 Prelude 的同名函式相撞)。

## OverloadedStrings

字串字面值預設是 `String`。開了 `OverloadedStrings`(本專案已在 cabal 全域開啟)
之後,字面值變成多載的,可以直接當 `Text` 用:

```haskell
greeting :: Text
greeting = "你好,冒險者"
```

```haskell
ghci> :set -XOverloadedStrings
ghci> :t "hello"
"hello" :: IsString a => a          -- 跟數字字面值的 Num a => a 一樣的機制
```

原理和第 1 章的數字字面值完全相同:`"hello"` 變成 `fromString "hello"`,
`IsString` 是一個 class,`Text`、`String`、`ByteString` 都有 instance,由上下文決定要哪個。

### 代價:歧義

多載的代價也和數字一樣 —— 上下文不夠時,GHC 猜不出你要哪個:

```haskell
main = print (length "abc")       -- 開了 OverloadedStrings
```

```
Ch6.hs:3:15: error: [GHC-39999]
    • Ambiguous type variable ‘t0’ arising from a use of ‘length’
      prevents the constraint ‘(Foldable t0)’ from being solved.
      Probable fix: use a type annotation to specify what ‘t0’ should be.
```

`length` 接受任何 `Foldable`,`"abc"` 可以是任何 `IsString` —— 兩邊都不肯先決定。
修法:用 `T.length "abc"`(函式本身固定了型別),或標註 `length ("abc" :: String)`。
慣例上你不會遇到太多次:只要函式來自 `T.`,型別就定了。

另一個更常見的:把 `Text` 交給只吃 `String` 的舊 API。

```haskell
greeting :: Text
main = putStrLn greeting
```

```
Ch6b.hs:6:17: error: [GHC-83865]
    • Couldn't match type ‘Text’ with ‘[Char]’
      Expected: String
        Actual: Text
```

`Expected`/`Actual` 是這類錯誤最重要的兩行:函式**要** `String`,你**給** `Text`。
修法:用 `Data.Text.IO` 的 `TIO.putStrLn`(第 7 章),不要 `T.unpack` 硬轉。
反方向的 `Couldn't match type ‘[Char]’ with ‘Text’` 則是你在沒開 `OverloadedStrings`
的檔案裡把字面值當 `Text` 用。

## 常用 API

```haskell
T.toUpper / T.toLower          -- 大小寫
T.strip                        -- 去頭尾空白
T.words / T.unwords            -- 依空白切開 / 接回
T.lines / T.unlines            -- 依換行切開 / 接回
T.splitOn "," / T.intercalate ","
T.breakOn "="                  -- 切成 (前, 含分隔的後)
T.filter / T.map / T.length
T.isPrefixOf / T.isInfixOf
(<>)                           -- 串接(就是 Semigroup!)
T.pack / T.unpack              -- String <-> Text
```

數字轉 Text 的固定套路:

```haskell
tshow :: Show a => a -> Text
tshow = T.pack . show
```

`show` 回 `String` 是歷史包袱(見上),所以 `tshow` 這個小函式幾乎每個專案都會自己寫一份。

## ghci 實驗

```haskell
ghci> :set -XOverloadedStrings
ghci> import Data.Text qualified as T
ghci> T.words "slime  bat\tdragon"        -- 連續空白、tab 都當分隔
["slime","bat","dragon"]
ghci> T.splitOn "," "a,b,,c"              -- 空欄位保留
["a","b","","c"]
ghci> T.breakOn "=" "hp=100"              -- 分隔符留在右半
("hp","=100")
ghci> T.length "你好"
2                                          -- 算字元不算 bytes(UTF-8 下是 6 bytes)
```

## Map:順便認識鍵值容器

字數統計這類任務需要 `Data.Map.Strict`(**預設用 Strict 版**,
惰性版的 value 會堆 thunk):

```haskell
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

wordFreq :: Text -> Map Text Int
wordFreq t = Map.fromListWith (+) [(w, 1) | w <- T.words t]
```

`Map.fromListWith f` 和 `Map.fromList` 差在**遇到重複的 key 怎麼辦**:
`fromList` 是後者覆蓋前者,`fromListWith (+)` 是把兩個 value 用 `(+)` 合併。
所以每個單字先配一個 `1`,重複出現就加起來,結果就是詞頻:

```haskell
ghci> Map.fromListWith (+) [("axe",1),("bow",1),("axe",1)]
fromList [("axe",2),("bow",1)]
ghci> Map.fromList [("axe",1),("bow",1),("axe",1)]
fromList [("axe",1),("bow",1)]           -- 沒有 With:後面的蓋掉前面的
```

`Map.lookup :: k -> Map k v -> Maybe v` —— 又是 `Maybe`,查不到不會爆炸:

```haskell
ghci> Map.lookup "axe" (Map.fromList [("axe", 2)])
Just 2
ghci> Map.lookup "sword" (Map.fromList [("axe", 2)])
Nothing
```

`Map` 的 key 需要 `Ord`(它是平衡二元搜尋樹),這就是第 5 章 `deriving stock (Ord)` 的用途之一。

## 補充:lazy Text 與 ByteString

| 型別 | 是什麼 | 什麼時候用 |
|------|------|------|
| `Data.Text` (strict) | 一塊連續的 UTF-8 文字 | **預設**。設定、訊息、名字、解析結果 |
| `Data.Text.Lazy` | 一串 chunk 組成的惰性文字 | 產生很大的輸出(如 template 渲染)時串接省記憶體;第 3 級 streaming 再談 |
| `Data.ByteString` | 原始位元組,沒有編碼概念 | 檔案的原始內容、網路封包、二進位格式 |
| `String` | `[Char]` | 只在跟 base 舊 API 交界處出現 |

`Text` 是「文字」、`ByteString` 是「位元組」,概念不同,別混用:
`ByteString` 變 `Text` 必須經過**解碼**(`decodeUtf8`),而且可能失敗;
反過來要**編碼**(`encodeUtf8`)。第 7 章的 Windows 編碼問題就是這條界線出的事。

## 常見誤區

1. 用 `T.unpack` 轉成 `String` 去用 list 函式再 `T.pack` 回來 → 先查 `T.` 有沒有同名函式,幾乎都有。
2. `length "abc"` 在 `OverloadedStrings` 下歧義 → 用 `T.length`。
3. `putStrLn` 餵 `Text` → 用 `Data.Text.IO` 的版本。
4. `Map.fromList` 建詞頻表 → 重複 key 會被覆蓋,要 `fromListWith (+)`。
5. 把 `Text` 當 list 做 pattern match(`(c : cs)`)→ 編不過;用 `T.uncons`。

## 2026 實務準則

1. 字串一律 `Text`;`String` 只在邊界,進來就 `T.pack`。
2. `OverloadedStrings` 全專案開,歧義時用 `T.` 函式固定型別。
3. 鍵值容器用 `Data.Map.Strict`,不用 `Data.Map`(惰性版)。
4. 位元組和文字分清楚,轉換必經 `encodeUtf8`/`decodeUtf8`。

## 習題

`exercises/Exercises/E06Text.hs` → `cabal test level01-foundations`
