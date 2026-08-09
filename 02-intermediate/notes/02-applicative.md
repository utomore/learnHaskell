# 第 2 章 — Applicative:多個上下文的值組合起來

## Functor 的極限

`fmap` 只能套**一元**函式。想把「兩個都可能失敗的值」餵給二元函式呢?

```haskell
ghci> fmap (+) (Just 3)
Just (+3) :: Maybe (Int -> Int)   -- 卡住了:函式被關在 Maybe 裡
```

Applicative 補上這一步:

```haskell
class Functor f => Applicative f where
  pure  :: a -> f a                  -- 把純值放進最小上下文
  (<*>) :: f (a -> b) -> f a -> f b  -- 套用「上下文裡的函式」
```

## 套路:`f <$> x <*> y <*> z`

```haskell
ghci> (+) <$> Just 3 <*> Just 4
Just 7
ghci> (+) <$> Just 3 <*> Nothing
Nothing                            -- 任何一個失敗,全體失敗
```

這個鏈可以無限接下去 —— n 個參數的建構子照樣用:

```haskell
mkHero :: Text -> Int -> Either Text Hero
mkHero n h = Hero <$> validateName n <*> validateHp h
```

這是實務中**最常見的 Applicative 用法**:驗證多個欄位、組合多個解析結果。
`liftA2 f x y`(Prelude 內建)等價於 `f <$> x <*> y`。

## Laws(知道存在即可)

```haskell
pure id <*> v == v                  -- identity
pure f <*> pure x == pure (f x)     -- homomorphism
```

意義同 Functor:組合不會偷偷改變結構。

## Either 是 fail-fast

`Either e` 的 Applicative 遇到第一個 `Left` 就停:

```haskell
ghci> mkHero "" 999
Left "名字不能為空"     -- 只回報第一個錯
```

想**收集所有錯誤**(表單驗證那種需求)要用 `Validation` 型別
(`validation-selective` 套件,錯誤型別是 Semigroup 就能累積)。
先知道有這個選項,需要時再用。

## Applicative vs Monad(下一章)

- Applicative:各個值**彼此獨立**,結構是靜態的 —— `x` 失敗與否不影響 `y` 怎麼算。
- Monad:下一步**依賴前一步的結果**(`>>=` 把值餵進去決定後續)。

經驗法則:能用 Applicative 就用 Applicative,表達的依賴關係最少、
最容易讀(也給了函式庫平行化/靜態分析的空間)。

## 習題

`exercises/Exercises/E02Applicative.hs` → `cabal test level02-intermediate`
