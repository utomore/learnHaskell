# 第 6 章 — Text:2026 的預設字串型別

## String 已淘汰,原因很簡單

`String = [Char]` —— 字元的 linked list。每個字元一個節點、兩個指標,
記憶體開銷約 20 倍,操作全是 O(n) 遍歷。教學書用它是歷史因素,
**實務程式一律用 `Data.Text`**(緊湊的 UTF-8 陣列)。

`String` 只在跟舊 API 打交道時出現(如 `show`、`getArgs`),
拿到就立刻 `T.pack` 成 `Text`。

## 標準 import 樣板

```haskell
import Data.Text (Text)
import Data.Text qualified as T     -- GHC2024 的 import 後置寫法
```

慣例:型別 `Text` 直接用,函式都掛 `T.` 前綴(因為 `T.length`、`T.map`
會跟 Prelude 的同名函式相撞)。

## OverloadedStrings

字串字面值預設是 `String`。開了 `OverloadedStrings`(本專案已全域開啟)
之後,字面值變成多載的,可以直接當 `Text` 用:

```haskell
greeting :: Text
greeting = "你好,冒險者"
```

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

## Map:順便認識鍵值容器

字數統計這類任務需要 `Data.Map.Strict`(**預設用 Strict 版**,
惰性版的 value 會堆 thunk):

```haskell
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

wordFreq :: Text -> Map Text Int
wordFreq t = Map.fromListWith (+) [(w, 1) | w <- T.words t]
```

`Map.lookup :: k -> Map k v -> Maybe v` —— 又是 `Maybe`,查不到不會爆炸。

## 補充:lazy Text 與 ByteString

- `Data.Text.Lazy`:串流式大文本用,之後 streaming 章節再談。
- `ByteString`:位元組(檔案的原始內容、網路封包)。`Text` 是「文字」、
  `ByteString` 是「位元組」,概念不同,別混用。

## 習題

`exercises/Exercises/E06Text.hs` → `cabal test level01-foundations`
