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

## case 運算式

```haskell
describeRoll :: Int -> Text
describeRoll roll = case roll of
  1   -> "大失敗!"
  100 -> "大成功!"
  _   -> "普通"
```

## Total functions(2026 重要習慣)

**partial function** 是對某些輸入會爆炸的函式,例如 `head []`。
GHC 現在內建 `x-partial` 警告來阻止你用 `head`/`tail`。現代做法:

- 可能失敗 → 回傳 `Maybe`:

```haskell
safeDivide :: Double -> Double -> Maybe Double
safeDivide _ 0 = Nothing
safeDivide x y = Just (x / y)
```

- pattern match 要**涵蓋所有案例**(我們開了 `-Wincomplete-patterns` 系警告,漏了編譯器會唸你)。

`Maybe a` 的定義就只是 `data Maybe a = Nothing | Just a` —— 第 4 章你會自己定義這種型別。

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

## 柯里化與部分套用

`hitPoints :: Int -> Int -> Int` 其實是「吃一個 Int,回傳一個 `Int -> Int`」。
所以可以只餵一個引數:

```haskell
ghci> bossAttack = hitPoints 100   -- 固定 hp = 100
ghci> bossAttack 30
70
```

## 函式合成:`.` 與 `$`

```haskell
-- f . g 是「先 g 再 f」
shoutName :: Player -> Text
shoutName = T.toUpper . (.name)

-- $ 只是「最低優先度的套用」,用來省括號
print (sum (map (*2) [1,2,3]))
print $ sum $ map (*2) [1,2,3]   -- 同一件事
```

用 `.` 把小函式串成資料處理管線,是 Haskell 的核心風格 ——
第 3 章的 list 處理會大量使用。

## 習題

`exercises/Exercises/E02Functions.hs` → `cabal test level01-foundations`
