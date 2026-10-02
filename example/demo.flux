// The example: the player logged in by the plugin - as Game Jolt runs the
// game, or as the editor's debug player on Play - greeted, given a trophy
// and a score, and the game's tables listed.

struct Demo {
    /// A trophy of the game's to give, by its ID: 0 for none.
    @export var trophy_id: int = 0;
    /// A score table to add a score to: 0 for the game's main one.
    @export var table_id: int = 0;

    fn ready(self) {
        const found = app.find("GameJolt");
        if (found == null) {
            self.say("The Game Jolt plugin is not turned on: Project Settings, Plugins.");
            return;
        }
        const gj = found.?.script();
        gj.logged_in.connect(self.loggedIn);
        gj.log_in_failed.connect(self.failed);
        if (!gj.keys.ready()) {
            self.say("Set the game's ID and private key: Project Settings, Plugins, Game Jolt.");
        } else {
            self.say("Nobody logged in yet: run the game from Game Jolt, or set a debug player in the editor's Game Jolt panel.");
        }
    }

    fn say(self, words: string) {
        self.entity.get(Text2D).text = words;
        print(words);
    }

    fn failed(self, why: string) {
        self.say(f"Logging in did not work: {why}");
    }

    fn loggedIn(self, name: string) {
        self.say(f"Hello, {name}!");
        _ = self.reward();
    }

    fn reward(self) {
        const gj = app.find("GameJolt").?.script();
        if (self.trophy_id != 0) {
            await gj.achieve(self.trophy_id) catch |e| print("the trophy:", e.message orelse e.name);
        }
        await gj.addScore("100 points", 100, self.table_id) catch |e| print("the score:", e.message orelse e.name);
        const tables = await gj.tables() catch |e| {
            print("the tables:", e.message orelse e.name);
            return;
        };
        print("score tables:", tables.len);
    }
}
