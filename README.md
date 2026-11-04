# Steps

A personal step tracker for **iPhone and Apple Watch**, built with **SwiftUI** and **HealthKit**.
It reads your step count from Apple Health and shows progress toward a daily goal, with
a hand-drawn animated character that reacts to how your day is going.

<p align="center">
  <img src="Screenshots/iphone-main.png" width="260" alt="iPhone main screen with goal ring, streak, golf mode">
  &nbsp;&nbsp;&nbsp;
  <img src="Screenshots/watch-ring.png" width="220" alt="Apple Watch Ultra 2 ring screen">
</p>

## Features

**iPhone**
- Daily goal ring (2,000–30,000, default 10,000) with today's steps and steps to go
- Streak of consecutive days at goal, pace check, and "holes walked" (~1,300 steps per hole)
- Golf mode: start/end a 9- or 18-hole round and track steps between two times; saved round history
- Last 7 days table: days at goal, daily average, best day, per-day bars with ✅ or how many steps short
- Themes: Auto (system), Dark, Purple & gold, Golf green

**Apple Watch**
- Ring page centered for the Ultra 2 screen, with the animated character and step count
- Stats page (streak, pace, holes walked) and a 7-day bar chart, paged with the Digital Crown
- Pick your character and ring color on the watch
- Watch face complications (WidgetKit): ring, steps left, and pace, for circle, corner, inline,
  and rectangle slots; they read HealthKit directly and refresh when the app opens

**Animated characters** (`Characters.swift`)
- Three characters drawn entirely in code with SwiftUI `Canvas` + `TimelineView` on a 100×140 grid:
  a golfer, a basketball player, and a gym version
- Mood follows your progress: swings during a golf round, celebrates at goal, walks when on pace, slumps when behind

## How it works

- **HealthKit:** `HKStatisticsCollectionQueryDescriptor` sums steps per day for the last 61 days
  (for the streak and 7-day history); `HKStatisticsQueryDescriptor` sums steps between two times for golf rounds.
- **Personal pace curve:** learns your usual day from the last 30 days of hourly HealthKit data
  (the share of a day's steps you've usually done by each hour, averaged over days with 2,000+ steps).
  "On pace" means on track compared with your own normal day, not a flat line. Until there are 7 such
  days, it falls back to walking evenly from 7am to 10pm.
- **Catch-up:** when behind, it says how many steps and how many minutes of walking (~100 steps/min)
  it takes to catch up.
- **Forecast:** scales today's steps by how much of your usual day is done to say what time you'll
  reach your goal, or how many steps short you'll be by your usual end of day (and how many more
  minutes of walking would close the gap). One shared `Pace.swift` drives the phone, watch, and complications.
- **State:** settings and golf rounds are stored with `@AppStorage`; data refreshes whenever the app becomes active.
- **Layout:** the watch ring is centered on the physical screen (`WKInterfaceDevice.screenBounds`)
  instead of the safe area, so it stays centered next to the clock and page indicator.

## Tech

Swift · SwiftUI · HealthKit · Combine · WatchKit · Xcode 27 · iOS 27 / watchOS 27

## Run it

1. Open `Steps.xcodeproj` in Xcode.
2. Set your own Team under **Signing & Capabilities** for both targets (and change the bundle id if needed).
3. Run on a real iPhone / Apple Watch (Health data isn't available in the simulator) and allow Health access.
