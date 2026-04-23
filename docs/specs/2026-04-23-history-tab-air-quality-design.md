# History Tab Air Quality Design

## Overview
Replace the current History tab in the iPhone app with a dedicated air-quality trend view. The Dashboard keeps the current point-in-time `Input Sensor Data` and `Output Sensor Data` cards, while the History tab becomes a rolling 1-hour visualization of `input CO2`, `output CO2`, and `output O2`.

## Current Context
- The History tab is currently wired in [ContentView.swift](/Users/sidac/gro-bot/AgTech-App/BioReactor/ContentView.swift) to render `GasHistoryCardView`.
- `GasHistoryCardView` currently visualizes only output-side gas history and includes latest-value summary tiles.
- `PhotobioreactorViewModel` already publishes `history: [ReactorReading]`, and each `ReactorReading` already contains `inputCo2ppm`, `outputCo2ppm`, and `outputO2Percent`.
- Live BLE updates already merge partial characteristic notifications into a composite reading before appending/replacing history samples.

## User Requirements
- Replace the separate `History` tab content with an over-time chart for air quality readings.
  Trace: user's initial request
- The chart should use a full air view instead of output-only metrics.
  Trace: user chose "full air view"
- The chart should plot `input CO2`, `output CO2`, and `output O2`.
  Trace: user confirmed the full-air metrics choice
- Keep the Dashboard's singular reading cards in place instead of replacing them.
  Trace: user chose to replace the separate History tab only
- Use a stacked chart layout rather than a single combined overlay chart.
  Trace: user selected option `B` in the browser mockup
- Show a rolling 1-hour window of data instead of the full retained history.
  Trace: user explicitly requested a rolling 1-hour graph

## Agent Design Decisions
- Keep the existing `History` tab slot and `ContentView` routing, but redesign `GasHistoryCardView` to become the full air-quality trend screen.
  Serves: replacing the History tab content without changing the app's navigation structure.
- Use two vertically stacked charts in a single scrollable view.
  Serves: the user's selected stacked layout while keeping the history screen simple.
- The top chart will compare `input CO2` and `output CO2` on a shared `ppm` y-axis.
  Serves: the full air view requirement while making the two CO2 series directly comparable.
- The bottom chart will render `output O2` on its own `%` y-axis.
  Serves: the full air view requirement while preserving readability across different units.
- Derive the displayed points by filtering `viewModel.history` to timestamps within `latestTimestamp - 1 hour ... latestTimestamp`.
  Serves: the rolling-window requirement without changing history collection behavior.
- Remove the current latest-value summary tiles from the History tab.
  Serves: avoiding duplication because the Dashboard remains the source of singular readings.
- Reuse the existing empty-state pattern when the rolling window contains fewer than 2 points.
  Serves: preventing misleading charts when there is not enough data to show a trend.
- Add targeted tests around the rolling-window slice and preserve the existing merged-update behavior as the data source for the charts.
  Serves: making sure the new trend view is fed by stable, non-noisy history samples.

## Components
- `ContentView`
  Responsibility: continue mounting the History tab using the shared `PhotobioreactorViewModel`.
- `GasHistoryCardView`
  Responsibility: render the stacked air-quality history UI and derive chart-ready series from the supplied history.
- `PhotobioreactorViewModel`
  Responsibility: remain the source of retained `ReactorReading` history and continue merging live BLE updates before they appear in the view.

## Data Flow
1. `PhotobioreactorViewModel` publishes `history` as readings are generated from mock updates or merged BLE updates.
2. `ContentView` passes `viewModel.history` into the History tab view.
3. The History tab computes `latestTimestamp` from the newest reading and filters history down to the last hour.
4. The top chart renders the filtered `inputCo2ppm` and `outputCo2ppm` series.
5. The bottom chart renders the filtered `outputO2Percent` series.

## Error Handling And Empty States
- If there are fewer than 2 readings in the 1-hour window, show the existing "Not enough history yet" style empty state.
- If readings exist but one of the series is flat, render it as-is instead of inventing smoothing or derived values.
- The History view should not mutate history retention, BLE merge timing, or sampling cadence.

## Testing
- Add a focused test for the rolling-window filter so readings older than 1 hour are excluded from the History tab's displayed data.
- Verify the chart input logic uses absolute `ppm` for both CO2 series and absolute `%` for the O2 series.
- Regression-check that live BLE updates still merge into coherent readings before they feed history, so the charts do not explode into one point per characteristic notification.

## Out Of Scope
- Changing the Dashboard layout or removing its current-value cards
- Changing how long the app retains raw history in memory
- Adding export, zoom, or date-range controls to the History tab
