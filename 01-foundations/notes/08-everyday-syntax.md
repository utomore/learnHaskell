# 第 8 章 — 日常語法:TypeApplications、readMaybe、`\case`、NonEmpty

> 前七章的觀念已經夠寫程式了。這章補的是**每天都會寫、讀任何開源碼
> 都會撞到**的四樣語法,它們各自取代了一個 Haskell 98 時代的舊寫法。
> 讀完你會發現前幾章的「淘汰品警告」全部有了正解。

## TypeApplications:直接告訴編譯器型別

### 問題:型別推不出來的時候

```haskell
ghci> read "3"
*** Exception: Prelude.read: no parse
```

`read :: Read a => String -> a`,結果型別 `a` 完全由**呼叫端**決定。
ghci 推不出你要什麼,就用它的預設規則猜了一個(`()`),當然解析失敗。
Haskell 98 的解法是型別註記:

```haskell
ghci> (read "3" :: Int)
3
```

能用,但註記的是「整個運算式的型別」。當你要指定的型別變數
**不是結果型別**(例如 `fromIntegral` 的輸入),註記就得寫得很彆扭。

### 新做法:`@` 直接填型別變數

```haskell
ghci> read @Int "3"
3
ghci> maxBound @Int
9223372036854775807
ghci> fromIntegral @Int @Double 3
3.0
```

`@Int` 填的是簽名裡 `forall` 的第一個型別變數,依序往後填。
`fromIntegral :: (Integral a, Num b) => a -> b`,所以 `@Int @Double`
就是「a 是 Int、b 是 Double」。開 `-fprint-explicit-foralls` 之後,
`:t` 會把 `forall` 印出來,型別變數的順序一目瞭然:

```haskell
ghci> :set -fprint-explicit-foralls
ghci> :t fromIntegral
fromIntegral :: forall a b. (Integral a, Num b) => a -> b
```

### 來龍去脈

- **舊做法**:型別註記 `(x :: T)`,或者更醜的 `Proxy` 技巧
  (定義一個沒有值的 `Proxy :: Proxy Int` 當「型別載體」傳進去)。
- **為什麼會這樣**:Haskell 98 的型別參數是「看不見的」——編譯器自動推斷,
  語言沒有語法讓你手動填。多數情況推斷得出來,設計者覺得夠了。
- **出了什麼問題**:typeclass 越用越多之後,「結果型別由呼叫端決定」的函式
  到處都是(`read`、`mempty`、`minBound`、`fromIntegral`、`decode`……),
  註記與 Proxy 讓程式碼變得很吵。
- **新做法**:`TypeApplications`(GHC 8.0,2016 年)讓你用 `@T` 顯式填入,
  進了 GHC2021 之後不用再開擴充。
- **哪裡還會看到舊寫法**:結果型別就是你要指定的那個時,`(x :: Int)` 仍然常見、
  也沒有錯;`Proxy` 在型別層級程式設計裡還有用途(Level 3 會遇到)。

## `read` 淘汰,`readMaybe` 上位

`read` 是 **partial function**:解析失敗直接炸,和第 2 章的 `head []` 同一類。
玩家在指令列打錯一個字,遊戲就當掉,這不能接受。

```haskell
import Text.Read (readMaybe)

readMaybe :: Read a => String -> Maybe a
```

```haskell
ghci> readMaybe @Int "12"
Just 12
ghci> readMaybe @Int "12x"
Nothing
ghci> readMaybe @Double "1e3"
Just 1000.0
```

失敗變成 `Nothing`,呼叫端被型別逼著處理。搭配 `Text`:

```haskell
parseInt :: Text -> Maybe Int
parseInt = readMaybe @Int . T.unpack . T.strip
```

### 來龍去脈

- **舊做法**:Haskell 98 的 `Read` class 只給 `read` 和 `reads`。
  想安全解析要手寫 `case reads s of [(n, "")] -> Just n; _ -> Nothing`,
  這個片段在 2012 年以前的程式碼裡到處都是。
- **新做法**:`readMaybe`(與 `readEither`)在 base 4.6(GHC 7.6,2012 年)
  進了 `Text.Read`。它就是把上面那段 `reads` 樣板包起來。
- **哪裡還會看到 `read`**:測試碼、一次性腳本、確定輸入來自自己程式的地方。
  面對使用者輸入或檔案內容,一律 `readMaybe`。
- **要解析更複雜的格式**:`Data.Text.Read`(`decimal`、`double`,Level 3 會用)
  或 parser 函式庫(`megaparsec`)。`Read` 的格式是「Haskell 語法」,
  不是設計給人類輸入的。

## `\case`:對唯一引數做 case

```haskell
describePower :: Int -> Text
describePower = \case
  n
    | n >= 100 -> "傳說"
    | n >= 50 -> "強敵"
    | otherwise -> "雜魚"
```

`\case` 等於 `\x -> case x of`,省掉一個只為了拿來 case 的變數名。
分支裡照樣可以用 guard。第 4 章的 `describeMonster` 就是這樣寫的。

### 來龍去脈

- **舊做法**:`f x = case x of ...`,或者多條等式 `f (Just n) = ...; f Nothing = ...`。
  多條等式很好,但當函式是「先做點事再 case」或者要當引數傳進 `map` 時,
  就得幫那個引數取名字。
- **新做法**:`LambdaCase`(GHC 7.6,2012 年)。它**不在 GHC2021**,
  但進了 **GHC2024** —— 本專案用 GHC2024,所以直接寫。
  在 GHC2021 專案裡寫 `\case` 會看到
  `Perhaps you intended to use the ‘LambdaCase’ extension`。
- **延伸**:GHC 9.4 起有 `\cases`,一次比對多個引數(Level 3 第 8 章)。

## NonEmpty:把「非空」寫進型別

### 問題:`head` 為什麼不能用

```haskell
ghci> head []
*** Exception: Prelude.head: empty list
```

GHC 9.8 起,`-Wall` 會對每個 `head`/`tail` 發警告:

```
warning: [GHC-63394] [-Wx-partial]
    In the use of ‘head’
    (imported from Prelude, but defined in GHC.Internal.List):
    "This is a partial function, it throws an error on empty lists.
     Use pattern matching, 'Data.List.uncons' or 'Data.Maybe.listToMaybe'
     instead. Consider refactoring to use "Data.List.NonEmpty"."
```

警告最後一句就是本節:**如果你的邏輯需要「至少一個」,就用一個
本來就不可能為空的型別**。

```haskell
import Data.List.NonEmpty (NonEmpty (..), nonEmpty)
import Data.List.NonEmpty qualified as NE

data NonEmpty a = a :| [a]        -- 第一個元素 :| 剩下的 list

nonEmpty  :: [a] -> Maybe (NonEmpty a)   -- 唯一的入口:空 list 給 Nothing
NE.head   :: NonEmpty a -> a             -- total!不可能炸
NE.toList :: NonEmpty a -> [a]
```

```haskell
ghci> nonEmpty [3, 1, 2]
Just (3 :| [1,2])
ghci> nonEmpty []
Nothing
ghci> NE.head (3 :| [1, 2])
3
ghci> NE.toList (NE.sort (3 :| [1, 2]))
[1,2,3]
```

### 模式:邊界驗一次,裡面全部 total

```haskell
-- 隊伍至少要有一個人,這個不變量寫在型別上
strongest :: NonEmpty Monster -> Monster
strongest = maximumBy (comparing (.power))    -- 不需要 Maybe

-- 只有在「從外面的 list 進來」的邊界才處理空的情況
partyLeader :: [Monster] -> Maybe Monster
partyLeader = fmap strongest . nonEmpty
```

`Maybe` 只出現在邊界一次。內部所有函式都拿 `NonEmpty`,
不必每一層都 `case` 一次「萬一是空的」。這和第 7 章「純核心、薄 IO 殼」
是同一個思想:**把檢查推到邊界,核心保持乾淨**。

### 來龍去脈

- **舊做法**:`head`/`tail`/`maximum`/`foldr1` 這些 partial function
  在 Prelude 裡待了三十年;大家「知道要小心」,然後持續在生產環境炸。
- **為什麼會這樣**:Haskell 98 沒有 `NonEmpty`;list 是唯一的序列型別,
  「非空」這個不變量沒有地方放。
- **新做法**:`NonEmpty` 原本住在 Edward Kmett 的 `semigroups` 套件,
  base 4.9(GHC 8.0,2016 年)把它收進 `Data.List.NonEmpty`。
  動機之一是 `Semigroup` 的 `sconcat :: NonEmpty a -> a` 需要它
  (沒有 `mempty` 的型別只能合併非空序列)。
  GHC 9.8(2023 年)再加上 `-Wx-partial`,把「不要用 `head`」從口頭叮嚀
  變成編譯器警告。
- **哪裡還會看到 `head`**:大量舊教材與舊函式庫。讀到時在心裡翻譯成
  「這裡有一個沒寫進型別的前提」。

## `Data.Maybe` / `Data.Either` 工具箱

用了 `Maybe` 之後,你會一直寫同樣的 `case`。這些函式把常見形狀包好了:

| 函式 | 型別 | 用途 |
|------|------|------|
| `fromMaybe` | `a -> Maybe a -> a` | 給預設值 |
| `maybe` | `b -> (a -> b) -> Maybe a -> b` | 兩個分支一次寫完 |
| `mapMaybe` | `(a -> Maybe b) -> [a] -> [b]` | 轉換 + 丟掉失敗的 |
| `catMaybes` | `[Maybe a] -> [a]` | 丟掉 `Nothing` |
| `listToMaybe` | `[a] -> Maybe a` | 安全版 `head` |
| `either` | `(e -> c) -> (a -> c) -> Either e a -> c` | `Either` 的 `maybe` |
| `partitionEithers` | `[Either e a] -> ([e], [a])` | 錯誤與成功分開收 |

```haskell
parseAll :: [Text] -> [Int]
parseAll = mapMaybe parseInt      -- ["1", "x", "3"] → [1, 3]
```

順便認識 `Data.Ord` 的 `comparing`(上面 `strongest` 用過)與 `Down`
(反向排序:`sortOn (Down . (.power))`)。

## 你會看到的錯誤訊息

忘了 `@Int`,又沒有任何上下文能推出型別:

```
error: [GHC-39999]
    • Ambiguous type variable ‘a0’ arising from a use of ‘print’
      prevents the constraint ‘(Show a0)’ from being solved.
      Probable fix: use a type annotation to specify what ‘a0’ should be.
      Potentially matching instances:
        instance Show Ordering -- Defined in ‘GHC.Internal.Show’
        instance Show Integer -- Defined in ‘GHC.Internal.Show’
        ...plus 25 others
    • In the expression: print (readMaybe "3")
```

怎麼讀:「`a0` 是誰?」——`readMaybe "3"` 的結果型別沒人指定,
`print` 只要求它有 `Show`,候選有 27 個。**Probable fix 那行就是答案**:
補 `@Int`,或者讓結果流進一個型別確定的地方(例如 `Move <$> parseInt n`,
`Move` 的欄位是 `Int`,型別就推得出來)。

## ghci 實驗

```haskell
cabal repl level01-foundations
ghci> import Text.Read (readMaybe)
ghci> import Data.List.NonEmpty (nonEmpty)
ghci> :set -fprint-explicit-foralls
ghci> :t readMaybe
readMaybe :: forall a. Read a => String -> Maybe a
ghci> readMaybe @Int "  7"
Just 7                          -- Read 會吃前導空白,但不吃尾端垃圾
ghci> readMaybe @Int "7 "
Just 7
ghci> readMaybe @Int "7x"
Nothing
ghci> nonEmpty "abc"
Just ('a' :| "bc")              -- String 也是 list,所以也能用
```

## 常見誤區

1. `read` 出現在處理使用者輸入的路徑上 → 換 `readMaybe`。
2. 為了避開 `head`,寫 `case xs of (x : _) -> ...; [] -> error "impossible"`
   → 這只是把 partial 藏起來。真的「不可能為空」就改成收 `NonEmpty`。
3. `@` 填錯順序:`fromIntegral @Double @Int` 是「Double 進、Int 出」。
   用 `-fprint-explicit-foralls` 看 `forall` 的順序。
4. `mapMaybe` 默默丟掉失敗 —— 適合「壞的就跳過」的場景;
   需要知道哪些壞了,用 `partitionEithers` 收錯誤。
5. `NonEmpty` 到處傳但只在一個地方 `nonEmpty` → 對,這就是設計:
   邊界一次,內部 total。

## 2026 實務準則

1. 指定型別用 `@T`;結果型別就是目標時 `(x :: T)` 也可以。
2. 使用者輸入一律 `readMaybe`;`read` 只留給測試與自家格式。
3. 「對唯一引數做 case」寫 `\case`。
4. 「至少一個」的不變量用 `NonEmpty` 表達,`Maybe` 只留在邊界。
5. 常見的 `Maybe`/`Either` 形狀先查 `Data.Maybe`/`Data.Either`,不要手寫 `case`。

## 習題

`exercises/Exercises/E08Everyday.hs` → `cabal test level01-foundations`

`parseInt`(readMaybe + `@Int`)、`parseCommand`(對 `T.words` 做 case)、
`strongest`/`partyLeader`(NonEmpty 邊界模式)、`parseAll`(`mapMaybe`)、
`describePower`(`\case` + guard)。
