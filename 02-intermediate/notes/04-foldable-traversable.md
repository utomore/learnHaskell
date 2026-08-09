# 第 4 章 — Foldable 與 Traversable

## Foldable:可以被聚合的結構

Level 1 的 `foldMap` 其實是 Foldable 的方法:

```haskell
class Foldable t where
  foldMap :: Monoid m => (a -> m) -> t a -> m
  foldr   :: (a -> b -> b) -> b -> t a -> b
  -- sum, length, elem, maximum, all, any... 都由此而來
```

`sum`、`length`、`all` 的真正型別是 `Foldable t => t a -> ...`,
所以它們對 `Maybe`、`Map` 也有效(`Map` 摺的是 value)。

標準 Monoid 包裝:`Sum`/`Product`(數字兩種合併方式)、`Any`/`All`、
`Min`/`Max`。`foldMap (Sum . (.gold))` = 「取出每人金幣,全部相加」。

⚠️ 注意:`length (Just 3)` 是 `1` —— 合法但常是 bug 的味道,
GHC 對明顯錯誤的情況會警告,還是要自己留意。

## Traversable:map + 收集效果

本章主角。先看型別,再看它解決什麼:

```haskell
traverse  :: (Traversable t, Applicative f) => (a -> f b) -> t a -> f (t b)
sequenceA :: (Traversable t, Applicative f) => t (f a) -> f (t a)
```

`sequenceA` 把「一疊可能失敗的結果」翻轉成「可能失敗的一疊結果」:

```haskell
sequenceA [Just 1, Just 2]   -- Just [1,2]
sequenceA [Just 1, Nothing]  -- Nothing
```

`traverse f = sequenceA . map f`,一步到位,**這是日常最常用的函式之一**:

```haskell
traverse readInt ["1", "2", "3"]   -- Just [1,2,3]:全部解析成功才成功
traverse readInt ["1", "x"]        -- Nothing
```

換個 Applicative 就換個語意,同一個 `traverse`:

- `a -> Maybe b`:全部成功才成功
- `a -> Either e b`:第一個錯誤停下
- `a -> IO b`:依序執行動作,收集結果(`mapM` 的一般化)

```haskell
contents <- traverse TIO.readFile paths   -- 讀一排檔案,IO [Text]
```

丟棄結果的版本:`traverse_`/`for_`(`Data.Foldable`)。
`for` = `flip traverse`(引數反過來,長 do 區塊比較好讀)。

## 心法

看到「一排 X,每個都要做可能失敗/有副作用的事,要全部結果」——
反射動作就是 `traverse`。它取代你想寫的手工遞迴。

## 習題

`exercises/Exercises/E04Traverse.hs` → `cabal test level02-intermediate`
