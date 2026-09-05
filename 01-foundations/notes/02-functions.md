# 第 2 章 — Pattern Matching、Guards、高階函式

## Pattern Matching:依形狀分案例

函式可以寫成多個等式,由上往下比對:

```haskell
answer :: Int -> Text
answer 42 = "宇宙的答案"
answer _  = "普通數字"     -- _ = 不在乎的萬用字元
```

比對 tuple:

```haskell
swap' :: (a, b) -> (b, a)
swap' (x, y) = (y, x)
```

`a`、`b` 是**型別變數**(小寫開頭):這個函式對任何型別都成立,
叫做**參數多型**(不是 OOP 的繼承多型)。

參數多型有一個好處,初學容易忽略:`swap' :: (a, b) -> (b, a)` 這個簽名
**只有一種**合理實作。它不知道 `a` 是什麼,所以不能檢查它、不能造一個新的 `a`,
只能把拿到的東西原封不動放到另一邊。型別越泛,能做的事越少,
程式就越不可能寫錯 —— 這是「讓型別替你思考」的第一個例子。

## Guards:依條件分案例

```haskell
describeHp :: Int -> Text
describeHp hp
  | hp <= 0   = "倒下"
  | hp < 20   = "瀕死"
  | hp < 70   = "受傷"
  | otherwise = "健康"
```

由上往下試,第一個為 `True` 的分支獲勝。`otherwise` 就是 `True` 的別名。

### Guard 還是 `if`?

兩者能表達的東西一樣,差在**可讀性**:

- 兩條路 → `if c then a else b` 就好。
- 三條以上、依序判斷的區間 → guard。把 `describeHp` 改寫成巢狀 `if`
  會變成向右一路縮排的階梯,一眼看不出有幾個案例。
- 需要**同時看形狀和條件** → pattern 配 guard:

```haskell
attack :: Monster -> Int -> Text
attack (Dragon _ hp) dmg
  | dmg >= hp = "一擊斬龍!"
  | otherwise = "龍還活著"
attack (Slime _) _ = "史萊姆爆了"
```

guard 是「這個 pattern 之下再細分」,不是取代 pattern matching。

## case 運算式

```haskell
describeRoll :: Int -> Text
describeRoll roll = case roll of
  1   -> "大失敗!"
  100 -> "大成功!"
  _   -> "普通"
```

`case` 和多等式定義是同一件事的兩種寫法:多等式適合「整個函式就是在分案例」,
`case` 適合「在運算式中間對某個**中間結果**分案例」。
第 4 章會看到更省字的 `\case`。

## `where` 還是 `let`?

```haskell
-- where:掛在整個等式後面,所有 guard 都看得到
damageAfterArmor :: Int -> Int -> Int
damageAfterArmor dmg armor
  | effective <= 0 = 0
  | otherwise      = effective
  where
    effective = dmg - armor

-- let:是運算式,可以出現在任何運算式的位置
damageAfterArmor' :: Int -> Int -> Int
damageAfterArmor' dmg armor =
  let effective = dmg - armor
   in max 0 effective
```

- `where` 的作用域是**整個等式**,包含 guard —— 上面 `effective` 在 guard 裡也能用,
  `let ... in` 做不到這點(它只涵蓋 `in` 後面那段)。
- `let` 是運算式,所以可以塞在括號裡、lambda 裡、第 7 章的 `do` 區塊裡。
- 慣例:定義輔助值給整個函式用 → `where`;局部小計算 → `let`。兩者都可以巢狀。

## Total functions(2026 重要習慣)

**partial function** 是對某些輸入會爆炸的函式,例如 `head []`。

### `head` 的三十年

`head`、`tail`、`init`、`last`、`!!` 從 Haskell 1.0(1990)就在 Prelude 裡。
當年的設計思路是 Lisp 式的:list 是主要資料結構,`car`/`cdr` 風格的存取很自然,
「空 list 呼叫 `head` 是呼叫者的錯」。但三十年的實務證明:

- 它們是 Haskell 程式**執行期崩潰的第一大來源**,而且錯誤訊息只有一句
  `Prelude.head: empty list`,連是哪一行呼叫的都不知道(近幾版才補上 `HasCallStack` 呼叫堆疊)。
- 型別簽名 `head :: [a] -> a` 在**說謊**:它承諾對任何 list 都能給你一個 `a`,
  但空 list 給不出來。型別系統最大的價值就是簽名可信,partial function 直接破壞這件事。

所以 GHC 9.8 起,Prelude 的 `head`/`tail` 被標上 `{-# WARNING #-}`,
使用它們會觸發 `-Wx-partial` 警告(在 `-Wall` 內):

```
Ch2.hs:8:14: warning: [GHC-63394] [-Wx-partial]
    In the use of ‘head’
    (imported from Prelude, but defined in GHC.Internal.List):
    "This is a partial function, it throws an error on empty lists.
     Use pattern matching, 'Data.List.uncons' or 'Data.Maybe.listToMaybe' instead.
     Consider refactoring to use "Data.List.NonEmpty"."
```

警告本身就把三種正解列出來了。現代做法:

- 可能失敗 → 回傳 `Maybe`:

```haskell
safeDivide :: Double -> Double -> Maybe Double
safeDivide _ 0 = Nothing
safeDivide x y = Just (x / y)

safeHead :: [a] -> Maybe a
safeHead []      = Nothing
safeHead (x : _) = Just x        -- 就是 Data.Maybe.listToMaybe
```

- 「這個 list 保證非空」→ 用 `Data.List.NonEmpty` 這個**型別**表達保證,
  它的 `NE.head` 是 total 的,因為空的 `NonEmpty` 根本造不出來。第 8 章「日常語法」細講。
- pattern match 要**涵蓋所有案例**(我們開了 `-Wincomplete-patterns` 系警告,漏了編譯器會唸你)。

`Maybe a` 的定義就只是 `data Maybe a = Nothing | Just a` —— 第 4 章你會自己定義這種型別。

你在舊教材、舊函式庫和 Stack Overflow 舊答案裡還是會大量看到 `head`。
讀得懂就好,自己寫的程式碼裡一律換掉。

## 高階函式:函式是一等公民

函式可以當引數、當回傳值:

```haskell
applyTwice :: (a -> a) -> a -> a
applyTwice f x = f (f x)

ghci> applyTwice (+3) 10
16
ghci> applyTwice (T.append "很") "重要"
"很很重要"
```

`(+3)` 是**運算子切片**(section):`\x -> x + 3` 的簡寫。
匿名函式(lambda)寫成 `\x -> ...`。

section 有一個經典陷阱:`(-1)` 不是「減一」而是**負一**這個數字
(因為 `-` 也是負號)。要「減一」寫 `subtract 1` 或 `\x -> x - 1`:

```haskell
ghci> map (subtract 1) [1, 2, 3]
[0,1,2]
```

## 柯里化與部分套用

`hitPoints :: Int -> Int -> Int` 其實是「吃一個 Int,回傳一個 `Int -> Int`」。
所以可以只餵一個引數:

```haskell
ghci> bossAttack = hitPoints 100   -- 固定 hp = 100
ghci> bossAttack 30
70
```

這解釋了第 1 章 `:t max 0` 為什麼合法:`max 0 :: (Ord a, Num a) => a -> a`,
它是「跟 0 比大小」這個新函式。Haskell 裡**所有**多參數函式都是這樣一個一個吃的,
沒有例外 —— 所以 `hitPoints 20 -5` 才會被讀成 `(hitPoints 20) - 5`。

## 函式合成:`.` 與 `$`

```haskell
-- f . g 是「先 g 再 f」
shoutName :: Player -> Text
shoutName = T.toUpper . (.name)

-- $ 只是「最低優先度的套用」,用來省括號
print (sum (map (*2) [1,2,3]))
print $ sum $ map (*2) [1,2,3]   -- 同一件事
```

```haskell
ghci> :t (.)
(.) :: (b -> c) -> (a -> b) -> a -> c
ghci> :t ($)
($) :: (a -> b) -> a -> b
```

`.` 的簽名說得很清楚:先用 `a -> b`,把結果餵給 `b -> c`,合成 `a -> c`。
`shoutName = T.toUpper . (.name)` 沒有寫出參數 —— 這叫 **point-free** 風格,
「定義一條管線」時很清楚;但硬把三個以上的參數都消掉會變成謎題,適可而止。

用 `.` 把小函式串成資料處理管線,是 Haskell 的核心風格 ——
第 3 章的 list 處理會大量使用。

## 你會看到的錯誤訊息

漏了一個案例。本專案開了 `-Wincomplete-patterns`,編譯時會看到:

```
Ch2.hs:5:1: warning: [GHC-62161] [-Wincomplete-patterns]
    Pattern match(es) are non-exhaustive
    In an equation for ‘describeElement’:
        Patterns of type ‘Element’ not matched: Lightning
```

- 這是 **warning** 不是 error,程式照樣編過 —— 所以你必須主動看警告。
- `not matched: Lightning` 直接告訴你漏了誰;新增一個建構子時,
  所有處理它的函式都會冒出這條警告,這是 ADT 最實用的特性(第 4 章)。

如果無視警告執行到那個案例:

```
ch2b.exe: Uncaught exception ghc-internal:GHC.Internal.Control.Exception.Base.PatternMatchFail:

Ch2b.hs:(4,1)-(5,28): Non-exhaustive patterns in function describeElement
```

執行期才炸,而且是在玩家按下某個按鍵的那一刻。警告是免費的,執行期錯誤不是。

## ghci 實驗

```haskell
ghci> :t (+3)                        -- Num c => c -> c
ghci> :t applyTwice                  -- (a -> a) -> a -> a
ghci> describeHp hp | hp <= 0 = "down" | hp < 20 = "dying" | otherwise = "ok"
ghci> describeHp 0
"down"
ghci> :t describeHp                  -- (Ord a1, Num a1, IsString a2) => a1 -> a2
```

最後一行注意兩件事:`cabal repl` 會帶入 cabal 裡的 `OverloadedStrings`,所以回傳型別
不是 `String` 而是任何 `IsString a2`(第 6 章);沒有簽名所以參數也推成任何 `(Ord a1, Num a1)`。
推斷出來的是「最寬」的型別,這就是第 1 章說「要寫簽名」的原因。

## 常見誤區

1. `(-1)` 是負一,「減一」要寫 `subtract 1`。
2. guard 的 `otherwise` 忘了寫 → 非窮盡警告 + 執行期 `Non-exhaustive guards`。
3. `where` 能被 guard 看到,`let ... in` 不行。
4. `f . g x` 是 `f . (g x)`,不是 `(f . g) x` —— 函式套用比 `.` 優先。
5. `head`/`tail` 出現在你的程式碼裡 = 警告 = 有一個空 list 案例你還沒想。

## 習題

`exercises/Exercises/E02Functions.hs` → `cabal test level01-foundations`
