# 📋 Idle Hippo 配置參數說明

本文件說明 Idle Hippo 遊戲中所有配置檔案的參數結構與用途。

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

## 📋 quests.json - 任務資料配置

### 參數說明

| 參數 | 類型 | 說明 | 範例值 |
|------|------|------|--------|
| `id` | string | 任務唯一識別碼 | "quest_001" |
| `name` | string | 任務顯示名稱 | "首次點擊" |
| `description` | string | 任務描述 | "點擊河馬 10 次" |
| `target_condition.type` | string | 目標條件類型 | "tap_count", "idle_income_total" |
| `target_condition.value` | number | 目標條件數值 | 10 |
| `rewards.coins` | number | 獎勵金幣 | 50 |
| `rewards.experience` | number | 獎勵經驗值 | 10 |

### 目標條件類型

- `tap_count`: 點擊次數
- `idle_income_total`: 放置收益總額
- `equipment_upgrades`: 裝備升級次數
- `pets_collected`: 收集寵物數量

### 範例配置

```json
{
  "quests": [
    {
      "id": "quest_001",
      "name": "首次點擊",
      "description": "點擊河馬 10 次",
      "target_condition": {
        "type": "tap_count",
        "value": 10
      },
      "rewards": {
        "coins": 50,
        "experience": 10
      }
    }
  ]
}
```

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

*最後更新: 2025-08-24*
