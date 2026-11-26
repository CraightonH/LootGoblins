# Side bets

Enable betting in LootGoblins settings, then click **1c**, **1s**, or **1g** beside a player in the loot queue. Each click adds that denomination to your prediction. Back multiple players and keep adding until the item resolves. There is no percentage-selected or remaining-time cutoff.

While betting is enabled, the party table hides other players' choices and everyone's roll values until an authoritative loot result arrives. Hidden rows use stable alphabetical order and include players who passed. Once blinded, an item stays blinded until resolution even if the setting is turned off. Turning betting off removes the betting column and stakes and narrows the window. It does not withdraw existing pledges. Privacy applies to LootGoblins's presentation; the game or other addons may expose the same information elsewhere.

Item identity and eligible-player history must still be reliable. Ambiguous identical drops and missing rosters do not permit new bets. Local submissions stop as soon as a result is known; valid earlier notifications may still arrive and reconcile a pool. The old time/percentage preferences no longer affect placement.

`/lg demo [count]` supports the same inline controls through a simulation data adapter, using the exact live UI. Simulated bets stay local and do not create ledger entries or addon messages.

## Ledger and payments

Correct predictions split the pledged pool proportionally to their combined stakes on the winner. Stakes on other players still count toward net balances. Copper rounding conserves the entire pool. No correct predictions, everyone passing, or fewer than two bettors produces no payment. No gold is transferred automatically.

`/lg bets` opens the ledger. Payment marks are local notes, not proof of transfers. A late valid notification may revise a calculated settlement; previously paid notes remain separately available for manual reconciliation. Interrupted pools remain unresolved rather than inventing a result. The latest 1,000 rounds are retained, protecting active records during pruning.

## Coordination

Bets are cumulative per sender, target, and session, with increasing revisions. Repeated and reordered messages cannot double count or reduce stakes. Rapid clicks coalesce in the outgoing queue. Pool identity uses the item, eligible roster, and expected deadline; the deadline identifies the item and does not close placement. BET packets retain their timer/selection fields for submission validation, without the former cutoffs.

Canonical bet books, automatic acknowledgments, bounded replay, and synchronization recover lost/reordered messages. A connected bettor resolves an agreed book against the local authoritative winner. Resolver failover and late reconciliation remain automatic. No manual hosting or acceptance step is required. This remains a cooperative honor system, not server-issued escrow or a guarantee against deliberately modified clients.

## Verification

Automated checks cover bets after everyone has selected and at zero timer before resolution, closure on resolution, exact copper settlement, repeated multi-target stakes, asynchronous joining, missing/reordered messages, reconciliation, and forty clients. Shared UI integration checks verify blindness, stable ordering, removal and narrowing when disabled, and the same controls for real and simulated drops. Real two-client testing remains necessary for client channel behavior and server-event timing.
