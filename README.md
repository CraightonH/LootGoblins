# LootGoblins

A compact loot queue with optional side bets for WoW Forever (Interface 16001).

## Loot window

All simultaneous drops share one draggable window. Item icons form connected tabs across the top, with radial loot timers and a check mark after your choice. Need, Greed, and Pass stay fixed at the right; Disenchant and Transmog appear when offered by the client. The tab strip scrolls with its arrows or mouse wheel. Arrows appear only when the icons overflow, and auto-advance scrolls the next undecided item into view.

The details pane uses native GameTooltip rendering and refresh handling, including embedded crafted-item previews for patterns and recipes. The party table sits beside it, highlights the confirmed winner, and sorts revealed choices Need → Transmog → Greed → Pass → Waiting. Personal outcomes tint the relevant item icon; the window has no outcome border. There is no footer. The window measures all queued item descriptions in advance and keeps the largest pane sizes until the queue empties. Changing tabs or dismissing a larger item cannot shrink the active window. Turning betting off still explicitly removes its controls, stakes, and column and narrows the window.

The client still owns loot submission and binding confirmations. Untracked or unsupported native loot frames remain available. `/lg native` restores Blizzard's popups; `/lg queue` restores LootGoblins's queue. Avoid running another loot-frame replacement alongside LootGoblins.

## Demo and testing

`/lg demo` simulates three drops. `/lg demo pattern` previews a real pattern and its crafted output. `/lg demo 10` exercises overflow with ten drops (up to forty supported). **Demo and real drops use exactly the same `QueueUI.lua` window, renderer, tabs, actions, tooltips, table, sizing, and result effects.** `Demo.lua` only creates sample item/party data, simulates choices/bets, and schedules outcomes. It creates no separate UI, native-template copies, real roll submissions, network bets, or history records. Results arrive in about forty seconds; rerunning the command replaces the samples and invalidates their old timers.

This release is checked with simulated game APIs, not visually verified inside the running game client. Check real drops, confirmation acceptance/cancellation, simultaneous items, tab overflow, winner effects, dragging, item cache loading, and two-client betting in game.

## Side bets

Enable side bets under Options → AddOns → LootGoblins. Click **1c**, **1s**, or **1g** beside a player to add that amount to your prediction. Repeated clicks accumulate, and you can back multiple players. The backed row shows your running stake.

Bets remain open until loot resolution, including while all players have chosen or the timer has reached zero and the server is still resolving. The former selection-percentage and ten-second limits are removed. Eligible-roster and unambiguous-item checks still apply.

Other players' choices and all roll numbers stay hidden until a confirmed loot result. Blind rows use stable name order and include passes, so ordering and filtering cannot reveal choices. Once an item has been shown with betting enabled, it remains blind through resolution even if betting is switched off. This affects LootGoblins's display; it does not prevent inspecting information supplied elsewhere by the game or another addon.

This is an honor ledger. No money is collected or transferred. Correct predictions split the pledged pool proportionally, with exact copper accounting. Existing bets remain in the ledger when betting is disabled. `/lg bets` opens saved rounds and local payment notes. See [betting details](docs/betting.md).

Under **Settings → Common → Tooltip addons**, separate **Auctionator prices** and **GearQuest rankings and notes** checkboxes control their contributions to item details. Both default on; changes apply immediately and persist across reloads, without changing either addon globally.

Tooltip addons using the shared item processor can contribute to the embedded tooltips. LootGoblins follows Auctionator's `NotGameTooltip` naming convention and resets GearQuestForever's per-tooltip guards when content is cleared. Addons that explicitly target only Blizzard's `GameTooltip` or `ItemRefTooltip` may require their own integration; their adjustments cannot be universally transferred to a separate embedded tooltip.

## Commands

| Command | Action |
| --- | --- |
| `/lg` or `/lootgoblins` | Open game settings category |
| `/lg demo [count]` | Simulate drops in the real queue renderer |
| `/lg queue` | Enable the LootGoblins loot window |
| `/lg native` | Restore Blizzard's loot popups |
| `/lg clear` | Dismiss completed queue items |
| `/lg history` or `/lg session` | Open saved drop history |
| `/lg stats` | Open player statistics |
| `/lg export` | Open CSV export |
| `/lg bets` | Open the side-bet ledger |

Use **−** to minimize the pane to its header and **+** to restore it; the header stays in place and shows remaining choices. The close button unlocks after all available rolls have been chosen (or can no longer be acted on). Closing hides the current queue while results, history, and bets continue in the background; newly arriving loot opens the pane again.

Drag the window header or background to move it. Position and scale persist across reloads. Settings include position locking, hover-paused result dismissal, result timeout, table font/row sizing, class colors, sounds, and history retention.

## Install

Extract the `LootGoblins` folder into the client's `Interface/AddOns/`. The TOC must be at `Interface/AddOns/LootGoblins/LootGoblins.toc`. Reload the UI after updating; restarting or returning to character selection may be needed for newly added source files. History and honor-ledger records use the existing `LootGoblinsDB` saved variable.

## Releases

Pushing an annotated `vX.Y.Z`, `vX.Y.Z-alpha[.N]`, or `vX.Y.Z-beta[.N]` tag runs tests, builds a validated ZIP, creates a GitHub release and deploys that same archive to CurseForge project **1806558**. The package version comes from the tag. See [automatic releases](docs/releases.md) for setup, release commands and recovery.

## Development

`make test` runs the model, persistent-history, asynchronous betting, and mocked game integration suites with `lua` (override with `LUA=/path/to/lua`). Integration loads the actual TOC and verifies that live and simulated drops share the same UI with no demo branches in the renderer. `make package` builds `dist/LootGoblins-0.9.0-alpha.zip` with Python's standard library.

`QueueUI.lua` owns the only loot renderer. `Demo.lua` owns the simulation adapter; `Core.lua` owns live events. `UI.lua` supplies settings. `Model.lua` supplies roll state, privacy, and sorting. `History.lua`/`StatsUI.lua` provide persistent history; `BetModel.lua`/`BetComms.lua`/`BetUI.lua` handle honor bets and ledger views.
