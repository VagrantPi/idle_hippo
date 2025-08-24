# 📋 Idle Hippo 配置參數說明

本文件說明 Idle Hippo 遊戲中所有配置檔案的參數結構與用途。

當需要新增新變數時，請先檢閱有沒有既有相關設定了。

## 📁 配置檔案結構

```
assets/config/
├── game.json          # 遊戲全域設定
├── equipments.json    # 裝備資料配置
├── pets.json          # 寵物資料配置
├── titles.json        # 稱號資料配置
└── quests.json        # 任務資料配置
```

---

## 🎮 game.json - 遊戲全域設定

### 參數說明

| 參數 | 類型 | 說明 | 預設值 |
|------|------|------|--------|
| `tap.base` | number | 基礎點擊收益 | 1 |
| `tap.base_gain` | number | 基礎點擊增益倍率 | 0.5 |
| `tap.daily_cap_base` | number | 每日點擊上限（基礎值） | 200 |
| `tap.daily_cap_ad_multiplier` | number | 廣告翻倍倍率（影響當日上限） | 2 |
| `idle.base_per_sec` | number | 基礎放置收益（每秒） | 0.0 |
| `ui.theme` | string | UI 主題色彩 | "green" |
| `ui.showDebugPanel` | boolean | 是否顯示除錯面板 | true |
| `character.animation` | object | 角色動畫設定 | - |
| `character.animation.swing` | object | 搖擺動畫設定 | - |
| `character.animation.swing.duration` | number | 動畫持續時間(毫秒) | 300 |
| `character.animation.swing.angle` | number | 搖擺角度(度) | 0.5 |
| `character.animation.move` | object | 移動動畫設定 | - |
| `character.animation.move.duration` | object | 移動動畫時間範圍 | - |
| `character.animation.move.duration.min` | number | 最小持續時間(秒) | 2 |
| `character.animation.move.duration.max` | number | 最大持續時間(秒) | 5 |
| `character.animation.move.range` | object | 移動範圍(像素) | - |
| `character.animation.move.range.x` | number | X軸移動範圍 | 80 |
| `character.animation.move.range.y` | number | Y軸移動範圍 | 80 |

### 範例配置

```json
{
  "tap": {
    "base": 1,
    "base_gain": 0.5,
    "daily_cap_base": 200,
    "daily_cap_ad_multiplier": 2
  },
  "idle": {
    "base_per_sec": 0.0
  },
  "ui": {
    "theme": "green",
    "showDebugPanel": true
  }
}
```

---

## ⚔️ equipments.json - 裝備資料配置

### 參數說明

| 參數 | 類型 | 說明 | 範例值 |
|------|------|------|--------|
| `id` | string | 裝備唯一識別碼 | "weapon_001" |
| `name` | string | 裝備顯示名稱 | "基礎武器" |
| `type` | string | 裝備類型 | "weapon", "armor" |
| `boost_type` | string | 加成類型 | "tap_multiplier", "idle_multiplier" |
| `base_boost` | number | 基礎加成倍率 | 1.5 |
| `upgrade_cost` | number | 升級消耗 | 100 |
| `upgrade_multiplier` | number | 升級倍率 | 1.2 |

### 範例配置

```json
{
  "equipments": [
    {
      "id": "weapon_001",
      "name": "基礎武器",
      "type": "weapon",
      "boost_type": "tap_multiplier",
      "base_boost": 1.5,
      "upgrade_cost": 100,
      "upgrade_multiplier": 1.2
    },
    {
      "id": "armor_001", 
      "name": "基礎護甲",
      "type": "armor",
      "boost_type": "idle_multiplier",
      "base_boost": 1.3,
      "upgrade_cost": 150,
      "upgrade_multiplier": 1.15
    }
  ]
}
```

---

## 🦛 pets.json - 寵物資料配置

### 參數說明

| 參數 | 類型 | 說明 | 範例值 |
|------|------|------|--------|
| `id` | string | 寵物唯一識別碼 | "hippo_001" |
| `name` | string | 寵物顯示名稱 | "小河馬" |
| `rarity` | string | 稀有度 | "common", "rare", "epic", "legendary" |
| `initial_idle_income` | number | 初始放置收益 | 0.5 |
| `upgrade_rules.cost_base` | number | 升級基礎消耗 | 50 |
| `upgrade_rules.cost_multiplier` | number | 升級消耗倍率 | 1.1 |
| `upgrade_rules.income_multiplier` | number | 收益增長倍率 | 1.2 |

### 範例配置

```json
{
  "pets": [
    {
      "id": "hippo_001",
      "name": "小河馬",
      "rarity": "common",
      "initial_idle_income": 0.5,
      "upgrade_rules": {
        "cost_base": 50,
        "cost_multiplier": 1.1,
        "income_multiplier": 1.2
      }
    }
  ]
}
```

---

## 🏆 titles.json - 稱號資料配置

### 參數說明

| 參數 | 類型 | 說明 | 範例值 |
|------|------|------|--------|
| `id` | string | 稱號唯一識別碼 | "title_001" |
| `name` | string | 稱號顯示名稱 | "河馬新手" |
| `unlock_condition.type` | string | 解鎖條件類型 | "total_taps", "idle_time_hours" |
| `unlock_condition.value` | number | 解鎖條件數值 | 100 |
| `display_text` | string | 稱號描述文字 | "初來乍到的河馬訓練師" |

### 解鎖條件類型

- `total_taps`: 總點擊次數
- `idle_time_hours`: 放置時間（小時）
- `total_income`: 總收益
- `equipment_upgrades`: 裝備升級次數

### 範例配置

```json
{
  "titles": [
    {
      "id": "title_001",
      "name": "河馬新手",
      "unlock_condition": {
        "type": "total_taps",
        "value": 100
      },
      "display_text": "初來乍到的河馬訓練師"
    }
  ]
}
```

---

## 📋 quests.json - 主線任務配置

### 參數說明

| 參數 | 類型 | 說明 | 範例值 |
|------|------|------|--------|
| `id` | string | 任務唯一識別碼 | "stage1" |
| `title` | string | 任務階段標題 | "新生階段" |
| `requirements.tapCount` | number | 累積點擊次數需求 | 10 |
| `requirements.memePoints` | number | 累積迷因點數需求 | 50 |
| `rewards` | array | 獎勵陣列 | - |
| `rewards[].type` | string | 獎勵類型 | "equipment", "system", "skin" |
| `rewards[].id` | string | 獎勵識別碼 | "youtube", "title", "skin1" |

### 獎勵類型說明

- `equipment`: 解鎖裝備，id 對應裝備識別碼
- `system`: 解鎖系統功能，id 可為 "title"（稱號系統）或 "pet"（寵物系統）
- `skin`: 解鎖河馬造型，id 對應造型識別碼

### 主線任務階段

主線任務共分為 6 個階段，每個階段都有累積性的要求：

1. **新生階段**: 10 次點擊 + 50 迷因點數 → 解鎖 YouTube 裝備
2. **迷因小菜鳥階段**: 50 次點擊 + 500 迷因點數 → 解鎖稱號系統
3. **動物迷因階段**: 300 次點擊 + 5000 迷因點數 → 解鎖寵物系統
4. **梗圖河馬階段**: 1000 次點擊 + 20000 迷因點數 → 解鎖造型 1
5. **迷因巨星階段**: 3000 次點擊 + 50000 迷因點數 → 解鎖造型 2
6. **宇宙級迷因之神**: 5000 次點擊 + 100000 迷因點數 → 解鎖造型 3

### 範例配置

```json
{
  "quests": [
    {
      "id": "stage1",
      "title": "新生階段",
      "requirements": {
        "tapCount": 10,
        "memePoints": 50
      },
      "rewards": [
        {
          "type": "equipment",
          "id": "youtube"
        }
      ]
    },
    {
      "id": "stage2",
      "title": "迷因小菜鳥階段",
      "requirements": {
        "tapCount": 50,
        "memePoints": 500
      },
      "rewards": [
        {
          "type": "system",
          "id": "title"
        }
      ]
    }
  ]
}
```

### 進度追蹤

主線任務進度會持久化保存在 GameState 中：

- `mainQuest.currentStage`: 當前階段（1-6）
- `mainQuest.tapCountProgress`: 累積點擊次數
- `mainQuest.memePointsEarned`: 累積迷因點數
- `mainQuest.unlockedRewards`: 已解鎖獎勵列表

---

## 🔧 ConfigService 使用方式

### 取得配置值

```dart
final configService = ConfigService();

// 取得基礎點擊收益
final tapBase = configService.getValue('game.tap.base', defaultValue: 1);

// 取得裝備資料
final equipments = configService.getValue('equipments.equipments', defaultValue: []);

// 取得寵物初始收益
final petIncome = configService.getValue('pets.pets.0.initial_idle_income', defaultValue: 0.0);
```

### 路徑格式

配置路徑使用點號分隔，支援巢狀物件與陣列索引：

- `game.tap.base` → 遊戲基礎點擊收益
- `equipments.equipments.0.name` → 第一個裝備的名稱
- `pets.pets` → 所有寵物陣列

---

## 📝 配置修改指南

### 1. 數值平衡調整

修改 `game.json` 中的基礎數值：

```json
{
  "tap": {
    "base": 2,                  // 提高點擊收益
    "daily_cap_base": 300       // 增加每日點擊上限
  },
  "idle": {"base_per_sec": 0.2} // 提高放置收益
}
```

### 2. 新增裝備

在 `equipments.json` 中新增裝備項目：

```json
{
  "id": "weapon_002",
  "name": "強化武器",
  "type": "weapon",
  "boost_type": "tap_multiplier",
  "base_boost": 2.0,
  "upgrade_cost": 200,
  "upgrade_multiplier": 1.3
}
```

### 3. 配置驗證

- 所有 `id` 必須唯一
- 數值類型必須正確（number/string/boolean）
- 必填欄位不可省略
- JSON 格式必須有效

---

## 🚨 注意事項

1. **Hot Reload 支援**: 修改配置檔案後可透過 Debug 面板重新載入
2. **錯誤處理**: ConfigService 會自動處理缺失的 key，回傳預設值
3. **版本控制**: 建議在 `version` 欄位記錄配置版本
4. **備份**: 修改前建議備份原始配置檔案

---

## 🆕 每日上限與廣告翻倍（Step 6）

- `tap.daily_cap_base`：定義當日可由點擊獲得的基礎上限。
- `tap.daily_cap_ad_multiplier`：當日一次性看廣告後的上限倍率（例如 2 → 上限翻倍）。

範例：

```json
{
  "tap": {
    "base": 1,
    "base_gain": 0.5,
    "daily_cap_base": 200,
    "daily_cap_ad_multiplier": 2
  }
}
```

---

## pets.json

寵物系統配置檔案，定義寵物種類、稀有度、基礎屬性及升級參數。

### 結構說明

```json
{
  "pets": [
    {
      "id": "寵物種類ID",
      "name": "寵物名稱",
      "image": "寵物圖片路徑",
      "rarities": {
        "稀有度名稱": {
          "rarity": "稀有度代碼",
          "baseIdlePerSec": "基礎放置收益/秒"
        }
      }
    }
  ],
  "upgrade": {
    "levelUpUpgradeBase": "等級升級基礎加成",
    "levelUpUpgradeDecayLevels": "加成衰減間隔等級",
    "levelUpUpgradeDecayRate": "加成衰減率"
  }
}
```

### 參數說明

#### pets 陣列
- **id**: 寵物種類的唯一識別碼
- **name**: 寵物的顯示名稱
- **image**: 寵物圖片的資源路徑
- **rarities**: 該寵物種類的所有稀有度變體

#### rarities 物件
- **rarity**: 稀有度代碼 (RR, R, S, SR, SSR)
- **baseIdlePerSec**: 該稀有度的基礎放置收益每秒數值

#### upgrade 物件
- **levelUpUpgradeBase**: 每級升級的基礎加成倍率 (預設: 0.5)
- **levelUpUpgradeDecayLevels**: 每隔多少等級進行加成衰減 (預設: 10)
- **levelUpUpgradeDecayRate**: 加成衰減的倍率 (預設: 0.5)

### 稀有度系統

寵物系統支援五種稀有度等級：
- **RR** (普通): 灰色 (#808080)
- **R** (稀有): 綠色 (#00FF00)
- **S** (超稀有): 藍色 (#0000FF)
- **SR** (史詩): 紫色 (#800080)
- **SSR** (傳說): 紅色 (#FF0000)

### 升級機制

寵物升級採用費氏數列計算升級點數需求：
- Level 1→2: 需要 1 點
- Level 2→3: 需要 1 點
- Level 3→4: 需要 2 點
- Level 4→5: 需要 3 點
- Level 5→6: 需要 5 點
- 以此類推...

### 等級加成計算

寵物等級提供的放置收益加成計算公式：
```
當前收益 = 基礎收益 × (1 + 總加成)
總加成 = Σ(每級加成)
每級加成 = 基礎加成 × (衰減率 ^ (等級 ÷ 衰減間隔))
```

### 使用範例

```json
{
  "pets": [
    {
      "id": "MooDeng",
      "name": "彈跳豬 MooDeng",
      "image": "assets/images/pets/moodeng.png",
      "rarities": {
        "RR": {
          "rarity": "RR",
          "baseIdlePerSec": 5.0
        },
        "R": {
          "rarity": "R", 
          "baseIdlePerSec": 10.0
        },
        "S": {
          "rarity": "S",
          "baseIdlePerSec": 20.0
        },
        "SR": {
          "rarity": "SR",
          "baseIdlePerSec": 40.0
        },
        "SSR": {
          "rarity": "SSR",
          "baseIdlePerSec": 80.0
        }
      }
    }
  ],
  "upgrade": {
    "levelUpUpgradeBase": 0.5,
    "levelUpUpgradeDecayLevels": 10,
    "levelUpUpgradeDecayRate": 0.5
  }
}
```

---

*最後更新: 2025-08-25*
