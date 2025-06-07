# BatteryOptimizer_for_Mac

[BatteryOptimizer_for_Mac](https://github.com/js4jiang5/BatteryOptimizer_for_Mac) 是 [Battery APP v1.2.7](https://github.com/actuallymentor/battery) 的一個分支, 但加入新功能、增強功能、錯誤修復以及刪除令人困惑或無用的命令，如下所示

## 多語言版本
- [English README](README.md)<br>

### 新功能
- 支援 Apple 和 Intel CPU Macs
- 航行模式 (sail mode)，允許電池從維持百分比航行到航行目標而無需充電
- 定時電池校正，每月指定日（最多四日）開始自動電池校正，或每1-3個月指定一日，或每1-12週指定星期幾開始自動電池校正
- 新指令“suspend”，暫時電池維護，允許充電至 100%，並在重新連接交流電源供應器時自動恢復維護
- 即使 MacBook 睡眠或關機時，充電限制器仍然有效
  - Intel CPU：限制為上限百分比
  - Apple CPU：限制固定為80%
- 新增電池每日日誌和通知 

### 增強功能
- 以真實的硬體充電百分比取代 macOS 電池百分比。
- 當電池校正的每個步驟完成時發送通知
- 開始電池校正前通知用戶打開 MacBook 螢幕，並在 MacBook 螢幕打開時立即開始電池校正
- 禁止在 MacBook 螢幕關閉時放電，以防止意外進入睡眠模式
- 在「電池狀態」中報告定時電池校正時間
- 在狀態報告中包含電池健康度和溫度
- 放電期間將 LED 設定為無（不亮）
- 新增顯示目前版本的命令
- 當有新版本可供更新時通知用戶

### [Battery APP v1.2.7](https://github.com/actuallymentor/battery) 錯誤修復 
- 電池校正失敗並停留在 10%
- 由於同時充電和放電，電池健康狀況惡化
- 啟動時啟動的電池進程的 PID 不會被存儲，因此 "battery maintain stop" 無法終止原有的 maintain

### 刪除指令
- 電池轉接器開/關（令人困惑，最好不要使用）
- 電池充電開/關（令人困惑，最好不要使用）
- 電池保持使用電壓為依據（不實用，因為充電開始時電壓突然升高）

### 相較於 AlDente 的優點
- 免費且開源
- 極輕量，記憶體使用量只有 AlDente 的 1/20
- 不佔 menu bar 空間
- 每日主動通知電池狀態，使用者無須手動執行此工具
- 日誌記錄電池狀態歷史

### 安裝完成後的設定需求
這是適用於 Apple 和 Intel Silicon Mac 的 CLI 工具。<br>
請調整 Mac 系統設定如下
1.	系統設定 > 隱私權與安全性 > 輔助使用 > 增加 "應用程式\工具程式\工序指令編寫程式"
2.	系統設定 > 隱私權與安全性 > 輔助使用 > 增加 "應用程式\工具程式\終端機"
3.	系統設定 > 通知 > 開啟 "在鏡像輸出或共享顯示器時允許通知"
4.	系統設定 > 通知 > 應用程式通知 > 工序指令編寫程式 > 選擇 "提示"
如果通知中沒有工序指令編寫程式，請重啟你的 Mac 再確認一次.

### 🖥 CLI 版本的安裝方法

單指令安裝:

```bash
curl -s https://raw.githubusercontent.com/js4jiang5/BatteryOptimizer_for_Mac/main/setup.sh | bash
```

安裝過程:

1. 下載 `smc` 工具 (編譯來源 [hholtmann/smcFanControl](https://github.com/hholtmann/smcFanControl.git))
2. 安裝 `smc` 至 `/usr/local/bin`
3. 安裝 `battery` 至 `/usr/local/bin`
4. 安裝 `brew` 以安裝 `sleepwatcher` (Intel CPU Macs 不需要，會自動跳過)
5. 安裝 `sleepwatcher` (Intel CPU Macs 不需要，會自動跳過)

### 快照
- `電池狀態` <br>
<img src="https://i.imgur.com/VHx5ytq.jpg" /> <br>

- `電池維護充電上限 85%，下限 70%` <br>
<img src="https://i.imgur.com/mWhaVjb.jpg" /> <br>

- `電池校正` <br>
<img src="https://i.imgur.com/Pj87VPN.jpg" /> <br>

- `電池校正 螢幕上蓋未打開提醒通知` <br>
<img src="https://i.imgur.com/4ikr641.jpg" /> <br>

- `電池校正 開始通知` <br>
<img src="https://i.imgur.com/3PMRCdU.jpg" /> <br>

- `電池校正 結束通知` <br>
<img src="https://i.imgur.com/foc3n0u.jpg" /> <br>

- `安排每月 12 28 日 21:30 進行電池校正` <br>
<img src="https://i.imgur.com/QbTiWqo.jpg" /> <br>

- `安排每兩週的週三 10:50 進行電池校正` <br>
<img src="https://i.imgur.com/JTNpakx.jpg" /> <br>

- `電池狀態每日通知` <br>
<img src="https://i.imgur.com/42ATyJz.jpg" /> <br>

- `顯示電池狀態日誌` <br>
<img src="https://i.imgur.com/ETfjely.jpg" /> <br>

- `有更新版通知` <br>
<img src="https://i.imgur.com/wRw4GFl.jpg" /> <br>

- `更新至最新版前顯示更新內容` <br>
<img src="https://i.imgur.com/6Np1Kd8.jpg" /> <br>

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
  - 電池校正會將電池放電至 15%, 然後充電到 100%, 保持一小時後, 放電到所設定的充電上限
  - 如果 macbook 螢幕打開且已接電源，電池校正立刻開始。
  - 如果 macbook 螢幕沒打開或是沒接電源線, 會收到提醒通知。一旦 macbook 螢幕打開且已接電源，電池校正就自動啟動。如果超過一天仍未打開螢幕，則電池校正停止
  - 電池校正過程中每一步驟完成都會收到通知直到電池校正結束或出現錯誤
    eg: battery calibrate   # 開始電池校正
    eg: battery calibrate stop # 停止電池校正

  battery schedule
    每月最多安排 4 日進行定期電池校正，或每 1~12 週指定星期幾，或每 1~3 個月指定一日。預設為每月一號上午 9 點。
    範例:
    battery schedule    # 每月一日早上九點電池校正
    battery schedule day 1 8 15 22    # 每月 1, 8, 15, 22 日早上九點電池校正
    battery schedule day 3 18 hour 13    # 每月 3, 18 日 13:00 (下午一點)電池校正
    battery schedule day 6 16 26 hour 18 minute 30    # 每月 6, 16, 26 日 18:30 電池校正
    battery schedule weekday 0 week_period 2 hour 21 minute 30 # 每兩個禮拜的禮拜日 21:30 電池校正
    battery schedule disable    # 停止定期電池校正
    battery schedule enable    # 重啟定期電池校正
    限制:
      1. 每月最多四日
      2. 正確日期(day)範圍  [1-28]
      3. 正確小時(hour)範圍 [0-23]
      4. 正確分鐘(minute)範圍 [0-59]
      5. 正確星期幾(weekday)範圍 [0-6] 0:星期日, 1:星期一, 以此類推
      6. 正確星期週期(week_period)範圍 [1-12]
      7. 正確月週期(month_period)範圍 [1-3]

  battery charge LEVEL[1-100, stop]
    將電池充電到指定百分比，並在達到該百分比時停止充電
    eg: battery charge 90
    eg: battery charge stop # 終止進行中的充電程序並停止充電

  battery discharge LEVEL[1-100, stop]
    將電池放電到指定百分比，並在達到該百分比時停止放電
    eg: battery discharge 90
    eg: battery discharge stop # 終止進行中的放電程序並停止放電

  battery status
    顯示電池 SMC 狀態、容量、溫度、運作狀況和循環計數

  battery dailylog
    顯示電池日誌以及電池日誌儲存位置

  battery changelog
    顯示在 Github 上最新版本的變更內容

  battery calibratelog
    顯示電池校正歷史記錄

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
    重新安裝 BatteryOptimizer_for_Mac

  battery uninstall
    解除安裝，完成後電池會持續充電
```

### 後語
如果您覺得這個小工具對您有幫助，[請我喝杯咖啡吧](https://buymeacoffee.com/js4jiang5) ☕ 😀.