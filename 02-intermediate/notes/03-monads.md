# 第 3 章 — Monad:下一步依賴上一步的串接

## 直接看問題

查裝備表拿到武器名,**再拿武器名**去查攻擊力 —— 第二步的查詢
取決於第一步的結果,`<*>` 做不到這件事:

```haskell
case Map.lookup hero equips of
  Nothing -> Nothing
  Just weapon -> Map.lookup weapon stats
```

這種「Nothing 就短路、Just 就把值餵給下一步」的模板寫多了很煩。
Monad 把它抽象掉:

```haskell
class Applicative m => Monad m where
  (>>=) :: m a -> (a -> m b) -> m b    -- 讀作 "bind"

Map.lookup hero equips >>= \weapon -> Map.lookup weapon stats
```

**就這樣,沒有比喻,沒有玄學。** Monad 是「帶上下文的串接」的 API,
配三條 law(左單位、右單位、結合律 —— 意義是串接方式不影響結果,
所以 do 區塊可以放心拆小、重組)。

## do 記法的真相

你第 7 章寫的 do 就是 `>>=` 的語法糖:

```haskell
do weapon <- Map.lookup hero equips        -- 脫糖成:
   Map.lookup weapon stats                 -- lookup ... >>= \weapon -> ...
```

**同一套 do 語法,行為由 monad instance 決定:**

| monad | `x <- action` 的意義 |
|-------|---------------------|
| `IO` | 執行副作用,拿結果 |
| `Maybe` | `Nothing` 就整段放棄 |
| `Either e` | `Left` 就整段放棄(帶著錯誤) |
| `[]` | 對**每個**元素都跑一遍後續(窮舉組合) |

list monad 值得體驗一次:

```haskell
allPairs xs ys = do
  x <- xs        -- 對每個 x
  y <- ys        --   對每個 y
  pure (x, y)    --     產生一組
```

## pure、return、常用工具

`return` 就是 `pure` 的舊名,**寫 `pure`**。常用組合子:

```haskell
when   :: Applicative f => Bool -> f () -> f ()
unless :: Applicative f => Bool -> f () -> f ()
mapM_  / forM_ / traverse_   -- 對每個元素跑動作,丟棄結果
(>>)   -- 串接但不用前面的值(do 裡直接換行就是它)
```

## 選擇的階梯

能力越弱的抽象越容易推理,**用夠用的最弱工具**:

```
Functor(只轉換) ⊂ Applicative(獨立組合) ⊂ Monad(依賴串接)
```

`fmap` 能解決就別 `<*>`;`<*>` 能解決就別 `>>=`。

## 習題

`exercises/Exercises/E03Monads.hs` → `cabal test level02-intermediate`

會讓你手工實作一次 Maybe 的 bind(`andThen`)—— 做完就親眼確認過
「Maybe monad 只是 pattern matching」。
