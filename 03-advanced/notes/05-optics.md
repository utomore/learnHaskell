# 第 5 章 — Optics:巢狀資料的存取器

## 問題:巢狀 record 更新很痛

```haskell
data Stats = Stats { hp :: Int, mp :: Int }
data Hero  = Hero  { name :: Text, stats :: Stats }
```

讀很舒服(`OverloadedRecordDot`):`hero.stats.hp`。
但**改**就原形畢露:

```haskell
takeDamage n hero = hero { stats = hero.stats { hp = hero.stats.hp - n } }
```

兩層就這樣,三層直接沒法看。optics(lens 家族)就是解這題的。

## Lens 不是魔法:一個型別,兩個小把戲

一個 lens = 「聚焦 s 裡的一個 a」。van Laarhoven 表示法:

```haskell
type Lens' s a = forall f. Functor f => (a -> f a) -> s -> f s
```

讀作:「給我一個對 a 動手腳的函式(包在任意 Functor 裡),
我還你對整個 s 動手腳的函式」。做一個 lens 只要 getter + setter:

```haskell
lens :: (s -> a) -> (s -> a -> s) -> Lens' s a
lens get put f s = put s <$> f (get s)
```

神奇的是,`view`(讀)和 `over`(改)是**選不同的 Functor** 變出來的:

```haskell
view l s   = getConst (l Const s)              -- Const:偷走 a,忽略改動
over l g s = runIdentity (l (Identity . g) s)  -- Identity:乖乖套用 g
```

`Const` 假裝要改、其實把焦點值帶出來;`Identity` 真的改。
整套 lens 就只是 `Functor` 的應用 —— Level 2 的抽象在這裡兌現。

## 最強性質:lens 用 `.` 就能組合

lens 是普通函式,所以函式合成就是 lens 合成:

```haskell
statsL :: Lens' Hero Stats
hpL    :: Lens' Stats Int

heroHpL :: Lens' Hero Int
heroHpL = statsL . hpL              -- 一路聚焦進去

takeDamage n = over heroHpL (max 0 . subtract n)   -- 巢狀更新一行
```

注意方向和 record dot 一致:`statsL . hpL` ≈ `.stats.hp`,由外而內。

## 生態系識讀(2026)

| 套件 | 定位 |
|------|------|
| `optics` | 現代推薦:錯誤訊息好、API 分層清楚(`view`/`set`/`%`) |
| `lens` | 老大哥:功能最全、依賴大、錯誤訊息難讀 |
| `microlens` | 極小依賴,函式庫作者常用 |

它們的核心都是你這章手寫的東西。日常讀值用 record dot 就好;
optics 的主場是**巢狀更新**、以及 lens 之外的家族成員:
`Traversal`(0..n 個焦點,就是 `traverse`!)、`Prism`(sum type 的分支)。

## 2026 實務準則

1. 讀值:record dot。巢狀更新:optics(或本章的手寫 lens)。
2. 新專案選 `optics`;讀舊碼要認得 `lens` 的 `^.` `%~` 符號。
3. getter/setter 定律:set 後 view 要拿回設的值 —— 測試會抽查。

## 習題

`exercises/Exercises/E05Optics.hs` —— 手刻迷你 lens 庫:
`lens`/`view`/`over`/`set`,做出 `statsL`、`hpL`,
用合成寫 `takeDamage`。
