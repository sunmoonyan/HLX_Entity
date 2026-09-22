# hlx_entity

A Helix plugin (`Entity`) that provides a generic item base for turning any
world entity - or a plain decorative prop - into a Helix item that players
can carry, place, own, pick back up, and (for police) seize. Nothing on its
own; other plugins (e.g. `hlx_halflife_entity`) build their item catalog on
top of it.

## The core idea: `base_entity`

Every item using this system inherits from the `base_entity` item base
(`items/base/sh_entity.lua`). An item built on it just needs a handful of
fields:

```lua
ITEM.name = "..."
ITEM.model = "models/..."        -- inventory icon / dropped-on-ground look
ITEM.dropModel = "models/..."    -- optional: different look when just dropped
ITEM.entityclass = "item_suit"   -- the real entity class to spawn (nil = plain prop_physics)
ITEM.deployable = false          -- see "Two ways to place an item" below
```

That's it - `base_entity` supplies everything else: placing the entity in
the world, tracking who owns it, letting the owner pick it back up into
their inventory, and (optionally) per-item `Save`/`Load` to persist state
(health, ammo, whatever) across the pickup/place cycle.

If `entityclass` is left `nil`, placing the item spawns a plain
`prop_physics` using `ITEM.model` - i.e. a decorative prop with no special
behavior, like furniture.

## Two ways to place an item

`ITEM.deployable` picks which of the two placement paths an item uses:

- **`deployable = false`** - small/handheld items. Right-clicking the item
  in the inventory offers **Place**, which spawns it instantly on the
  ground in front of the player (raytraced, range- and ownership-limited).
  Good for handheld objects like weapons or ammo.
- **`deployable = true`** - furniture-sized items. Right-clicking offers
  **Deploy** instead, which gives the player the `ix_building` SWEP
  (`entities/weapons/ix_building.lua`). That SWEP shows a translucent ghost
  preview, lets the player rotate it (primary/secondary fire) and confirm
  placement (reload), then networks the final position/angle to the server
  to actually spawn it. Good for furniture and anything too large to just
  drop in front of the player.

Both paths end up calling the same server-side machinery
(`ix.entityplacing.SetOwner`, `item:Load`, deploy sound/effects, etc.), so
an item only has to declare which path it wants via `deployable`.

## Ownership, pickup, and seizure

Every entity placed through this system is tagged with the owning
character's ID (`ix.entityplacing.SetOwner`/`GetOwnerID`/`IsOwner`). Owners
can walk up and press **G** to pick their item back up into their inventory
(or drop it on the ground if the inventory is full). If a `HelixPoliceConfig`
is present and lists the entity's class as illegal, a police character can
seize it instead of picking it up, with its own action/notification.

Constructed furniture (spawned through the `ix_building` SWEP) additionally
supports **Ctrl+E** to pick a piece back up without needing the G-prompt
flow, as a shortcut.

## Limits and cleanup

- `ix.config` option **`maxCharacterEntities`** (default 30) caps how many
  entities a single character can have placed in the world at once, across
  both plain props and item-ent placements. Players get warned as they
  approach the limit and blocked once they hit it.
- Admin commands **`/charremoveprops`** and **`/charremoveentities`** let
  staff wipe a character's placed props (or everything, including
  functional item-ent entities) - handy for cleaning up after a griefer or
  a leftover build.
