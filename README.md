# fluxion-gamejolt

[Game Jolt's game API](https://gamejolt.com/game-api/doc) for games made with
[Fluxion](https://github.com/kisstp2006/fluxion-editor): a plugin, in
[`addons/gamejolt`](addons/gamejolt), and this folder a Fluxion project that
uses it.

- **The plugin** - see [its README](addons/gamejolt/README.md): the player
  logged in by itself on Game Jolt's site and from its launcher, a session
  kept, trophies, scores, the data store, friends, the server's time and
  batches, from Flux; and in the editor a panel to try the game's keys, a
  debug player for Play, and the game's page in Project, Tools.
- **The example** - open this folder in the Fluxion editor. Set the game's ID
  and private key in Project Settings, under Plugins, Game Jolt, and a debug
  player in the Game Jolt panel; Play logs them in, gives a trophy - its ID is
  an `@export` of the `Status` entity's script - and a score, and lists the
  score tables.

It needs Fluxion engine 0.3.1 or newer: the `web` global, the `hash` and `url`
modules, and plugins.

## Licence

MIT: see [LICENSE](LICENSE).
