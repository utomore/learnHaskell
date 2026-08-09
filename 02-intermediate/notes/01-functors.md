# 第 1 章 — Functor:可以被 map 的結構

## 從你已經會的東西開始

Level 1 你已經用過這些:

```haskell
map  (+1) [1, 2, 3]        -- list 逐個轉換
fmap (+1) (Just 10)        -- Maybe 裡面的值轉換
```

`map` 和「對 Maybe 裡的值做事」是同一個模式:**結構不動,內容轉換**。
Functor 就是把這個模式抽出來的 typeclass:

```haskell
class Functor f where
  fmap :: (a -> b) -> f a -> f b
```

注意 `f` 是**型別建構子**(`Maybe`、`[]`、`Chest`),不是具體型別。
`f a` = 「某種裝著 a 的結構」。

## 本課程的教學立場

**Functor 不是比喻,是一組 API + 兩條 law。**「容器」「盒子」只是幫助直覺的
描述,定義永遠是型別與定律:

```haskell
fmap id      == id             -- 什麼都不做就是什麼都不做
fmap (f . g) == fmap f . fmap g  -- 合成後再 map = map 兩次
```

law 保證 `fmap` **只碰內容、不碰結構**:不會讓 list 變長、
不會把 `Just` 變 `Nothing`。所以你可以放心重構。

## 常見 instance

```haskell
fmap (+1) (Just 1)       -- Just 2
fmap (+1) Nothing        -- Nothing
fmap (+1) [1,2,3]        -- [2,3,4]
fmap (+1) (Right 1)      -- Right 2      (Either e 對 Right 那邊 map)
fmap (+1) (Left "err")   -- Left "err"   (Left 原樣通過)
fmap T.toUpper TIO.getLine  -- IO 也是 Functor:轉換「未來的結果」
```

`<$>` 是 `fmap` 的中綴版,讀作「map 過去」:

```haskell
T.toUpper <$> TIO.getLine
```

## 自己的型別自己 derive

```haskell
data Chest a = EmptyChest | Chest a
  deriving stock (Eq, Show, Functor)   -- GHC 會自動推導 Functor!
```

習題會要你**手寫一次** instance(理解機制),但實務上
`deriving stock (Functor)` 是常態。

## 為什麼值得抽象

寫一次 `buffAll :: Functor f => Int -> f Int -> f Int`,
就同時適用於 list(場上所有敵人)、`Maybe`(可能不存在的目標)、
以及你自訂的任何結構。遊戲程式裡這種「對整個結構套效果」無所不在。

## 習題

`exercises/Exercises/E01Functors.hs` → `cabal test level02-intermediate`
