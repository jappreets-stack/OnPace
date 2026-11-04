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
- **Pace:** assumes walking evenly from 7am to 10pm, and compares today's steps with
  `goal × (time elapsed ÷ 15 hours)`.
- **State:** settings and golf rounds are stored with `@AppStorage`; data refreshes whenever the app becomes active.
- **Layout:** the watch ring is centered on the physical screen (`WKInterfaceDevice.screenBounds`)
  instead of the safe area, so it stays centered next to the clock and page indicator.

## Tech

Swift · SwiftUI · HealthKit · Combine · WatchKit · Xcode 27 · iOS 27 / watchOS 27

## Run it

1. Open `Steps.xcodeproj` in Xcode.
2. Set your own Team under **Signing & Capabilities** for both targets (and change the bundle id if needed).
3. Run on a real iPhone / Apple Watch (Health data isn't available in the simulator) and allow Health access.
