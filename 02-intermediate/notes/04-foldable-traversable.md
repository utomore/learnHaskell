# 第 4 章 — Foldable 與 Traversable

## Foldable:可以被聚合的結構

Level 1 的 `foldMap` 其實是 Foldable 的方法:

```haskell
class Foldable t where
  foldMap :: Monoid m => (a -> m) -> t a -> m
  foldr   :: (a -> b -> b) -> b -> t a -> b
  -- sum, length, elem, maximum, all, any, foldl'... 都由此而來
```

`sum`、`length`、`all` 的真正型別是 `Foldable t => t a -> ...`,
所以它們對 `Maybe`、`Map` 也有效(`Map` 摺的是 value)。

標準 Monoid 包裝:`Sum`/`Product`(數字兩種合併方式)、`Any`/`All`、
`Min`/`Max`。`foldMap (Sum . (.gold))` = 「取出每人金幣,全部相加」。

## 舊做法 → 新做法:FTP 與「怪現象」

2015 年前(GHC 7.10 之前),`length`、`sum`、`elem` 都是 **list 專用**的。
GHC 7.10 的 **FTP(Foldable/Traversable in Prelude)** 把它們一般化成
`Foldable t =>`,好處是 `Map`、`Set`、`Maybe`、自訂樹全都能直接 `sum`;
代價是一批當年引發激烈爭論的「怪現象」:

```haskell
ghci> length (1, 2)
1
ghci> maximum (3, 1)
1
ghci> sum (Just 3)
3
ghci> elem 3 (Just 3)
True
ghci> length Nothing
0
```

`length (1, 2)` 為什麼是 1?因為 `Foldable` 的 instance 是 `(,) a`——
型別建構子只剩最後一個參數是「內容」,tuple 的第一個元素屬於「結構」
(和第 1 章 `fmap` 對 tuple 的行為完全一致)。`Maybe` 則是「0 或 1 個元素的容器」。

這些結果**在型別上都正確**,但常常是 bug 的味道:你本來想 `length` 一個 list,
手上卻是 `Maybe [a]`。GHC 對這些**不會**警告(`-Wall` 過得去),
hlint 會提醒一部分。自保方法:

1. 型別簽名寫明確。`length` 的引數如果你認為是 list,就讓簽名說它是 list。
2. 對 `Maybe` 想問「有沒有值」用 `isJust`/`maybe`,不用 `length`/`null`。
3. 看到 `sum`/`length` 作用在 tuple 或 `Maybe` 上,九成是少了一層解構。

## Traversable:map + 收集效果

本章主角。先看型別,再看它解決什麼:

```haskell
traverse  :: (Traversable t, Applicative f) => (a -> f b) -> t a -> f (t b)
sequenceA :: (Traversable t, Applicative f) => t (f a) -> f (t a)
```

讀 `sequenceA` 的型別:輸入是「一個結構 `t`,每格裝著一個效果 `f a`」,
輸出是「一個效果 `f`,裡面是整個結構 `t a`」——**把兩層包裝內外翻轉**。
`t` 是 list 而 `f` 是 `Maybe` 時:

```haskell
sequenceA [Just 1, Just 2]   -- Just [1,2]
sequenceA [Just 1, Nothing]  -- Nothing
```

`traverse f = sequenceA . fmap f`,一步到位,**這是日常最常用的函式之一**:

```haskell
traverse readInt ["1", "2", "3"]   -- Just [1,2,3]:全部解析成功才成功
traverse readInt ["1", "x"]        -- Nothing
```

換個 Applicative 就換個語意,同一個 `traverse`:

- `a -> Maybe b`:全部成功才成功
- `a -> Either e b`:第一個錯誤停下
- `a -> Validation e b`(第 2 章):收集所有錯誤
- `a -> IO b`:依序執行動作,收集結果(`mapM` 的一般化)

```haskell
contents <- traverse TIO.readFile paths   -- 讀一排檔案,IO [Text]
```

### 舊做法 → 新做法:`mapM`、`sequence`、`forM`

```haskell
mapM     :: (Traversable t, Monad m)       => (a -> m b) -> t a -> m (t b)
traverse :: (Traversable t, Applicative f) => (a -> f b) -> t a -> f (t b)
```

型別只差一個約束:`mapM` 要求 `Monad`,`traverse` 只要 `Applicative`。
歷史上 `mapM` 先出現(Haskell 98 就有,那時只對 list),`traverse` 是
2008 年 Applicative 論文的產物,FTP 之後兩者才都變成一般化的。
今天 `mapM = traverse` 加上一個多餘的約束,留著純粹為了相容。

**2026 慣例:寫 `traverse`/`sequenceA`/`for`**。理由:

- 約束更弱,`Validation` 這類只有 Applicative 的型別也能用。
- 名字更準確:`traverse` 是「走訪並收集效果」,`mapM` 的 `M` 暗示「需要 Monad」,其實不需要。

`forM`/`for` 是引數反過來的版本(`for = flip traverse`),長 do 區塊比較好讀:

```haskell
for paths $ \path -> do
  content <- TIO.readFile path
  pure (T.length content)
```

### 丟棄結果的版本

```haskell
traverse_ :: (Foldable t, Applicative f) => (a -> f b) -> t a -> f ()
for_      :: (Foldable t, Applicative f) => t a -> (a -> f b) -> f ()
mapM_ / forM_                          -- 同上,Monad 約束的舊版
```

注意它們的約束是 **Foldable** 而不是 Traversable:既然結果要丟掉,
就不需要重建結構,只需要走訪。取捨:

| 要結果嗎? | 用 |
|---|---|
| 要,且結構要保留 | `traverse` / `for` |
| 不要,只跑效果 | `traverse_` / `for_` |
| 舊碼裡看到 | `mapM`/`forM`/`mapM_`/`forM_`,語意相同 |

## Traversable 的 laws

```haskell
traverse Identity == Identity                              -- identity
traverse (Compose . fmap g . f) == Compose . fmap (traverse g) . traverse f  -- composition
```

白話:用「什麼都不做的效果」走訪,等於什麼都不做;
兩趟走訪可以合成一趟。加上一條 naturality(換 Applicative 不改結構)。
你不需要背它們,但要知道它們保證兩件事:**`traverse` 不會改變結構
(list 長度、樹的形狀)**,以及 **`traverse` 只走訪每個元素恰好一次**。
第 2 章 `Counted` 那個違法的 Applicative 讓 `traverse` 多算一次,
正是 identity law 靠 `pure` 中性才成立的例子。

同樣,`deriving stock (Functor, Foldable, Traversable)` 生成的 instance 保證守法。
自訂的樹、`Chest`、`Pair` 都該這樣 derive,不手寫。

## 心法

看到「一排 X,每個都要做可能失敗/有副作用的事,要全部結果」——
反射動作就是 `traverse`。它取代你想寫的手工遞迴:

```haskell
-- 手工遞迴(不要再寫這個)
parseAll [] = Just []
parseAll (x : xs) = case readInt x of
  Nothing -> Nothing
  Just n -> case parseAll xs of
    Nothing -> Nothing
    Just ns -> Just (n : ns)

-- 一行
parseAll = traverse readInt
```

## 你會看到的錯誤訊息

`traverse` 的回呼忘了回傳「包在 Applicative 裡」的值:

```haskell
z :: Maybe [Int]
z = traverse (+ 1) [1, 2, 3]
```

```
E4.hs:3:15: error: [GHC-39999]
    • No instance for ‘Num (Maybe Int)’ arising from a use of ‘+’
    • In the expression: (+)
      In the first argument of ‘traverse’, namely ‘(+ 1)’
  |
3 | z = traverse (+ 1) [1, 2, 3]
  |               ^
```

`traverse` 要的回呼型別是 `a -> f b`,這裡 `f` 是 `Maybe`,
所以 GHC 要求 `(+ 1)` 回傳 `Maybe Int`,反推出「`1` 必須是 `Maybe Int`」,
於是找不到 `Num (Maybe Int)`。修法:純轉換用 `fmap`(`(+ 1) <$> [1,2,3]`),
真的要 `traverse` 就給一個回 `Maybe` 的函式(`\x -> Just (x + 1)`)。

規律:**`traverse` 的回呼一定要回 `f b`**,看到 `Num (f ...)` 就是回呼少包一層。

## ghci 實驗

```haskell
ghci> :t sequenceA
sequenceA :: (Traversable t, Applicative f) => t (f a) -> f (t a)
ghci> sequenceA [Just 1, Just 2]
Just [1,2]
ghci> sequenceA [Just 1, Nothing]
Nothing
ghci> traverse_ print [1,2]
1
2
ghci> for_ (Just 3) print          -- Maybe 也是 Foldable:有值就跑
3
ghci> length (1, 2)                 -- 親眼看一次「怪現象」
1
```

## 常見誤區

- **`traverse` 和 `fmap` 選錯。** 回呼沒有效果(`a -> b`)用 `fmap`;
  有效果(`a -> f b`)用 `traverse`。
- **要結果卻用了 `traverse_`。** `traverse_` 回 `f ()`,結果早丟了。
- **對 `Map` 用 `traverse` 以為會碰 key。** 只走訪 value;key 是結構的一部分。
- **`length`/`null` 用在 `Maybe` 上當存在檢查。** 型別過了、語意可疑,用 `isJust`。

## 習題

`exercises/Exercises/E04Traverse.hs` → `cabal test level02-intermediate`

`openAll` 與 `parseAllInts` 各是一次 `traverse`;`partyGold`、`allAlive`
是 `foldMap`/`all` 的練習。寫完檢查一下:有沒有哪一題你其實寫了手工遞迴?
