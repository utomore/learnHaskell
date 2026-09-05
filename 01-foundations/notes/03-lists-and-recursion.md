# 第 3 章 — List、遞迴、Fold

## List 基礎

```haskell
ghci> [1, 2, 3]
[1,2,3]
ghci> 0 : [1, 2, 3]      -- (:) 把元素接到前面,讀作 "cons"
[0,1,2,3]
ghci> [1, 2] ++ [3, 4]   -- 串接
[1,2,3,4]
ghci> [1 .. 5]           -- 範圍
[1,2,3,4,5]
```

**`[1, 2, 3]` 就是 `1 : 2 : 3 : []` 的語法糖。**
list 只有兩種形狀:空(`[]`)或「一個頭接一條尾」(`x : xs`)——
所以 pattern matching 只需要兩個案例。

這個定義決定了 list 的效能特性:`:` 接在前面是 O(1),
`++` 接在後面要走完整條左邊的 list 是 O(n),取第 n 個元素也是 O(n)。
list 是**單向鏈結串列**,不是陣列 —— 把它當陣列用是效能問題的常見來源(本章末的表格)。

## 遞迴:list 的自然處理方式

```haskell
myLength :: [a] -> Int
myLength []       = 0
myLength (_ : xs) = 1 + myLength xs
```

結構是什麼形狀,遞迴就是什麼形狀。空的怎麼辦、頭+尾怎麼辦,寫完就結束。

這種「跟著資料結構的形狀寫」的遞迴叫**結構遞迴**,它保證會終止
(每次遞迴 list 都少一節)。你會發現第 4 章的樹、第 3 級的 GADT 全部都用同一招:
資料型別有幾個建構子,函式就有幾個案例。

## 但日常先用現成的高階函式

顯式遞迴是理解基礎,實務上多數 list 處理用三板斧:

```haskell
ghci> map (*2) [1, 2, 3]           -- 逐個轉換
[2,4,6]
ghci> filter (> 0) [10, 0, -3, 5]  -- 篩選
[10,5]
ghci> foldl' (+) 0 [1, 2, 3]       -- 聚合(見下)
6
```

組合起來就是資料管線:

```haskell
aliveCount :: [Int] -> Int
aliveCount = length . filter (> 0)
```

為什麼寧可用 `map`/`filter` 也不自己寫遞迴?因為讀的人看到 `map` 就知道
「長度不變、逐個轉換」,看到 `filter` 就知道「只會變少、元素不變」;
而看到手寫遞迴得從頭讀到尾才能確定它在幹嘛。命名的高階函式是**意圖的宣告**。

## fold:把 list 摺成一個值

**2026 鐵則:左摺一律用 `foldl'`(嚴格),不要用 `foldl`(惰性)。**

`foldl` 會把「還沒算的加法」堆成一座 thunk 山,大資料直接吃爆記憶體
(這叫 **space leak**,第 2 級會深入)。`foldl'` 每步都立刻算,O(1) 空間。
`foldl'` 從 base 4.20 起就在 Prelude 裡,直接用。

```haskell
totalDamage :: [Int] -> Int
totalDamage = foldl' (+) 0
```

### `foldl` 的三十年:為什麼一個公認的錯誤放了這麼久

`foldl (+) 0 [1,2,3]` 會展開成 `((0 + 1) + 2) + 3`。在惰性求值下,
它不會邊走邊加,而是先把整個運算式**建出來**再算 —— 一千萬個元素就是一千萬層括號,
每層是一個 thunk(第 2 級講)。這件事 1990 年代就有人知道,`foldl'` 也早在
`Data.List` 裡。那為什麼 Prelude 的 `foldl` 三十年不改?

1. **語意不同**:`foldl'` 每一步都強制求值,對某些含 `undefined` 或無限結構的奇怪程式,
   結果和 `foldl` 不一樣。Haskell 社群對「改變 Prelude 既有函式的語意」極度保守。
2. **要改 Prelude 得過 CLC**(Core Libraries Committee)提案流程,任何加東西到 Prelude
   都可能跟使用者自己定義的名字撞名,破壞既有程式。

最後的折衷是 base 4.20(GHC 9.10,2024 年):**把 `foldl'` 加進 Prelude**,
`foldl` 留著但不再推薦。所以你會看到:

- 舊教材(《Learn You a Haskell》、《Real World Haskell》)通篇 `foldl`。
- 稍新的程式碼 `import Data.List (foldl')`。
- 2026 的程式碼直接用 `foldl'`,不 import。

三種都認得,自己只寫最後一種。

### 親眼看差別

```haskell
ghci> :set +s                         -- 之後每行顯示時間與配置量
ghci> foldl (+) 0 [1..10^7]
50000005000000
(1.56 secs, 1,612,455,016 bytes)
ghci> foldl' (+) 0 [1..10^7]
50000005000000
(0.15 secs, 880,126,440 bytes)
```

十倍時間差(ghci 沒開最佳化,編譯後差距更誇張:`foldl` 版會直接吃光 stack 或記憶體)。
`bytes` 是總配置量不是峰值,但 `foldl` 版那多出來的 7 億 bytes 就是一千萬個 thunk。

### `foldr`:惰性、短路、建構

`foldr f z [1,2,3]` 展開成 `1 `f` (2 `f` (3 `f` z))` —— **從右邊結合**,
但求值是從左邊開始的:先算 `1 `f` (...)`,而 `f` 要不要看括號裡的東西,由 `f` 自己決定。
這讓 `foldr` 能處理無限 list:

```haskell
ghci> take 5 (foldr (\x acc -> x : acc) [] [1..])
[1,2,3,4,5]                                       -- 建到第 5 個就停
ghci> foldr (\x acc -> x > 3 || acc) False [1..]
True                                              -- 遇到 4 就短路,不看 acc
```

第二行:`4 > 3 || acc`,`||` 左邊已經 `True` 就不碰右邊,遞迴到此為止。
同樣的事拿 `foldl'` 做會永遠跑不完,因為它一定要先走到 list 尾。

選擇規則:

| 你要什麼 | 用 |
|---|---|
| 把 list 聚合成一個嚴格的值(總和、計數、Map) | `foldl'` |
| 建構新的 list / 可能短路 / 處理無限 list | `foldr` |
| `foldl`(無 `'`) | 不用 |

`map`、`filter`、`any`、`++` 在概念上都是 `foldr` 的特例(GHC 內部的 list fusion 也是靠把它們改寫成 `foldr` 來做的),這就是它們能在無限 list 上工作的原因。

## List comprehension

```haskell
ghci> [x * x | x <- [1 .. 10], even x]
[4,16,36,64,100]

-- 座標網格(之後遊戲地圖會用到)
ghci> [(x, y) | x <- [0 .. 2], y <- [0 .. 2]]
[(0,0),(0,1),(0,2),(1,0), ...]
```

comprehension 是 `map` + `filter` + 巢狀迴圈的語法糖,`|` 右邊由左到右讀:
「x 取 1 到 10,篩掉奇數,對剩下的算 x*x」。多個 `<-` 就是巢狀:
右邊的變數變得快,`[x * y | x <- [1..3], y <- [10,20]]` 得到 `[10,20,20,40,30,60]`。

## zip:平行配對

```haskell
ghci> zip [0 ..] "abc"          -- 惰性:無限 list 沒問題
[(0,'a'),(1,'b'),(2,'c')]
```

`[0 ..]` 是無限 list —— 因為 Haskell 是惰性求值,只會算用到的部分。
`zip [0 ..]` 是「幫每個元素編號」的慣用寫法,不需要 for 迴圈的計數器;
`zip` 遇到短的那邊結束就停。

## 你會看到的(不是)錯誤訊息

`foldl` 不會給你任何編譯錯誤或警告 —— 這正是它危險的地方。
它的症狀在執行期:

- 小資料一切正常,測試全綠。
- 資料一大,程式突然變慢、記憶體暴漲,最後 `stack overflow` 或被 OS 殺掉。

本章習題的 `totalDamage` 有一個一百萬元素的測試就是為了讓你「感覺」到差別;
第 2 級會教你用 `+RTS -s` 把這件事量出來。

另一個沒有錯誤訊息的陷阱是 `Int` 溢位(第 1 章):

```haskell
ghci> product [1..20 :: Int]
2432902008176640000
ghci> product [1..21 :: Int]
-4249290049419214848            -- 靜悄悄地錯了
ghci> product [1..21 :: Integer]
51090942171709440000
```

## ghci 實驗

```haskell
ghci> :t foldr                 -- Foldable t => (a -> b -> b) -> b -> t a -> b
ghci> :t foldl'                -- Foldable t => (b -> a -> b) -> b -> t a -> b
ghci> xs = map (*2) [1..5] :: [Int]
ghci> :sprint xs               -- xs = _            (還沒算:整條是一個 thunk)
ghci> length xs
5
ghci> :sprint xs               -- xs = [_,_,_,_,_]  (骨架算了,元素還沒)
ghci> sum xs
30
ghci> :sprint xs               -- xs = [2,4,6,8,10] (現在全算了)
```

`:sprint` 顯示一個值「目前算到哪」,`_` 是還沒兌現的 thunk。
注意 `foldr` 和 `foldl'` 的函式參數順序是相反的(`a -> b -> b` vs `b -> a -> b`):
`foldr` 的 accumulator 在右、`foldl'` 在左,跟展開後括號的方向一致。

## 淘汰品警告

| 淘汰 | 改用 | 為什麼 |
|------|------|------|
| `head` / `tail`(空 list 爆炸) | pattern matching 或 `safeHead :: [a] -> Maybe a` | 簽名說謊,見第 2 章 |
| `foldl` | `foldl'` | thunk 堆積,space leak |
| `xs !! n` 隨機存取 | `Vector`(第 3 級)或直接改演算法 | list 是鏈結串列,`!!` 是 O(n) |
| `length xs == 0` | `null xs` | `length` 要走完整條 list,無限 list 永不回來 |
| 把 list 當高效能容器 | list 是「迭代器/控制結構」;要索引查詢用 `Vector`、要鍵值用 `Map`(第 6 章起) | 每個元素三個指標的開銷 |

## 常見誤區

1. `xs ++ [x]` 在迴圈裡反覆做是 O(n²);先 `x : acc` 累積再 `reverse`。
2. `foldr` 不是「從右邊開始算」,是「從右邊結合」;它從左邊開始求值,所以能短路。
3. 想用 `foldl'` 處理無限 list → 永遠不會回來,因為它必須走到尾。
4. `[1 .. 10]` 的 `..` 兩邊養成留空格的習慣:左端是大寫名字時 `[False..True]` 會被讀成模組限定的運算子而編不過,`[False .. True]` 才對。
5. 遞迴忘了寫 base case(`[]` 那條)→ 非窮盡警告 + 執行期炸。

## 習題

`exercises/Exercises/E03Lists.hs` → `cabal test level01-foundations`

其中 `totalDamage` 有一個一百萬元素的測試 —— 用錯 fold 不會錯,但你會知道差別在哪(試著在 ghci 對比 `foldl` 與 `foldl'` 加總 `[1..10^7]`)。
