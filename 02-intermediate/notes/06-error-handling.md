# 第 6 章 — 現代錯誤處理

## 兩類錯誤,兩種工具

| | 領域錯誤(預期中的失敗) | IO 例外(環境的背叛) |
|--|--|--|
| 例子 | 指令解析失敗、驗證不過、查無此人 | 檔案不存在、網路斷線、除以零 |
| 工具 | `Maybe` / `Either e` + **ADT 錯誤型別** | exception(`throwIO`/`try`/`catch`) |
| 出現在 | 型別簽名裡,呼叫端被迫處理 | 簽名看不到,在 IO 邊界攔截 |

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

**淘汰做法**:`Either String`(呼叫端只能比對字串)、
用 exception 表達業務失敗(簽名裡看不到,必炸)。

## IO 例外:在邊界收編

```haskell
import Control.Exception (IOException, try, throwIO)

safeReadFile :: FilePath -> IO (Either GameError Text)
safeReadFile path = do
  result <- try (TIO.readFile path)        -- try :: IO a -> IO (Either e a)
  pure $ case result of
    Left (_ :: IOException) -> Left (FileError (T.pack path))
    Right content -> Right content
```

模式:**exception 在 IO 邊界 `try` 起來,立刻轉成領域錯誤**,
讓程式其餘部分只面對 `Either GameError`。

丟例外用 `throwIO`(在 IO 裡,時序可預測),不要用 `throw`(純函式裡,
爆炸點取決於惰性求值,除錯地獄)。

## GHC 9.10+ 的新武器

- **例外註解與 backtrace**:未捕捉的例外現在自帶呼叫堆疊
  (`HasCallStack` 機制全面整合),不再是裸的一行錯誤訊息。
- 自訂例外型別實作 `Exception` class 即可 `throwIO`;
  需要清理資源用 `bracket`/`finally`(之後專案章會用到)。

## 反模式墓園(2026 不要這樣寫)

- **`ExceptT e IO`**:IO 本身就會丟例外,再包一層 `Either` 造成
  「兩套錯誤通道」,`catch` 不到 `Left`、`ExceptT` 接不到例外,
  資源清理極易寫錯。IO 邊界直接用例外 + `try`,純邏輯用 `Either`。
- 用 `error`/`undefined` 表達可預期的失敗(它們只該標記「程式寫錯了」)。
- `String` 當錯誤型別。

## 習題

`exercises/Exercises/E06Errors.hs`:完整走一遍
「解析指令(Either + ADT)→ 呈現錯誤 → 收編 IOException」。
