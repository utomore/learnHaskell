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
配三條 law。`Maybe` 的 instance 就是上面那段 `case` 搬進去:

```haskell
instance Monad Maybe where
  Nothing >>= _ = Nothing        -- 短路
  Just x  >>= f = f x            -- 把值餵給下一步
```

習題會讓你手工實作一次(`andThen`),做完你就親眼確認過
「Maybe monad 只是 pattern matching」。

## 為什麼 2026 不用比喻教 Monad

2000 年代的 Haskell 教學充斥「Monad 是 burrito / 太空衣 / 容器 / 管線」
的比喻。它們在 2026 被視為**有害**,原因不是不夠可愛,而是
**每個比喻只對一個 instance 成立**:

- 「容器」對 `Maybe`、list 說得通,對 `IO`、`State`、`Reader`、
  函式 monad `(->) r` 完全說不通——`IO a` 裡沒有裝任何東西。
- 「管線 / 依序執行」對 `IO` 說得通,對 list monad(窮舉所有組合)
  說不通。
- 比喻沒辦法回答「為什麼 `join` 存在」「為什麼 `traverse` 只要 Applicative」
  這種真正需要的問題;型別與 law 可以。

學習者用比喻理解了一個 instance 之後,遇到第二個 instance 就得
推翻重來——這就是「Monad 教學失敗」的真正原因。本課程的做法:
**型別簽名 + laws + 三個 instance 各看一次**,你會發現不需要比喻。

## 三條 laws

```haskell
pure a >>= f      ==  f a                        -- 左單位(left identity)
m >>= pure        ==  m                          -- 右單位(right identity)
(m >>= f) >>= g   ==  m >>= (\x -> f x >>= g)    -- 結合律(associativity)
```

用 do 記法改寫,意義就很清楚了:

```haskell
-- 左單位:綁定一個純值再用,等於直接用
do { x <- pure a; f x }       ==  f a

-- 右單位:把結果原封不動 pure 回去,等於沒做這一步
do { x <- m; pure x }         ==  m

-- 結合律:do 區塊可以任意切段、抽成子函式,語意不變
do { y <- do { x <- m; f x }; g y }
  ==  do { x <- m; y <- f x; g y }
```

第三條是你每天都在用的:把一個長 do 區塊中間三行抽成一個輔助函式,
程式行為不變——這件事**不是理所當然**,是結合律保證的。
前兩條則保證 `pure` 是「無害的一步」,重構時可以自由加減。

用 Kleisli 合成 `>=>` 寫的話,三條 law 就是「`pure` 是單位元、`>=>` 滿足結合律」,
和第 1 級 Monoid 的兩條 law 形狀完全相同:

```haskell
(>=>) :: Monad m => (a -> m b) -> (b -> m c) -> a -> m c

pure >=> f      ==  f
f >=> pure      ==  f
(f >=> g) >=> h ==  f >=> (g >=> h)
```

```haskell
ghci> let safeDiv y x = if y == 0 then Nothing else Just (x `div` y)
ghci> (safeDiv 2 >=> safeDiv 3) 60
Just 10
```

### 違反 law 會怎樣

一個「每次 bind 都記一筆 log」的 monad:

```haskell
newtype Logged a = Logged ([Text], a) deriving stock Show

instance Monad Logged where
  Logged (w, a) >>= f =
    let Logged (w', b) = f a
     in Logged (w <> ["bind"] <> w', b)   -- 多塞了一筆
```

```haskell
ghci> Logged ([], 1) >>= pure
Logged (["bind"],1)                       -- 違反右單位:多了一筆 log
```

後果:同一段邏輯,寫成 `do { x <- m; pure x }` 和直接寫 `m`,
log 內容不一樣;把 do 區塊拆成兩個函式,log 筆數就變了。
你的程式從此「重構會改變行為」——這正是 law 要防止的事。
(合法的寫法是 `Writer` monad:只在明確呼叫 `tell` 時寫 log,bind 本身不寫。)

## do 記法的真相

你第 7 章寫的 do 就是 `>>=` 的語法糖:

```haskell
do weapon <- Map.lookup hero equips        -- 脫糖成:
   Map.lookup weapon stats                 -- lookup ... >>= \weapon -> ...
```

完整的脫糖規則只有三條:

```haskell
do { x <- m; rest }   ==  m >>= \x -> do { rest }
do { m; rest }        ==  m >> do { rest }         -- (>>) = 不用值的 >>=
do { let x = e; rest} ==  let x = e in do { rest }
do { m }              ==  m
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

它和 list comprehension 是同一件事的兩種寫法(comprehension 是 list monad 的專用語法糖):

```haskell
ghci> [1,2] >>= \x -> [x, x*10]
[1,10,2,20]
ghci> [x * 10 | x <- [1,2], even x]
[20]
ghci> do { x <- [1,2]; if even x then [x*10] else [] }
[20]
```

## 舊做法 → 新做法:`return` 與 `pure`

上一章講過 AMP:2015 年前 `return` 是 `Monad` 的方法、`pure` 屬於 `Applicative`,
兩者互不相干。AMP 之後 `Applicative` 成為 `Monad` 的 superclass,
`return` 就變成多餘的——base 裡它的定義是 `return = pure`,留著純粹為了
不讓舊碼壞掉。

2026 慣例:**寫 `pure`**。理由不只是「新」:

- `pure` 的約束是 `Applicative`,能用在更多地方(例如 `traverse` 的回呼)。
- 名字誠實。`return` 對來自 C/Java 的人暗示「函式到此結束」,
  但 `do { return 1; print 2 }` 會照樣印出 2——這個誤會每年都在坑新人。

常用組合子:

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
判斷方法只有一個問題:「**下一步需不需要知道上一步的值?**」
需要 → Monad;不需要 → Applicative;只是轉換結果 → Functor。

## 你會看到的錯誤訊息

do 區塊最後一行忘了自己還在 monad 裡:

```haskell
weapon :: Map String String -> Map String Int -> Maybe Int
weapon equips stats = do
  w <- Map.lookup "hero" equips
  Map.lookup w stats + 1          -- 想對結果 +1
```

```
E3.hs:6:22: error: [GHC-39999]
    • No instance for ‘Num (Maybe Int)’ arising from a use of ‘+’
    • In a stmt of a 'do' block: Map.lookup w stats + 1
      In the expression:
        do w <- Map.lookup "hero" equips
           Map.lookup w stats + 1
  |
6 |   Map.lookup w stats + 1
  |                      ^
```

`In a stmt of a 'do' block` 告訴你錯在 do 裡的哪一句;
`Num (Maybe Int)` 告訴你「你在對一個還包著 `Maybe` 的值做算術」。
修法二選一:`(+ 1) <$> Map.lookup w stats`,或多綁一次
`n <- Map.lookup w stats; pure (n + 1)`。

另一個經典:用 `let` 該用 `<-` 的地方:

```haskell
  let w = Map.lookup "hero" equips     -- w :: Maybe String,不是 String
  Map.lookup w stats
```

```
E3b.hs:6:16: error: [GHC-83865]
    • Couldn't match type: [Char]
                     with: Maybe String
      Expected: Map.Map (Maybe String) Int
        Actual: Map.Map String Int
```

「Expected 一個 key 是 `Maybe String` 的 Map」——因為 `w` 多包了一層。
**`let` 是純綁定,`<-` 才會脫掉 monad 那層**。

## ghci 實驗

```haskell
ghci> :t (>>=)
(>>=) :: Monad m => m a -> (a -> m b) -> m b
ghci> :t (>=>)
(>=>) :: Monad m => (a -> m b) -> (b -> m c) -> a -> m c
ghci> Just 3 >>= \x -> if x > 2 then Just (x * 2) else Nothing
Just 6
ghci> Nothing >>= \x -> Just (x + 1)
Nothing
ghci> :i Monad          -- 看 class 定義:注意 return 的預設就是 pure
```

## 常見誤區

- **以為 `return` 會提早離開。** 不會,它只是 `pure`。
- **在 do 裡混用不同 monad。** 一個 do 區塊裡所有 `<-` 右邊都必須是同一個 `m`;
  `Maybe` 和 `IO` 不能直接混,這是第 9 章 transformer 存在的原因。
- **能用 Applicative 的地方用了 do。** 兩個彼此獨立的 `<-` 接一個 `pure (f x y)`,
  改成 `f <$> mx <*> my` 更短、約束更弱。
- **把 `>>=` 想成「執行」。** 對 `Maybe`、list 它只是 pattern matching,
  什麼都沒「執行」。「執行」是 `IO` 這個 instance 的特色,不是 Monad 的定義。

## 習題

`exercises/Exercises/E03Monads.hs` → `cabal test level02-intermediate`

會讓你手工實作一次 Maybe 的 bind(`andThen`)—— 做完就親眼確認過
「Maybe monad 只是 pattern matching」。寫完順手在 ghci 驗右單位:
`(Just 3 `andThen` Just) == Just 3`。
