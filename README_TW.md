# BatteryOptimizer_for_MAC

[BatteryOptimizer_for_MAC](https://github.com/js4jiang5/BatteryOptimizer_for_MAC) 是 [Battery APP v1.2.7](https://github.com/actuallymentor/battery) 的一個分支, 但加入新功能、增強功能、錯誤修復以及刪除令人困惑或無用的命令，如下所示

## 多語言版本
- [English README](README.md)<br>

### 新功能
- 支援 Apple 和 Intel CPU Mac（請參閱下面的註釋）
- 航行模式 (sail mode)，允許電池從維持百分比航行到航行目標而無需充電
- 定時校準，每月指定日（最多四日）開始自動校準，或每1-3個月指定一日，或每1-12週指定星期幾開始自動校準
- 新指令“suspend”，暫時電池維護，允許充電至 100%，並在重新連接交流電源供應器時自動恢復維護
- 即使 MacBook 睡眠或關機時，充電限制器仍然有效
  - Intel CPU：限制為上限百分比
  - Apple CPU：限制固定為80%（註：不支援MacOS Sequoia，因為 Apple 不再提供此功能）
- 新增電池每日日誌和通知 

  註釋: 放電和校準僅適用於 2014 年或更早型號的 Intel CPU Mac。我仍在尋找其他 Intel CPU Macs 型號的放電方法。

### 增強功能
- 以真實的硬體充電百分比取代 macOS 電池百分比。
- 當校準的每個步驟完成時發送通知
- 開始校準前通知用戶打開 MacBook 螢幕，並在 MacBook 螢幕打開時立即開始校準
- 禁止在 MacBook 螢幕關閉時放電，以防止意外進入睡眠模式
- 在「電池狀態」中報告定時校準時間
- 在狀態報告中包含電池健康度和溫度
- 放電期間將 LED 設定為無（不亮）
- 新增顯示目前版本的命令
- 當有新版本可供更新時通知用戶

### [Battery APP v1.2.7](https://github.com/actuallymentor/battery) 錯誤修復 
- 校準失敗並停留在 10%
- 由於同時充電和放電，電池健康狀況惡化
- 啟動時啟動的電池進程的 PID 不會被存儲，因此 "battery maintain stop" 無法終止原有的 maintain

### 刪除指令
- 電池轉接器開/關（令人困惑，最好不要使用）
- 電池充電開/關（令人困惑，最好不要使用）
- 電池保持使用電壓為依據（不實用，因為充電開始時電壓突然升高）

### 需求
這是適用於 Apple 和 Intel Silicon Mac 的 CLI 工具。<br>
請調整 MAC 系統設定如下
1.	系統設定 > 通知 > 開啟 "在鏡像輸出或共享顯示器時允許通知"
2.	系統設定 > 通知 > 應用程式通知 > 工序指令編寫程式 > 選擇 "提示"

### 🖥 CLI 版本的安裝方法

單指令安裝:

```bash
curl -s https://raw.githubusercontent.com/js4jiang5/BatteryOptimizer_for_MAC/main/setup.sh | bash
```

安裝過程:

1. 下載 `smc` 工具 (編譯來源 [hholtmann/smcFanControl](https://github.com/hholtmann/smcFanControl.git))
2. 安裝 `smc` 至 `/usr/local/bin`
3. 安裝 `battery` 至 `/usr/local/bin`
4. 安裝 `brew` 以安裝 `sleepwatcher` (Intel CPU Macs 不需要，會自動跳過)
5. 安裝 `sleepwatcher` (Intel CPU Macs 不需要，會自動跳過)

### 使用方法

如需協助，請執行不含參數的 `battery` 或 `battery help`:

```
Battery CLI utility v2.0.0

Usage:

  battery maintain PERCENTAGE[10-100,stop,suspend,recover] SAILING_TARGET[5-99]
  - PERCENTAGE 為充電上限，超過則停止充電
  - SAILING_TARGET 為航行目標，低於此值則開始充電。若未指定則默認值為 (充電上限-5)
  - 範例:
    battery maintain 80 50    # 高於80% 停止充電，低於 50% 開始充電
    battery maintain 80    # 相當於 battery maintain 80 75
    battery maintain stop   # 終止進行中的 battery maintain 並立即充電。重開機後也不會進行 battery maintain
    battery maintain suspend   # 暫停 battery maintain 並立即充電。如果電源拔掉後重新連上 maintain 就會恢復，適合暫時需充電到 100% 的場合，例如外出旅遊時
    battery maintain recover   # 恢復 battery maintain

  battery calibrate
  - 校準會將電池放電至 15%, 然後充電到 100%, 保持一小時後, 放電到所設定的充電上限
  - 如果 macbook 螢幕打開且已接電源，校準立刻開始。
  - 如果 macbook 螢幕沒打開或是沒接電源線, 會收到提醒通知。一旦 macbook 螢幕打開且已接電源，校準就自動啟動。如果超過一天仍未打開螢幕，則校準停止
  - 校準過程中每一步驟完成都會收到通知直到校準結束或出現錯誤
    eg: battery calibrate   # 開始校準
    eg: battery calibrate stop # 停止校準

  battery schedule
    每月最多安排 4 日進行定期校準，或每 1~12 週指定星期幾，或每 1~3 個月指定一日。預設為每月一號上午 9 點。
    範例:
    battery schedule    # 每月一日早上九點校準
    battery schedule day 1 8 15 22    # 每月 1, 8, 15, 22 日早上九點校準
    battery schedule day 3 18 hour 13    # 每月 3, 18 日 13:00 (下午一點)校準
    battery schedule day 6 16 26 hour 18 minute 30    # 每月 6, 16, 26 日 18:30 校準
    battery schedule weekday 0 week_period 2 hour 21 minute 30 # 每兩個禮拜的禮拜日 21:30 校準
    battery schedule disable    # 停止定期校準
    battery schedule enable    # 重啟定期校準
    限制:
      1. 每月最多四日
      2. 正確日期(day)範圍  [1-28]
      3. 正確小時(hour)範圍 [0-23]
      4. 正確分鐘(minute)範圍 [0-59]
      5. 正確星期幾(weekday)範圍 [0-6] 0:星期日, 1:星期一, 以此類推
      6. 正確星期週期(week_period)範圍 [1-12]
      7. 正確月週期(month_period)範圍 [1-3]

  battery charge LEVEL[1-100]
    將電池充電到指定百分比，並在達到該百分比時停止充電
    eg: battery charge 90

  battery discharge LEVEL[1-100]
    將電池放電到指定百分比，並在達到該百分比時停止放電
    eg: battery discharge 90

  battery status
    顯示電池 SMC 狀態、容量、溫度、運作狀況和循環計數

  battery dailylog
    顯示電池日誌以及電池日誌儲存位置

  battery changelog
    顯示在 Github 上最新版本的變更內容

  battery logs LINES[integer, optional]
    顯示電池記錄的最末指定行數
    eg: battery logs 100

  battery language LANG[tw,us]
    eg: battery language tw  # 電池狀態與通知以中文顯示
    eg: battery language us  # 電池狀態與通知以英文顯示
  
  battery update
    更新至最新版本

  battery version
    顯示目前版本

  battery reinstall
    重新安裝 BatteryOptimizer_for_MAC

  battery uninstall
    解除安裝，完成後電池會持續充電
```

### 後語
如果您覺得這個小工具對您有幫助，[請我喝杯咖啡吧](https://buymeacoffee.com/js4jiang5) ☕ 😀.