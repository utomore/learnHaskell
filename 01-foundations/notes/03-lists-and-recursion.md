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

## 遞迴:list 的自然處理方式

```haskell
myLength :: [a] -> Int
myLength []       = 0
myLength (_ : xs) = 1 + myLength xs
```

結構是什麼形狀,遞迴就是什麼形狀。空的怎麼辦、頭+尾怎麼辦,寫完就結束。

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

## fold:把 list 摺成一個值

**2026 鐵則:左摺一律用 `foldl'`(嚴格),不要用 `foldl`(惰性)。**

`foldl` 會把「還沒算的加法」堆成一座 thunk 山,大資料直接吃爆記憶體
(這叫 **space leak**,第 2 級會深入)。`foldl'` 每步都立刻算,O(1) 空間。
`foldl'` 從 base 4.20 起就在 Prelude 裡,直接用。

```haskell
totalDamage :: [Int] -> Int
totalDamage = foldl' (+) 0
```

`foldr` 則用於惰性/短路的場合(例如 `any`、建構新 list)——現在先知道有這回事即可。

## List comprehension

```haskell
ghci> [x * x | x <- [1 .. 10], even x]
[4,16,36,64,100]

-- 座標網格(之後遊戲地圖會用到)
ghci> [(x, y) | x <- [0 .. 2], y <- [0 .. 2]]
[(0,0),(0,1),(0,2),(1,0), ...]
```

## zip:平行配對

```haskell
ghci> zip [0 ..] "abc"          -- 惰性:無限 list 沒問題
[(0,'a'),(1,'b'),(2,'c')]
```

`[0 ..]` 是無限 list —— 因為 Haskell 是惰性求值,只會算用到的部分。

## 淘汰品警告

| 淘汰 | 改用 |
|------|------|
| `head` / `tail`(空 list 爆炸) | pattern matching 或 `safeHead :: [a] -> Maybe a` |
| `foldl` | `foldl'` |
| 把 list 當高效能容器 | list 是「迭代器/控制結構」;要索引查詢用 `Vector`、要鍵值用 `Map`(第 6 章起) |

## 習題

`exercises/Exercises/E03Lists.hs` → `cabal test level01-foundations`

其中 `totalDamage` 有一個一百萬元素的測試 —— 用錯 fold 不會錯,但你會知道差別在哪(試著在 ghci 對比 `foldl` 與 `foldl'` 加總 `[1..10^7]`)。
