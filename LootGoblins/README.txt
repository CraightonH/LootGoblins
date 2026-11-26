LootGoblins 0.9.0-alpha — WoW Forever, Interface 16001

INSTALL
Place this folder in Interface/AddOns/LootGoblins. Reload the UI after updating.
Return to character selection if the client does not discover the new Lua files.
Settings: Options > AddOns > LootGoblins, or /lg.

ONE LOOT QUEUE
A single compact, draggable window for all rolls. Click item icons across the
top; radial cooldowns show their timers. Need/Greed/Pass stay fixed beside the
tabs. Mouse wheel or overflow-only arrows scroll the tabs. Selecting a loot
choice advances to the next undecided item after confirmation. Full client
item descriptions and the party table share the details area. The confirmed
winner is highlighted; outcomes tint item icons. No outcome border or footer.
The largest queued description sets a stable window size until the queue empties.
Tabs and item dismissal cannot shrink it. Disabling betting removes its column
and narrows the window.

Use - / + to minimize to the header and restore without moving the header.
Close unlocks after all available rolls are chosen or no longer actionable.
Closing hides the current queue while results and bets update in the background.
New loot reopens the pane.

DEMO USES THE REAL UI
/lg demo simulates three drops. /lg demo 10 tests tab overflow. Both use the
same QueueUI.lua renderer and controls as live rolls. Demo.lua only drives
sample data, choices, bets and timed results. /lg demo pattern tests a real
recipe tooltip, including the crafted result and delayed native data refresh. Results resolve after about forty
seconds. No server rolls, network bets or history entries are created.

TOOLTIP ADDONS
Settings > Common > Tooltip addons has separate checkboxes for Auctionator
prices and GearQuest rankings/notes in item details. Both default on. Changes
apply immediately and persist, without altering the addons globally.

SIDE BETS
Enable betting in settings. Click 1c, 1s or 1g on any player repeatedly to add
stakes until the loot resolves. No percentage or remaining-time cutoff.
Other players' choices and roll values stay hidden until the confirmed result.
Items already blinded remain blind even if betting is subsequently disabled.
The addon cannot hide information provided elsewhere by the game or addons.
No gold moves automatically: this is an honor ledger. /lg bets shows saved
rounds and local payment notes. Disabling betting preserves existing pledges.

COMMANDS
/lg queue: show LootGoblins queue; /lg native: restore default loot popups.
/lg clear: dismiss completed items. /lg history: saved drops. /lg stats: player
statistics. /lg export: CSV. /lg session: saved drop history.

Checked with simulated game APIs; the new layout still needs in-game visual
and real-party verification, including binding prompts and two-client betting.
