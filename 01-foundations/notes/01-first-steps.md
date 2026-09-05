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

「一切都是運算式」不是修辭,它決定了你怎麼寫程式:`if` 是運算式
(一定要有 `else`,因為它必須算出一個值)、`case` 是運算式、
後面會學的 `let`/`where` 也只是給運算式的子片段取名字。
沒有「先執行這行、再執行那行」的概念 —— 那是第 7 章 IO 的事。

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

### `Num a => a` 怎麼讀

```haskell
ghci> :t 3
3 :: Num a => a
ghci> :t 3 + 4
3 + 4 :: Num a => a
ghci> :t (3 :: Double)
(3 :: Double) :: Double
```

`=>` 左邊是**約束**、右邊是型別。`Num a => a` 讀作「任何屬於 `Num` 的型別 a 都行」:
字面值 `3` 還沒決定自己是 `Int` 還是 `Double`,要等有人告訴它。
`sqrt` 的簽名是 `Floating a => a -> a`,`div` 是 `Integral a => a -> a -> a`,
所以 `sqrt 3` 的 `3` 會變成浮點數、`3 `div` 2` 的 `3` 會變整數 —— 由用途決定身分。
如果到最後都沒人決定,ghci 會預設成 `Integer`(整數)或 `Double`(小數),
這叫 **defaulting**;寫進檔案的程式碼則會收到 `-Wtype-defaults` 警告提醒你。
第 5 章講 typeclass 時會回頭正式介紹 `Num`、`Floating` 這些約束是什麼。

### `Int` 與 `Integer`:選錯會靜悄悄地算錯

`Int` 是 64 位元機器整數,快但**會溢位**;`Integer` 想多大就多大,慢一點但永不溢位。

```haskell
ghci> maxBound :: Int
9223372036854775807
ghci> (2^63 :: Int)
-9223372036854775808        -- 溢位:繞回負數,沒有任何錯誤或警告
ghci> 2^63 :: Integer
9223372036854775808         -- Integer 正確
```

2026 的選法:計數、索引、HP、金幣這類「不會破 9×10¹⁸」的用 `Int`;
階乘、大數運算、密碼學用 `Integer`。溢位不會報錯是機器整數的天性,
不是 Haskell 的缺陷,但你必須知道它存在。

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

### 型別推斷:能不寫簽名,為什麼還是要寫?

Haskell 的型別系統會自己**推斷**型別。你不寫簽名,編譯器照樣算得出來:

```haskell
ghci> noSig x = x * 2 + 1
ghci> :t noSig
noSig :: Num a => a -> a
```

它從 `*` 和 `+` 推出「x 必須是某種數字」,而且只推到**最寬的**型別
(任何 `Num`),不會替你猜 `Int`。這麼強的推斷是 Hindley–Milner 型別系統的能力,
Java/C++ 那種「宣告了型別才知道型別」的語言做不到。

那為什麼社群還是要求頂層函式**一律寫簽名**?

1. **簽名是文件**:讀程式的人第一眼看簽名,不看實作。
2. **錯誤訊息會變好**:沒有簽名時,一個打錯的地方會讓推斷結果「傳染」到整個函式,
   錯誤報在離真正錯誤很遠的行;有簽名時錯誤會停在簽名和實作衝突的那一行。
3. **你想要的型別常比推斷出來的窄**:`noSig` 推出來對所有 `Num` 成立,
   但你可能只想給 `Int` 用,寫死簽名可以擋掉誤用(也讓 GHC 產生更快的專用程式碼)。

`-Wall`(本專案已開)會對每個沒簽名的頂層定義發 `-Wmissing-signatures` 警告。
ghci 裡臨時實驗才省略簽名。

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

這件事在其他語言常被當成限制,在 Haskell 是**推理的基礎**:
`x` 在整段程式裡永遠是同一個值,所以你可以放心把任何 `x` 換成它的定義
(或反過來),程式意義不變。這叫 referential transparency,
第 2 級的每一條 law、第 3 級的每一次重構都建立在它上面。

## 你會看到的錯誤訊息

第一天最常撞到的一個:負數當引數忘了加括號。

```haskell
main = print (hitPoints 20 -5)
```

```
Ch1.hs:5:28: error: [GHC-39999]
    • No instance for ‘Num (Int -> Int)’ arising from a use of ‘-’
      (maybe you haven't applied a function to enough arguments?)
    • In the first argument of ‘print’, namely ‘(hitPoints 20 - 5)’
```

怎麼讀:

- `[GHC-39999]` 是錯誤代碼,可以貼到 https://errors.haskell.org 查完整解說。
- 第一個 `•` 是**問題本身**:GHC 把你的程式讀成 `(hitPoints 20) - 5`,
  `hitPoints 20` 是一個「還差一個引數的函式」(型別 `Int -> Int`),
  而 `-` 要求兩邊都是數字,所以它在找 `Num (Int -> Int)` 這個 instance,當然沒有。
- 括號裡的提示(`maybe you haven't applied a function to enough arguments?`)
  就是正解:看到 `No instance for (Num (X -> Y))` 或 `(Show (X -> Y))`,
  九成是**函式少餵了引數**或**負數沒加括號**。
- 第二個 `•` 之後是**位置脈絡**:錯誤發生在 `print` 的第一個引數裡。

修法:`hitPoints 20 (-5)`。

## ghci 實驗

```haskell
ghci> :t max               -- max :: Ord a => a -> a -> a
ghci> :t max 0             -- max 0 :: (Ord a, Num a) => a -> a   (只餵一個引數也合法!)
ghci> :t sqrt              -- sqrt :: Floating a => a -> a
ghci> :t div               -- div :: Integral a => a -> a -> a
ghci> 7 / 2                -- 3.5
ghci> 7 `div` 2            -- 3
ghci> maxBound :: Int      -- 9223372036854775807
```

`max 0` 這行值得停一下:餵一個引數就回你一個函式,這就是第 2 章要講的柯里化。

## 常見誤區

1. `sqrt 3 + 4` 是 `(sqrt 3) + 4`,不是 `sqrt (3 + 4)` —— 函式套用永遠先算。
2. `if` 沒有 `else` 是語法錯誤:`if` 是運算式,兩條路都要有值。
3. `Int` 溢位不會報錯;算階乘、大乘積請用 `Integer`。
4. `x = x + 1` 在 Haskell 是「x 定義成 x 加一」的無限遞迴,不是「把 x 加一」。
5. 沒寫簽名 GHC 不會拒絕你,但 `-Wall` 會唸;把它當成「你還沒想清楚這個函式要什麼型別」的訊號。

## 2026 提醒

- 整數除法用 `div`/`mod`(或 `divMod`),`/` 只給小數。
- 次方:`^` 給整數指數、`**` 給浮點指數。
- 負數當引數要加括號:`hitPoints 20 (-5)`。
- 頂層函式一律寫簽名;`Int`/`Integer` 依「會不會超過 9×10¹⁸」選。

## 習題

打開 `exercises/Exercises/E01Basics.hs`,完成後:

```powershell
cabal test level01-foundations
```

E01 區塊全綠即通關,前進第 2 章。
