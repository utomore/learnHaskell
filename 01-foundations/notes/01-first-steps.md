# 第 1 章 — 運算式、型別、第一個函式

## 一切都是運算式

Haskell 沒有「陳述式」,只有會求值出結果的**運算式**。開 ghci 實驗:

```powershell
cabal repl level01-foundations
```

```haskell
ghci> 2 + 3 * 4
14
ghci> max 10 20
20
ghci> sqrt (3^2 + 4^2)
5.0
```

函式呼叫**不用括號和逗號**:`max 10 20` 而不是 `max(10, 20)`。
函式套用的優先度最高,所以 `sqrt 3 + 4` 是 `(sqrt 3) + 4`。

## 型別:用 `:t` 問

```haskell
ghci> :t True
True :: Bool
ghci> :t 'a'
'a' :: Char
ghci> :t not
not :: Bool -> Bool
```

`::` 讀作「的型別是」。`Bool -> Bool` 是「吃一個 Bool、回一個 Bool 的函式」。

常見基本型別:`Int`(機器整數)、`Integer`(任意精度整數)、
`Double`、`Bool`、`Char`、`Text`(字串 —— 第 6 章;**不是** `String`)。

數字字面值是多載的:`3` 可以是 `Int` 也可以是 `Double`,由上下文決定。
需要指定時寫 `(3 :: Double)`。

## 定義函式

```haskell
-- 先寫型別簽名(好習慣,永遠要寫),再寫定義
hitPoints :: Int -> Int -> Int
hitPoints hp dmg = max 0 (hp - dmg)
```

`Int -> Int -> Int`:吃兩個 `Int`、回一個 `Int`。
(箭頭其實是右結合的 `Int -> (Int -> Int)` —— 柯里化,第 2 章細講。)

在 ghci 裡也能直接定義:

```haskell
ghci> double x = x * 2
ghci> double 21
42
```

## let 與 where

```haskell
secondsToHms :: Int -> (Int, Int, Int)
secondsToHms total = (h, m, s)
  where
    (h, rest) = total `divMod` 3600
    (m, s) = rest `divMod` 60
```

- `where` 把輔助定義放在函式後面,最常用。
- 反引號把普通函式變中綴:``total `divMod` 3600``。
- `(h, m, s)` 是 **tuple**;`(h, rest) = ...` 同時做了**解構**。

## 不可變性

Haskell 沒有「變數重新賦值」。`x = 5` 是**定義**,不是賦值。
所有「改變」都是算出新值 —— 這正是之後遊戲狀態更新的模型:
每一幀都是 `oldWorld -> newWorld` 的純函式。

## 2026 提醒

- 整數除法用 `div`/`mod`(或 `divMod`),`/` 只給小數。
- 次方:`^` 給整數指數、`**` 給浮點指數。
- 負數當引數要加括號:`hitPoints 20 (-5)`。

## 習題

打開 `exercises/Exercises/E01Basics.hs`,完成後:

```powershell
cabal test level01-foundations
```

E01 區塊全綠即通關,前進第 2 章。
