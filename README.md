# 上班鼓励器 · Work Cheer

[中文](README.zh-CN.md) · English

A tiny, always-on-top macOS earnings meter. Big earnings, small distractions.

![Work Cheer](preview-en.png)

## Features

- Resizable desktop widget: starts at 360 × 280, shrinks to 160 × 100, or fills your desktop.
- Monthly salary or daily pay, configurable daily hours and monthly workdays (default: 22).
- Live earnings, pause/resume, stop at actual earnings, or finish with full-day pay.
- Drag the progress slider to adjust today's hours, with one-minute precision.
- Monthly check-in calendar with tracked hours and recorded earnings.
- Chinese / English UI, including settings, calendar, menus and 20 random quotes.
- Local-only storage. No account, analytics, networking or salary uploads.

## Install

Download `Work-Cheer-Mac.zip` from this repository's [download link](Work-Cheer-Mac.zip), unzip it, and move the app into Applications. Requires macOS 12+, Apple silicon or Intel.

This community build is ad-hoc signed and **not Apple-notarized**. macOS may block downloaded copies. The project does not include an Apple Developer certificate.

## Use

Open **Settings → Language** to choose Chinese or English. Set monthly salary or daily pay and daily working hours. Start work, then pause, stop, or finish with full-day pay. Drag the slider to correct today's hours; pauses stay paused. The ¥ menu-bar icon provides all actions even in mini mode.

Monthly daily pay = monthly salary ÷ configured workdays. Hourly pay = daily pay ÷ configured daily hours. Currency remains CNY in either language. These are estimates, not payroll calculations.

Closing the window hides it but does not pause billing. Running sessions count elapsed time while the app is closed, capped at the configured daily hours. Pause or stop before quitting to prevent that. Historical sessions stay unchanged when pay settings change; the current session is recalculated. Overnight sessions belong to the start date. A manual correction on a later day creates a record for today.

## Build and verify

Install Apple's Xcode Command Line Tools, then run on a Mac:

```sh
bash build.sh
```

This builds a universal binary, signs it locally, runs checks in Chinese and English, and creates `build/Work-Cheer-Mac.zip`. No third-party dependencies are required.

Source: `*.swift`. Translations: `zh-Hans.json` and `en.json`. Bundle display names: localized `InfoPlist.*.strings`. Preferences and history live in the local `local.workcheer.meter` defaults domain and are excluded from this repository.
