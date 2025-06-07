# BatteryOptimizer_for_Mac

[BatteryOptimizer_for_Mac](https://github.com/js4jiang5/BatteryOptimizer_for_Mac) is a fork of [Battery APP v1.2.7](https://github.com/actuallymentor/battery), with new features, enhancements, bug fixes, and removal of confusing or useless commands as follows

## Other languages
- [正體中文 說明](README_TW.md)<br>

### New features
- support both Apple and Intel CPU Macs
- sail mode, allowing the battery to sail from maintain percentage to sail target without charging
- scheduled calibration, starting automatic calibration on specified days per month (at most four days), or specified one day every 1-3 month, or specified weekday every 1-12 weeks
- new command "suspend", suspending maintain temporarily allowing charging to 100%, and automatically resume maintain when AC adapter is reconnected
- charging limiter still works even when macbook sleep or shutdown
  - Intel CPU: limit is at maintain percentage
  - Apple CPU: limit is fixed at 80%
- add battery daily log and notification

### Enhancements
- replace macOS battery percentage with real hardware charging percentage.
- send notifications when each step of calibration is completed
- notify user to open macbook lid before calibration is started, and start calibration immediately when macbook lid is open
- prohibit discharge when macbook lid is closed to prevent entering sleep mode unexpectedly
- report calibration schedule in "battery status"
- include battery health and temperature in status report
- set LED to none (no light) during discharging
- add a command to show current version
- notify user when new version is available to update

### Fixed bugs of [Battery APP v1.2.7](https://github.com/actuallymentor/battery)
- Calibrate fail and hang at 10%
- Battery health deteriorate due to simultaneous charge and discharge
- PID of battery process initiated at boot-up is not stored, thus cannot be killed by "battery maintain stop" 

### Removed commands
- battery adapter on/off (confusing and better not be used)
- battery charging on/off (confusing and better not be used)
- battery maintain using voltage (not practical because voltage boost abruptly when charging starts)

### Advantages compared to AlDente
- free and open source
- extremely light weighted - memory usage is 1/20 of AlDente
- no icon in menu bar
- daily notification of battery status. no need for user to manually run this tool
- daily log of battery status history

### Required settings after installation
This is a CLI tool for both Apple and Intel Silicon Macs.<br>
Please setup your Mac system settings as follows
1.	System Settings > Privacy & Security > Accessibility > add "Applications\Utilities\Script Editor" 
2.	System Settings > Privacy & Security > Accessibility > add "Applications\Utilities\Terminal" 
3.	System Settings > Notifications > enable "Allow notifications when mirroring or sharing"
4.	System Settings > Notifications > Applications > Script Editor > Choose "Alerts"<br>
If Script Editor is missing in the Notifications list, please reboot your Mac and check again.

### 🖥 Command-line version installation

One-line installation:

```bash
curl -s https://raw.githubusercontent.com/js4jiang5/BatteryOptimizer_for_Mac/main/setup.sh | bash
```

This will:

1. Download the precompiled `smc` tool in this repo (built from the [hholtmann/smcFanControl](https://github.com/hholtmann/smcFanControl.git) repository)
2. Install `smc` to `/usr/local/bin`
3. Install `battery` to `/usr/local/bin`
4. Install `brew` for `sleepwatcher` (not required for Intel CPU Macs)
5. Install `sleepwatcher` (not required for Intel CPU Macs)

### Snapshots
- `battery status` <br>
<img src="https://i.imgur.com/VHx5ytq.jpg" /> <br>

- `battery charge upper limit 85% and lower limit 70%` <br>
<img src="https://i.imgur.com/mWhaVjb.jpg" /> <br>

- `battery calibrate` <br>
<img src="https://i.imgur.com/Pj87VPN.jpg" /> <br>

- `battery calibrate lid not open notification` <br>
<img src="https://i.imgur.com/G6R5EnH.jpg" /> <br>

- `battery calibrate start notification` <br>
<img src="https://i.imgur.com/J2L99Uz.jpg" /> <br>

- `battery calibrate end notification` <br>
<img src="https://i.imgur.com/FLvcO3h.jpg" /> <br>

- `calibration schedule on Day 12 28 at 21:30` <br>
<img src="https://i.imgur.com/yl7HxIx.jpg" /> <br>

- `calibration schedule on WED every 2 weeks at 10:50` <br>
<img src="https://i.imgur.com/yXYeBB1.jpg" /> <br>

- `daily notification` <br>
<img src="https://i.imgur.com/UvAivHE.jpg" /> <br>

- `show daily log` <br>
<img src="https://i.imgur.com/ETfjely.jpg" /> <br>

- `new version available notification` <br>
<img src="https://i.imgur.com/nQttVUL.jpg" /> <br>

- `show changelog before update to the latest version` <br>
<img src="https://i.imgur.com/hlvnmMW.jpg" /> <br>

### Usage
For help, run `battery` without parameters or `battery help`:

```
Battery CLI utility v2.0.0

Usage:

  battery maintain PERCENTAGE[10-100,stop,suspend,recover] SAILING_TARGET[5-99]
  - PERCENTAGE is battery level upper bound above which charging is stopped
  - SAILING_TARGET is battery level lower bound below which charging is started. default value is PERCENTAGE-5 if not specified
  - Examples:
    battery maintain 80 50    # maintain at 80% with sailing to 50%
    battery maintain 80    # equivalent to battery maintain 80 75
    battery maintain stop   # kill running battery maintain process, disable daemon, and enable charging. maintain will not run after reboot
    battery maintain suspend   # suspend running battery maintain process and enable charging. maintain is automatically resumed after AC adapter is reconnected. used for temporary charging to 100% before travel
    battery maintain recover   # recover battery maintain process

  battery calibrate
  - calibrate the battery by discharging it to 15%, then recharging it to 100%, and keeping it there for 1 hour, then discharge to maintained percentage level
  - if macbook lid is open and AC adapter is connected, calibrate start immediately
  - if macbook lid is not open or AC adapter is not connected, a remind notification will be received. calibration will be started automatically once macbook lid is open and AC adapter is connected, and calibration will be terminated if lid is not open in one day.
  - notification will be received when each step is completed or error occurs till the end of calibration
  - if you prefer the notifications to stay on until you dismiss it, setup notifications as follows
    system settings > notifications > applications > Script Editor > Choose "Alerts"
  - when external monitor is used, you must setup notifications as follows in order to receive notification successfully
    system settings > notifications > check 'Allow notifications when mirroring or sharing the display'
    eg: battery calibrate   # start calibration
    eg: battery calibrate stop # stop calibration

  battery schedule
    schedule periodic calibration at most 4 separate days per month, or specified weekday every 1~12 weeks, or specified one day every 1~3 month. default is one day per month on Day 1 at 9am.
    Examples:
    battery schedule    # calibrate on Day 1 at 9am
    battery schedule day 1 8 15 22    # calibrate on Day 1, 8, 15, 22 at 9am.
    battery schedule day 3 18 hour 13    # calibrate on Day 3, 18 at 13:00
    battery schedule day 6 16 26 hour 18 minute 30    # calibrate on Day 6, 16, 26 at 18:30
    battery schedule weekday 0 week_period 2 hour 21 minute 30 # calibrate on Sunday every 2 weeks at 21:30
    battery schedule disable    # disable periodic calibration
    battery schedule enable    # enable periodic calibration
    Restrictions:
      1. at most 4 days per month are allowed
      2. valid day range [1-28]
      3. valid hour range [0-23]
      4. valid minute range [0-59]
      5. valid weekday range [0-6] 0:Sunday, 1:Monday, ...
      6. valid week_period range [1-12]
      7. valid month_period range [1-3]

  battery charge LEVEL[1-100, stop]
    charge the battery to a certain percentage, and disable charging when that percentage is reached
    eg: battery charge 90
    eg: battery charge stop # kill running battery charge process and stop charging

  battery discharge LEVEL[1-100, stop]
    block power input from the adapter until battery falls to this level
    eg: battery discharge 90
    eg: battery discharge stop # kill running battery discharge process and stop discharging

  battery status
    output battery SMC status, capacity, temperature, health, and cycle count 

  battery dailylog
    output daily log and show daily log store location

  battery changelog
    show the changelog of the latest version on Github

  battery calibratelog
    show calibrate history

  battery logs LINES[integer, optional]
    output logs of the battery CLI and GUI
    eg: battery logs 100

  battery language LANG[tw,us]
    eg: battery language tw  # show status and notification in traditional Chinese if available
    eg: battery language us  # show status and notification in English
  
  battery update
    update the battery utility to the latest version

  battery version
    show current version

  battery reinstall
    reinstall the battery utility to the latest version (reruns the installation script)

  battery uninstall
    enable charging, remove the smc tool, and the battery script
```

### Final note
If you feel this tool is helpful for you, you may [buy me a coffee](https://buymeacoffee.com/js4jiang5) ☕ 😀.