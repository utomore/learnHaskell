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

## 舊做法 → 新做法:`map` 為什麼只給 list

歷史上 `map` 比 `Functor` 早得多:Haskell 1.0(1990)的 `map` 就只對 list 有效,
`Functor` 是 Haskell 1.3(1996)才進標準庫的。那個年代 `fmap` 主要拿來寫
泛型程式碼,一般程式直接對 list 用 `map`。所以到今天:

- `map` 仍然只是 list 專用的 `fmap`(`map = fmap @[]`),留著是為了向後相容
  與初學者友善(錯誤訊息比較短)。
- 舊教材會教你「先學 `map`,Functor 是進階主題」——這是歷史包袱。
  2026 的觀點:`fmap`/`<$>` 才是一般情形,`map` 是它的特例。
  對 list 用 `map` 沒有錯,但看到 `Maybe`、`Either`、`IO`、`Map`
  時要立刻想到同一個 `fmap`。

## 本課程的教學立場:兩條 law

**Functor 不是比喻,是一組 API + 兩條 law。**「容器」「盒子」只是幫助直覺的
描述,定義永遠是型別與定律:

```haskell
-- law 1:identity
fmap id == id
-- 白話:「什麼都不做」map 過去之後,還是什麼都不做。

-- law 2:composition
fmap (f . g) == fmap f . fmap g
-- 白話:先合成再 map 一次,等於分兩次 map。
```

law 保證 `fmap` **只碰內容、不碰結構**:不會讓 list 變長、
不會把 `Just` 變 `Nothing`。所以你可以放心重構——
把 `fmap f (fmap g x)` 改成 `fmap (f . g) x` 少走一趟,行為保證一樣
(base 裡 list 的 `map/map` rewrite rule 就是靠這條 law 幫你自動做這個優化)。

### 違反 law 會怎樣

法律沒有人強制執行:GHC 不會檢查 laws,你寫得出違法的 instance:

```haskell
newtype Sneaky a = Sneaky (Maybe a) deriving stock Show

instance Functor Sneaky where
  fmap _ (Sneaky _) = Sneaky Nothing   -- 型別檢查過了,但偷改結構
```

```haskell
ghci> fmap id (Sneaky (Just 3))
Sneaky Nothing                -- 違反 identity:fmap id 不是 id
ghci> fmap id (Just 3)
Just 3                        -- 守法的 Maybe
```

後果是**所有建立在 Functor 之上的東西都會壞**:`<$>` 鏈、`traverse`、
`void`……任何人拿到 `Functor Sneaky` 都以為「結構不變」,
結果值憑空消失,而且錯誤發生在離 instance 很遠的地方。
這也是為什麼 `deriving stock Functor` 是首選:編譯器生成的 instance
一定守法。

## 常見 instance

```haskell
fmap (+1) (Just 1)       -- Just 2
fmap (+1) Nothing        -- Nothing
fmap (+1) [1,2,3]        -- [2,3,4]
fmap (+1) (Right 1)      -- Right 2      (Either e 對 Right 那邊 map)
fmap (+1) (Left "err")   -- Left "err"   (Left 原樣通過)
fmap T.toUpper TIO.getLine  -- IO 也是 Functor:轉換「未來的結果」
```

`<$>` 是 `fmap` 的中綴版,兩者**完全相同**(`(<$>) = fmap`,型別一字不差),
讀作「map 過去」:

```haskell
T.toUpper <$> TIO.getLine
```

選哪個純粹是排版:`f <$> x` 讀起來像函式套用 `f x`,鏈起來好看;
`fmap f` 適合當作點自由(point-free)的函式傳給別人。

### 函式也是 Functor

`(->) r`(「吃一個 r 的函式」)也有 Functor instance,而它的 `fmap` 就是合成:

```haskell
ghci> fmap (+1) (+2) 3
6
ghci> ((+1) . (+2)) 3
6
```

`fmap f g = f . g`:「轉換一個函式的結果」= 在後面接一個函式。
看懂這一點,`Functor` 的意思就穩了——它真的不是「容器」,
函式沒有裝任何東西。

### 順手常用:`void`、`<$`

```haskell
void :: Functor f => f a -> f ()      -- 丟掉結果,只留結構/效果
(<$) :: Functor f => a -> f b -> f a  -- 把內容全換成同一個值
```

```haskell
ghci> void (Just 3)
Just ()
ghci> 3 <$ Just "x"
Just 3
```

`void` 在 IO 裡很常見:`void (forkIO ...)`、`void (traverse ...)`——
表示「我知道有回傳值,我故意不要」,比 `_ <- ...` 更明確。

## 自己的型別自己 derive

```haskell
data Chest a = EmptyChest | Chest a
  deriving stock (Eq, Show, Functor)   -- GHC 會自動推導 Functor!
```

習題會要你**手寫一次** instance(理解機制),但實務上
`deriving stock (Functor)` 是常態:2026 慣例是**能 derive 就 derive**,
手寫 Functor instance 只發生在型別參數出現在函式的引數位置
(逆變)等 GHC 拒絕推導的情況。

## 你會看到的錯誤訊息

最常見的一個:忘了自己手上的是 `Maybe Int`,直接拿去加:

```haskell
x :: Maybe Int
x = Just 3 + 1
```

```
E1.hs:3:12: error: [GHC-39999]
    • No instance for ‘Num (Maybe Int)’ arising from a use of ‘+’
    • In the expression: Just 3 + 1
      In an equation for ‘x’: x = Just 3 + 1
  |
3 | x = Just 3 + 1
  |            ^
```

怎麼讀:

1. `No instance for ‘Num (Maybe Int)’`:GHC 想對 `Maybe Int` 做 `+`,
   但 `Maybe Int` 不是數字。這句話幾乎永遠代表「你少了一層 `fmap`」。
2. `arising from a use of ‘+’`:是哪個運算子引起的。
3. 最後的 `^` 指到 `+` 的位置。

修法:`fmap (+ 1) (Just 3)` 或 `(+ 1) <$> Just 3`。
同一個錯誤訊息在 `Either e Int`、`IO Int`、`[Int]` 上長得一模一樣,
反射動作都是「加 `<$>`」。

## ghci 實驗

```haskell
ghci> :t fmap
fmap :: Functor f => (a -> b) -> f a -> f b
ghci> :t (<$>)
(<$>) :: Functor f => (a -> b) -> f a -> f b      -- 一模一樣
ghci> :i Functor                    -- 看 class 定義與所有 instance
ghci> fmap (+1) (+2) 3              -- 函式的 Functor = 合成
6
ghci> fmap length (Just "abc")
Just 3
```

`:i Functor` 的輸出裡你會看到 `instance Functor ((->) r)`、
`instance Functor ((,) a)`(tuple 對**第二個**元素 map)、
`instance Functor (Either a)`——每一個都值得試一次。

## 常見誤區

- **以為 `fmap` 會改變結構。** 不會,law 禁止。`fmap` 過後 list 長度、
  `Just`/`Nothing`、`Left`/`Right` 全部保持不變。
- **對 tuple `fmap` 以為兩個都會變。** `fmap (+1) (1, 2)` 是 `(1, 3)`:
  型別建構子是 `(,) a`,只有最後一個參數是「內容」。
- **手寫 Functor instance 忘了遞迴。** 樹狀型別每個子節點都要 `fmap`,
  漏掉一個分支就違反 law。用 `deriving stock Functor` 免煩惱。
- **把 `<$>` 和 `$` 搞混。** `f $ x` 是普通套用;`f <$> x` 是穿透一層結構。
  忘了 `<` 的話,錯誤訊息就是上面那個 `No instance for Num (Maybe ...)`。

## 為什麼值得抽象

寫一次 `buffAll :: Functor f => Int -> f Int -> f Int`,
就同時適用於 list(場上所有敵人)、`Maybe`(可能不存在的目標)、
以及你自訂的任何結構。遊戲程式裡這種「對整個結構套效果」無所不在。

## 習題

`exercises/Exercises/E01Functors.hs` → `cabal test level02-intermediate`

手寫 `Chest` 與 `Pair` 的 instance 時,寫完在 ghci 用
`fmap id (Chest 3) == Chest 3` 自己驗一次 identity law。
