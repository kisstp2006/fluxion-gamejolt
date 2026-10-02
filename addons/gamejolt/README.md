# Game Jolt API for Fluxion

A Fluxion plugin for [Game Jolt's game API](https://gamejolt.com/game-api/doc):
the player logged in by itself, a session kept, trophies, scores, the data
store, friends, the server's time and batches - from the game - and a panel
in the editor to try it.

## Putting it in a game

1. Copy this folder into your project as `res://addons/gamejolt`, or install
   the repository's `.zip` from Project Settings, Plugins, Install from
   file....
2. Turn it on in Project Settings, Plugins.
3. In Project Settings, General, under Plugins, Game Jolt: the game's ID and
   private key, from your game's page on Game Jolt, Manage Game, Game API,
   API Settings. The private key is kept in the project's
   `.fluxion/secrets.json`, out of the project file and of version control.

The game gets a singleton, `GameJolt`, opened before the project's own
autoloads. A script finds it with `app.find("GameJolt").?.script()`.

## The player

As the game starts, the plugin logs in the player Game Jolt runs it for:

- on Game Jolt's site, the page's `gjapi_username` and `gjapi_token`;
- from Game Jolt's launcher, the `.gj-credentials` file beside the program;
- from the editor's Play, the debug player set in the Game Jolt panel.

Nobody to log in is no mistake. Once a player is known, `logged_in` is said
with their name; if logging in did not work, `log_in_failed` with why. A
session then opens, pinged every 30 seconds - idle while the game is behind
another program - and closed as the game ends. Both are settings.

```
fn ready(self) {
    const gj = app.find("GameJolt").?.script();
    gj.logged_in.connect(self.loggedIn);
}

fn loggedIn(self, name: string) {
    const gj = app.find("GameJolt").?.script();
    await gj.achieve(12345) catch |e| print("no trophy:", e.message orelse e.name);
}
```

## The calls

Each is a task: `await` it, and `catch` what can go wrong - the keys not set,
the web, or Game Jolt's own message. Two at once are two tasks, each with its
own answer.

| Call | What it does |
| --- | --- |
| `logIn(name, token)`, `logOut()`, `isLoggedIn()` | The player, by hand |
| `user(name = "")` | A player's details: by name, or the one logged in |
| `friends()` | The player's friends' user IDs |
| `openSession()`, `closeSession()` | The session, by hand |
| `achieve(id)`, `unachieve(id)`, `trophies(achieved = "")` | Trophies |
| `addScore(score, sort, table_id = 0, extra_data = "", guest = "Guest")` | A score: the player's, or a guest's |
| `scores(table_id = 0, limit = 10, mine = false)`, `rank(sort, table_id = 0)`, `tables()` | Scores and tables |
| `getData(key, mine = false)`, `setData(key, data, mine = false)` | The data store: the game's, or the player's with `mine` |
| `updateData(key, operation, value, mine = false)`, `removeData(key, mine = false)`, `dataKeys(mine = false, pattern = "")` | |
| `serverTime()` | The time on Game Jolt's server |
| `part(endpoint, params)`, `batch(parts, parallel = false, break_on_error = false)` | Up to 50 requests in one |

`setData` sends its value as the request's body, so it may be long. Every
request is signed as Game Jolt asks, with the MD5 of its address and the
private key.

## In the editor

- **Game Jolt status**, in the Hierarchy's + list under Game Jolt: a line of
  text that says who is logged in, or why nobody is - a copy of
  `presets/status_label.json`, its script the plugin's.
- **Game Jolt panel** (Project, Tools, Game Jolt panel): the debug player a
  Play logs in as - kept for you, not in the project - with Test login; the
  game's trophies and score tables; and what was asked.
- **Project, Tools, Open the game's Game Jolt page.**

## A word on the private key

A game that signs its own requests carries its private key: an export puts
it in the game's pack, and a player who looks can find it. That is so for
every game that talks to Game Jolt's game API directly.

## Licence

MIT: see [LICENSE](LICENSE).
