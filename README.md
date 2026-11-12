# NeoSwap

Gear swapping without writing a LuAshitacast profile. Build your sets in a window shaped like the game's equipment
menu, say when each one is worn, and NeoSwap swaps them as you play. Restyled after YunaUI. Ashita v4, CatsEyeXI.

**Install:** download `NeoSwap-<version>.zip` from [Releases](https://github.com/QB1985/NeoSwap/releases), unzip it into
your Ashita `addons` folder (so you have `addons/NeoSwap/neoswap.lua`), then load it with `/addon load neoswap`. `/nswap` shows or hides the window, `/nswap config` opens the settings.

> **LuAshitacast:** don't run both. They both hold back your actions to swap gear, so you'd get two swappers
> fighting. Unload it (`/addon unload luashitacast`), or turn on *Unload LuAshitacast on load* in the settings.
> If NeoSwap notices another swapper re-sending your actions, the title bar says so; click it to unload LuAshitacast.

## The window

- **Left: jobs.** Pick a job to see its sets (a gold dot marks your job now, the number is how many sets it has,
  a red dot means one of them has a problem). **Global** at the top holds the lockstyle jobs can share, and your modes.
- **Middle: the job.** Its emblem and level, then:
  - **Macros**: switch on, pick a book and a page; NeoSwap changes to them when you change to this job.
  - **Lockstyle**: *Off*, *Global* (the shared one) or *Own* (click *Edit* to build this job's look).
    Set when you change job, and kept through zone changes.
  - **Modes** used by this job's sets, as switches.
  - **Sets**, grouped by when they're worn (Idle, Engaged, Resting, Spell precast, Spell midcast, Job ability,
    Weapon skill, Ranged, Item, Pet action, Manual). Each card shows the set's name, when it's worn, its conditions,
    and **the total of its bonuses** (HP+40 MP+60 INT+12 MAB+10...). A green **ON** marks the sets worn right now;
    a red or yellow number counts its problems. Right-click a card for Equip now, Duplicate, Move up / down,
    Turn off, Copy to job and Delete.
- **Right: the set editor.**
  - **Name**, and *Equip now* (puts it on and holds those slots until you click the *Held* chip or `/nswap unlock`),
    *Copy worn* (fill the set with what you're wearing), *Duplicate*, *Delete* (click twice).
  - **The equipment grid**: the game's 4 x 4 layout. Click a slot and the list beside it shows every piece you own
    that fits it and that the job can wear (where it is, its level). *Every item* searches every piece in the game,
    to plan a set before you have it. *Take off* makes the set leave the slot empty; *Leave alone* (or right-clicking
    the slot) takes the slot out of the set, so whatever is on stays on.
  - **Pieces that cover a slot**: a piece whose description says *Cannot equip headgear* (a cloak) or the like
    covers that slot. The slot is hatched in the grid, whatever the set has there stays off while the cloak is on
    (no more flipping between the two), and it isn't counted in the stat summary.
  - **Sorting by a stat**: *Sort by* over the piece list puts the pieces with the most of a stat first - any stat
    the pieces for that slot have (Accuracy, Haste, HP, MP, STR, MP while healing, Refresh, Pet: Accuracy...), augments
    included - and shows each piece's amount in gold. For "damage taken", "delay", "cost", "enmity" and "spell
    interruption", lower comes first. *Only with it* hides the rest. The search box finds stats too: type "haste".
  - **Totals**: with no slot picked, the set's bonuses added up from every piece's description, pet bonuses
    (Avatar:, Wyvern:, Automaton:) apart, and the bonuses that only count sometimes (Latent effect, Set:, days,
    weather...) listed under *Only sometimes*.
  - **Use this set when**:
    - *Use it for*: Idle, Engaged, Resting, Spell precast, Spell midcast, Job ability, Weapon skill, Ranged preshot,
      Ranged midshot, Item use, Pet action, Manual only.
    - Weapon skills: empty means every weapon skill; add names to narrow it (each one, or several).
    - Job abilities: the job's own come first; *Blood Pact: Rage*, *Blood Pact: Ward*, *Ready*, *Corsair Roll*,
      *Quick Draw* and *Rune Enchantment* cover every ability of that kind.
    - Spells: every spell, or by magic skill (Healing, Enhancing, Enfeebling, Elemental...), or by name.
    - Pet action: every pet move, or named ones (Blood Pacts, breaths...).
    - *Only when*: HP / MP below or at least a %, TP, a buff on or off, the support job, the day, the weather,
      the spell's element (or its matching the day / weather, for obis), Vana'diel time, moving, pet out, the pet's
      name, a mode, the area, your level (for level sync). Click a condition's name to turn it around (not).
    - *Priority*, and *Use this set* (off keeps it but never puts it on).
  - **Checks**: what's wrong with the set.

## Controller

Settings > **Controller**: turn on *Use a controller*, set an **Open / minimize** button (one, or two
held together such as Back + Start), and change any binding (Change, then press the button). The defaults cover Xbox
(XInput) and PlayStation-style (DirectInput) pads: A / B / X confirm / back / second action, LB / RB the tabs.

- **Jobs** (left): up / down picks a job (or Global), right or Confirm goes into its sets.
- **Sets / Commands** (middle): up / down, Confirm opens a set (and goes to its slots) or a command. The second action
  button is *Equip now* on a set, *Run* on a command. LB / RB switch Sets / Commands. Left goes back to the jobs.
  Up from the first one (or the only row of an empty list) is **+ New set** / **+ New command**: Confirm opens its
  menu, up / down and Confirm make one (a new set opens at its slots).
- **The job's options** (above the list): up from *+ New set* reaches the job's modes, Lockstyle and Macros. Up / down
  moves, left / right changes a value (book, page, Off / Global / Own), Confirm switches the Macros switch or a mode,
  and on an *Own* lockstyle opens its editor. The second action sets the macro book and page now.
- **Slots** (the equipment grid): the D-pad moves, Confirm lists the slot's gear, the second action empties the slot.
- **Gear** (the list beside the grid): up / down, Confirm puts the piece in the slot.
- **Back** goes one step back each time; from the jobs it minimizes NeoSwap.
- While NeoSwap is open its buttons don't reach the game (*Keep NeoSwap's buttons from the game*).
- Names, conditions and timings are set with the mouse and keyboard.

## Augments

NeoSwap reads the augments on your gear (the decoding is LuAshitacast's). In the piece list each copy is its own
row with its augments under the name in gold, so two of the same piece with different augments can be told apart.
Picking one makes the set ask for *that* copy: NeoSwap only puts on a copy with those augments (and Path / Rank, for
Delve and Dynamis gear). An augmented piece has a gold corner in the grid; its tooltip lists the augments. The
augments count in the set's totals, *Copy worn* keeps them, and the checks say if none of your copies has them.
Imported LuAshitacast entries with `Augment`, `AugPath` or `AugRank` keep them too.

## Commands (your own, per job)

A job's page has two tabs: **Sets** and **Commands**. A command is a list of steps NeoSwap runs for you, started with
its own slash word (`/siphon`), `/nswap run <name>`, or *Run* in the window (`/nswap stop` stops it).

Steps: *Cast a spell*, *Use an ability*, *Use a weapon skill*, *Use an item* (each with a target), *Send a command*
(anything you'd type), *Wait* (seconds), *Wait for my pet* / *Wait for no pet* (at most so long), *Wear a set* (held
until the command ends), *Switch a mode* / *Switch an entry* (on, off or toggle), *Cycle modes* (Normal, PDT, MDT: the next one on, the rest off), *Stop unless* (a condition). Any step can have *only when* (a condition: pet out, MP below
50%, a buff, the day...). A step that sends a command waits a second before the next. In names, `{spirit}` is the
elemental spirit for the weather (or, without elemental weather, the day); `{element}`, `{day}`, `{weather}` and `{pet}`
work too.

Ready-made (*+ New command*): **Elemental Siphon** for Summoner (`/siphon`): releases your avatar if one is out, calls
the spirit for the weather or day, waits for it, wears your *Siphon* set, uses Elemental Siphon, then releases the
spirit. And **Spirit for the day** (`/spirit`).

**Button on screen** (under a command's name): gives the command a button you can put anywhere on screen. Click it to
run the command (click again while it runs to stop it), drag it to move it. *Name* shows text (the command's name, or
a short label of your own); *Icon* shows an icon instead - travel and status items, a job emblem, or any item. A job's
command buttons show while you're that job; a custom entry's show on every job. *Lock command buttons* in the settings
(or `/nswap buttons lock`) stops them being dragged by accident; `/nswap buttons hide` hides them all.

## Import from LuAshitacast

**Import** (next to *+ New set*) lists the LuAshitacast profiles of this character
(`config\addons\luashitacast\<Name>_<id>\JOB.lua`). Pick one, the level to read it at (for profiles that change
gear by level), and *Read*.

A profile is a program, so NeoSwap runs it - without letting it touch the game: its commands, packets and events are
caught - and notes what it puts on: idle, engaged, resting, idle with a pet out, moving, every weapon skill / ability /
spell / pet move it mentions or the job can use, and ranged attacks. That becomes sets: the broad ones with their full
gear (Idle, every weapon skill, every spell, a magic skill), the narrow ones with only what they change (Savage Blade,
Cure IV, a pet out, Blood Pact: Rage). Its other named sets come too, unticked, as Manual sets (PDT, Siphon...: give
them a mode or a trigger). Its macro book / page and a set called Lockstyle are offered as well.

Profiles that change gear by level (`sets.base[10]`, `sets.ability.Jump[50]`...) are read at every level they change
at, up to the level you pick, and each set gets those levels: its first gear, then what changes at each later level
(see *Levels in a set*). Tick what you want, *Add to* or *Replace* the job's sets, and *Import*. Things a profile decides with its own
switches (a /pdt toggle, a TH mode) are read in their default state: those sets arrive as Manual ones.

## Custom server pieces

Some CatsEyeXI pieces (the Drifter set, Thermal Ring) have blank slot data in the game's item table, so no addon
can equip them by packet. NeoSwap knows them (`data/custom_items.lua`, add more there), offers them in their slots,
and puts them on with the game's `/equip` command.

## Custom entries (HELM, Fishing, Crafting...)

**+ New entry** at the bottom of the jobs list adds your own entry: name it, and click its icon to pick one -
gathering and crafting tools (pickaxe, sickle, hatchet, fishing rod, Gysahl Greens, crystals...), a job emblem, or any
item by searching. An entry has its own sets and commands, like a job, but works whatever your job is. Switch it
**Active** (on its page, or `/nswap entry HELM on|off|toggle`) and its sets go on over your job's: a HELM entry with an Idle
set of gathering gear is worn while you're idle, whatever job you're on. Off, its sets are only worn with *Equip now*
or a command. Its commands' slash words work from any job. *Delete entry* (click twice) removes it with its sets.

## Levels in a set

A set can hold gear for several levels. The buttons above the set's name are its levels: each shows the highest
level among its pieces (that's the level it's worn from), and **+** adds a new one. At your level, every level of
the set at or below it is put on, lowest first, so lower gear carries forward until a higher level replaces that
slot. In the grid, a slot a level doesn't fill shows the piece carried on from below, faded. A level left empty goes
away when you switch to another (a set always keeps one). A gold dot marks the level your job wears now; the totals
show the set as worn at the picked level, and the card's summary as worn at your job's level.

## How sets combine

Sets go on one over the other, so a set only needs the slots it changes:

1. **Idle is the base.** Your Idle sets are always worn (add the condition *Status is Idle* to keep one out of fights,
   like a movement-speed set).
2. **Engaged / Resting / Chocobo riding** sets go on over Idle. *Chocobo riding* is on while you stand at a chocobo
   stable (one of its chocobos within 8 yalms, so the set is on when you rent and get on), while you use a Chocobo
   Whistle, and while you ride.
3. **Actions** - weapon skills, abilities, spells, ranged, items - go on over whatever is worn when they happen.
4. **Pet actions** go on over everything while your pet acts.

Inside each of those: broad first, narrow last (every weapon skill, then named ones; every spell, then a magic skill,
then named spells; a set with more conditions counts as narrower), then by priority (higher on top), then by list
order (lower on top).

## Checks

- **In a set**: no name, a name used twice, a piece the job can't wear or is too low a level for, a piece you don't
  have, a piece in the Mog House or a satchel / sack / case (move it to your Inventory or a Wardrobe), the same piece
  in two slots when you own one, a two-handed weapon with anything but a grip in Sub, a name the game doesn't know.
- **Between sets**: two sets worn at the same moment (same trigger, same names or skill, same conditions, same
  priority) with different gear in the same slot. Which wins would be down to list order, so NeoSwap flags it:
  give one a higher priority or another condition.

## Commands

| Command | |
|---|---|
| `/nswap` | show or hide the window (`/neoswap` too) |
| `/nswap on` / `off` | turn swapping on or off |
| `/nswap set <name>` | put on a set of your job now and hold it |
| `/nswap unlock` | let go of held slots |
| `/nswap run <command>` | run one of the job's own commands (or type its /word) |
| `/nswap stop` | stop the running command |
| `/nswap mode <name> [on\|off\|toggle]` | switch a mode (toggle: the other way; also with no word) |
| `/nswap cycle <mode> <mode> ...` | the next mode in the row goes on, the others off (Normal PDT MDT) |
| `/nswap modes` | list your modes |
| `/nswap disable <slot\|all>` / `enable` | NeoSwap leaves a slot alone / stops |
| `/nswap lockstyle` | set your job's lockstyle now |
| `/nswap macros` | change to your job's macro book and page now |
| `/nswap job <JOB>` | show a job in the window |
| `/nswap debug` | print every swap in chat |
| `/nswap buttons [show\|hide\|lock\|unlock]` | the on-screen command buttons (no word: show / hide) |
| `/nswap item <name>` | what the game's data says about a piece (slots, jobs, level, icon) and how NeoSwap puts it on |
| `/nswap save` | write your sets now |
| `/nswap config` | settings |
| `/nswap min` | minimize to the NSWP bubble |
| `/nswap opacity 60` | opacity (20 to 100) |

## Where your sets are

`config\addons\neoswap\<Name>_<id>\sets.lua`, per character, saved a second after each change (the previous file
is kept as `sets.lua.bak`). It's a plain Lua table you can back up or share.

## Timing

Like LuAshitacast, a set for an action is held until the action ends (the game says so) or until its time runs
out: a spell's cast time cut by your Fast Cast plus a margin, a weapon skill 3 s, an ability 2.5 s, a ranged attack
10 s cut by Snapshot. Settings > Timing changes them.

## Releasing (for the maintainer)

Bump `addon.version` in `neoswap.lua` and push to `main`: the *Release* workflow tags the commit `v<version>`,
builds `NeoSwap-<version>.zip` and publishes the release. Put the description in `release-notes/<version>.md`
(GitHub's generated notes are used if there's none). It can also be run by hand from the Actions tab.
