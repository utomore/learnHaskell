# 第 6 章 — 現代錯誤處理

## 兩類錯誤,兩種工具

| | 領域錯誤(預期中的失敗) | IO 例外(環境的背叛) |
|--|--|--|
| 例子 | 指令解析失敗、驗證不過、查無此人 | 檔案不存在、網路斷線、除以零 |
| 工具 | `Maybe` / `Either e` + **ADT 錯誤型別** | exception(`throwIO`/`try`/`catch`) |
| 出現在 | 型別簽名裡,呼叫端被迫處理 | 簽名看不到,在 IO 邊界攔截 |

判斷標準只有一個:**呼叫端有沒有合理的方式處理它?** 「玩家輸入了不存在的指令」
呼叫端當然要處理 → 領域錯誤,放進型別。「硬碟壞了」呼叫端能做的只有記錄然後放棄
→ 例外,讓它往外冒到有能力處理的地方。

## 領域錯誤:Either + ADT

```haskell
data GameError
  = UnknownCommand Text
  | BadArguments Text
  | FileError Text
  deriving stock (Eq, Show)

parseCommand :: Text -> Either GameError Command
```

錯誤是 ADT,所以:呼叫端能 pattern match 分別處理、
編譯器檢查你沒漏案例、加新錯誤種類時所有處理點自動現形。

### 舊做法 → 新做法:`Either String`

2000 年代的教材與函式庫大量使用 `Either String a`——當年 `Text` 還不存在
(2009 年才有),而 `String` 是唯一順手的錯誤載體。問題:

- 呼叫端只能拿字串比對(`if err == "not found"`),改一個字整個程式默默壞掉。
- 無法列舉「這個函式可能出哪幾種錯」,文件與程式碼永遠不同步。
- 多個模組的錯誤混在一起無法分辨來源。

現在你還會在 `Text.Read.readEither`、一些老解析器庫看到 `Either String`。
接到它的第一件事:在你的模組邊界把它轉成你的 ADT
(`first ParseFailed (readEither s)`),不要讓 `String` 錯誤流進核心邏輯。
同理,**用 exception 表達業務失敗**(簽名看不到,必炸)也是舊習慣,
來自 Java/C# 的 checked/unchecked exception 直覺。

## IO 例外:在邊界收編

```haskell
import Control.Exception (IOException, try, throwIO)

safeReadFile :: FilePath -> IO (Either GameError Text)
safeReadFile path = do
  result <- try @IOException (TIO.readFile path)   -- try :: IO a -> IO (Either e a)
  pure $ case result of
    Left e -> Left (FileError (T.pack (displayException e)))
    Right content -> Right content
```

```haskell
ghci> safeReadFile "does-not-exist.txt"
Left (FileError "does-not-exist.txt: openFile: does not exist (No such file or directory)")
```

模式:**exception 在 IO 邊界 `try` 起來,立刻轉成領域錯誤**,
讓程式其餘部分只面對 `Either GameError`。

`try @IOException` 的 `@` 是 **TypeApplications**(GHC2024 內建):
直接告訴 `try` 要抓哪一種例外。舊寫法是在 pattern 上標型別
`Left (e :: IOException)`,兩種都合法,`@` 版本一眼就看到意圖。

丟例外用 `throwIO`(在 IO 裡,時序可預測),不要用 `throw`(純函式裡,
爆炸點取決於惰性求值,除錯地獄)。

## 例外的完整工具箱

### 自訂例外型別

一個 `data` 加一個 instance 就是例外:

```haskell
data GameException
  = SaveCorrupted FilePath
  | AssetMissing Text
  deriving stock Show

instance Exception GameException where
  displayException (SaveCorrupted p) = "存檔損毀:" <> p
  displayException (AssetMissing a)  = "找不到資源:" <> T.unpack a
```

```haskell
ghci> r <- try @GameException (throwIO (AssetMissing "slime.png"))
ghci> case r of Left e -> putStrLn (show e) >> putStrLn (displayException e)
AssetMissing "slime.png"        -- show:給程式看的
找不到資源:slime.png            -- displayException:給人看的
```

**`displayException` 而不是 `show`**:`show` 的合約是「印出能重建值的 Haskell 語法」,
不是給使用者讀的。2026 的慣例是例外型別實作 `displayException`,
log 與錯誤畫面用它;GHC 9.10 起未捕捉例外的預設輸出也改用它。

### `SomeException`:例外的總根

所有例外都能塞進 `SomeException`(它是一個存在型別的包裝)。
`try @SomeException` 就是「什麼都抓」——**只該出現在最外層**
(main、執行緒進入點),用來記錄後放棄。中間層什麼都抓會吞掉
你不該處理的東西,例如 async 章的執行緒取消訊號。

### `bracket` / `finally`:資源一定要釋放

```haskell
bracket :: IO a -> (a -> IO b) -> (a -> IO c) -> IO c
--         取得      釋放           使用
```

```haskell
bracket
  (putStrLn "開檔" >> pure "handle")
  (\_ -> putStrLn "關檔(例外也會跑到這裡)")
  (\_ -> putStrLn "使用中..." >> throwIO (ErrorCall "讀到一半炸了"))
```

輸出:

```
開檔
使用中...
關檔(例外也會跑到這裡)
```

釋放動作在例外時**照跑**,這是 `withFile`、資料庫連線、鎖的實作基礎;
`finally` 是不需要「取得」那一步的簡化版:`work `finally` cleanup`。
自己手寫 `openFile`/`hClose` 配對是淘汰做法——中間任何一行丟例外,handle 就漏了。

### `evaluate`:讓純程式碼的錯誤在可預測的地方爆

```haskell
evaluate :: a -> IO a
```

純函式裡的 `error`、除以零是惰性的,`try (pure (1 `div` 0))` **抓不到**——
`pure` 根本沒去算它,例外會在稍後 `print` 時才爆。
`try (evaluate (1 `div` 0))` 才會在這一行把它算出來、抓到:

```haskell
ghci> r <- try @SomeException (evaluate (1 `div` 0 :: Int))
ghci> r
Left divide by zero
```

規律:**`try` 包純運算,一定配 `evaluate`**(要連內部都算完就 `evaluate (force x)`)。

## GHC 9.10 之後:例外自帶呼叫堆疊

未捕捉的例外以前只有一行 `prog: Boom "hi"`,你得猜是哪裡丟的。
從 GHC 9.10 開始,`throwIO`/`throw` 的型別多了 `HasCallStack`,
執行期會把堆疊一起印出來(GHC 9.14.1 的真實輸出):

```
p3.exe: Uncaught exception main:Main.Boom:

Boom "hi"

HasCallStack backtrace:
  throwIO, called at app\Probe3.hs:6:8 in main:Main
```

第一行是例外**型別**的完整名稱(套件:模組.型別)、中間是 `displayException` 的內容、
最後是丟出點。這套機制叫 **exception context / annotation**
(`Control.Exception.Context`、`Control.Exception.Annotation` 模組),
例外在往外傳的過程中可以被附加更多上下文。本課程你只需要會讀輸出;
自己的例外型別寫好 `displayException`,堆疊 GHC 會幫你附上。

## 反模式墓園(2026 不要這樣寫)

### `ExceptT e IO`:兩套錯誤通道

**它為什麼曾經流行**:2010 年代的 mtl 教學把「錯誤」當成一種效果,
`ExceptT` 是 transformer 家族裡處理錯誤的那一個;把它疊在 `IO` 上,
看起來就能「在型別裡看見錯誤」。很多教材與早期 servant/persistent 範例都這樣寫。

**具體壞在哪**:IO 本身就會丟例外,再包一層 `Either` 造成兩套通道:

```haskell
loadSave :: FilePath -> ExceptT GameError IO Save
loadSave path = do
  raw <- liftIO (TIO.readFile path)   -- 檔案不存在 → IOException,ExceptT 接不到
  case parseSave raw of
    Left e  -> throwError e           -- 解析失敗 → Left,catch 抓不到
    Right s -> pure s
```

呼叫端 `runExceptT (loadSave p)` 拿到 `Right`/`Left` 以為處理完了,
結果 `IOException` 從旁邊飛出去;反過來用 `try` 包它,又抓不到 `Left`。
更糟的是 `bracket` 只認例外:`ExceptT` 的 `Left` 會**正常**經過 `bracket`
的釋放段——但你要是在 `ExceptT` 上自己寫 `bracket` 變體,順序一錯資源就漏。

**社群何時轉向**:2017 年 Michael Snoyman(FP Complete)的
*The ReaderT Design Pattern* 與 *Exceptions Best Practices* 兩篇文章明確主張
「IO 裡的錯誤就用例外,不要 `ExceptT`」,之後成為主流共識。
2026 的分工:**IO 邊界直接用例外 + `try`,純邏輯用 `Either`**;
兩者在邊界處相接(本章的 `safeReadFile` 就是接點)。

### 其他

- 用 `error`/`undefined` 表達可預期的失敗(它們只該標記「程式寫錯了」)。
- `String` 當錯誤型別。
- 純函式裡 `throw`。
- 中間層 `catch` 全部例外(`SomeException`)然後吞掉。

## 你會看到的錯誤訊息

`try` 沒說要抓哪種例外:

```haskell
safeRead path = do
  r <- try (TIO.readFile path)
  pure $ case r of
    Left _ -> Nothing
    Right t -> Just t
```

```
E6.hs:7:8: error: [GHC-39999]
    • Ambiguous type variable ‘e0’ arising from a use of ‘try’
      prevents the constraint ‘(Exception e0)’ from being solved.
      Probable fix: use a type annotation to specify what ‘e0’ should be.
    • In a stmt of a 'do' block: r <- try (TIO.readFile path)
```

怎麼讀:`try :: Exception e => IO a -> IO (Either e a)`,`e` 由你決定;
你用 `Left _` 什麼都沒說,GHC 不知道你要抓 `IOException`、`ArithException`
還是全部。`Ambiguous type variable ... Exception e0` 這句話幾乎永遠對應
「`try` 少了型別」。修法:`try @IOException (...)`,或 `Left (_ :: IOException)`。

## ghci 實驗

```haskell
ghci> import Control.Exception
ghci> :t try
try :: Exception e => IO a -> IO (Either e a)
ghci> :t bracket
bracket :: IO a -> (a -> IO b) -> (a -> IO c) -> IO c
ghci> :t evaluate
evaluate :: a -> IO a
ghci> try @ArithException (evaluate (1 `div` 0 :: Int))
Left divide by zero
ghci> try @ArithException (evaluate (10 `div` 2 :: Int))
Right 5
```

## 常見誤區

- **`try (pure x)` 想抓純運算的錯。** 抓不到,要 `evaluate`。
- **`try @SomeException` 放在中間層。** 會吞掉取消訊號與你不懂的例外,只放最外層。
- **例外型別只 derive `Show` 不寫 `displayException`。** 使用者會看到 `AssetMissing "slime.png"` 這種 Haskell 語法。
- **在 `Either` 上疊 `ExceptT` 想「統一」錯誤。** 兩套通道,見上。
- **把「找不到玩家」寫成例外。** 那是領域錯誤,呼叫端要處理,放進 `Either`。

## 習題

`exercises/Exercises/E06Errors.hs`:完整走一遍
「解析指令(Either + ADT)→ 呈現錯誤 → 收編 IOException」。
