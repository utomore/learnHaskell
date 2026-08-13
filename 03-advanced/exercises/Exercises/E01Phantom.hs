-- | 第 1 章習題:Phantom types 與 DataKinds
--
-- 把 undefined 換成實作 → cabal test level03-advanced
module Exercises.E01Phantom
  ( Id (..)
  , Player
  , Monster
  , nextId
  , TempUnit (..)
  , Temp (..)
  , toFahrenheit
  , Raw
  , Validated
  , PlayerName (..)
  , validateName
  , greet
  ) where

import Data.Text (Text)
import Data.Text qualified as T

-- | 帶 phantom 標籤的 ID:執行期只是一個 Int,標籤只活在型別裡。
newtype Id entity = Id Int
  deriving stock (Eq, Ord, Show)

-- | 空型別:沒有值,純標籤。
data Player

data Monster

-- | 產生下一個 ID(裡面的數字 +1)。
-- 注意型別:Player 的下一個還是 Player 的,標籤不會弄丟。
nextId :: Id e -> Id e
nextId = undefined

-- | 溫度單位,經 DataKinds 升級後可當型別層級的標籤用。
data TempUnit = Celsius | Fahrenheit

-- | 帶單位的溫度。u 的 kind 是 TempUnit,只能是 'Celsius 或 'Fahrenheit。
newtype Temp (u :: TempUnit) = Temp Double
  deriving stock (Eq, Show)

-- | 攝氏轉華氏:F = C * 9/5 + 32。
-- 型別保證你不可能把華氏溫度再轉一次。
toFahrenheit :: Temp 'Celsius -> Temp 'Fahrenheit
toFahrenheit = undefined

-- | 驗證狀態標籤。
data Raw

data Validated

-- | 玩家名字,s 記錄「驗證過了沒」。
newtype PlayerName s = PlayerName Text
  deriving stock (Eq, Show)

-- | parse, don't validate:驗證通過就換標籤。
-- 規則:先 T.strip;結果非空,否則 Left "名字不能為空";
-- 長度 <= 12,否則 Left "名字太長"。
validateName :: PlayerName Raw -> Either Text (PlayerName Validated)
validateName = undefined

-- | 只接受驗證過的名字 —— 型別就是文件。
-- 輸出:"歡迎," <> 名字 <> "!"
greet :: PlayerName Validated -> Text
greet = undefined
