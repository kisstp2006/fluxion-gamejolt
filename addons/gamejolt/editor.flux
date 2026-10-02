// The Game Jolt plugin's part in the editor: a panel to try the game's keys,
// see its trophies and score tables and what was asked; the debug player a
// Play logs in as; and the game's page, in Project > Tools.

const api = @import("api.flux");

struct GameJoltEditor {
    var plugin: any = null;
    /// What was asked and answered, the newest last.
    var asked: [string] = [];
    var trophies: [any] = [];
    var tables: [any] = [];
    var busy: bool = false;

    fn start(self, plugin: Plugin) {
        self.plugin = plugin;
        editor.addPanel("panel", "Game Jolt", "bottom", self.draw);
        editor.addCommand("show", "Game Jolt panel", self.show);
        editor.addMenuItem("tools", "show");
        editor.addCommand("page", "Open the game's Game Jolt page", self.openPage);
        editor.addMenuItem("tools", "page");
        editor.addPlayHook(self.play);
    }

    fn show(self) {
        editor.showPanel("panel");
    }

    fn openPage(self) {
        const keys = api.keysNow();
        if (keys.game_id == "") {
            editor.say("Set the game's ID first: Project Settings, Plugins, Game Jolt");
            return;
        }
        app.openUrl(f"https://gamejolt.com/games/game/{keys.game_id}") catch {
            editor.say("The page did not open");
        };
    }

    /// Play: the game logs in as the debug player, if there is one.
    fn play(self, play: Play) {
        const name = str(self.plugin.setting("debug_user", ""));
        if (name == "") {
            return;
        }
        play.addArgument("gj-user", name);
        play.addArgument("gj-token", str(self.plugin.setting("debug_token", "")));
    }

    fn draw(self, ui: EditorUi) {
        const keys = api.keysNow();
        if (!keys.ready()) {
            ui.message("Set the game's ID and private key in Project Settings, Plugins, Game Jolt.", "warning");
        } else {
            ui.label(f"Game {keys.game_id}", "dim");
        }

        ui.heading("Debug player");
        ui.label("Who a Play logs in as. Kept for you, not in the project.", "dim");
        ui.label("Name", "plain");
        const name = ui.textField("debug-user", str(self.plugin.setting("debug_user", "")));
        if (name != str(self.plugin.setting("debug_user", ""))) {
            self.plugin.setSetting("debug_user", name) catch {};
        }
        ui.label("Game token: on Game Jolt, your avatar's menu, Game Token", "plain");
        const token = ui.secretField("debug-token", str(self.plugin.setting("debug_token", "")));
        if (token != str(self.plugin.setting("debug_token", ""))) {
            self.plugin.setSetting("debug_token", token) catch {};
        }
        if (ui.button("Test login") and !self.busy) {
            _ = self.testLogin(name, token);
        }

        ui.separator();
        ui.heading("The game");
        if (ui.button("Load trophies and tables") and !self.busy) {
            _ = self.load(name, token);
        }
        for (self.trophies) |trophy| {
            const id = str(trophy.get("id", ""));
            const title = str(trophy.get("title", ""));
            const difficulty = str(trophy.get("difficulty", ""));
            ui.label(f"Trophy {id}: {title} ({difficulty})", "plain");
        }
        for (self.tables) |table| {
            const id = str(table.get("id", ""));
            const called = str(table.get("name", ""));
            ui.label(f"Table {id}: {called}", "plain");
        }

        ui.separator();
        ui.heading("Asked");
        if (self.asked.is_empty()) {
            ui.label("Nothing yet.", "dim");
        }
        for (self.asked) |line| {
            ui.label(line, "dim");
        }
    }

    fn say(self, line: string) {
        self.asked.push(line);
        while (self.asked.len > 8) {
            _ = self.asked.remove(0);
        }
    }

    fn testLogin(self, name: string, token: string) {
        self.busy = true;
        defer self.busy = false;
        _ = await api.send(api.keysNow(), "users/auth", {"username": name, "user_token": token}) catch |e| {
            self.say(f"users/auth: {e.message orelse e.name}");
            return;
        };
        self.say(f"users/auth: logged in as {name}");
    }

    fn load(self, name: string, token: string) {
        self.busy = true;
        defer self.busy = false;
        const keys = api.keysNow();
        const found = await api.send(keys, "trophies", {"username": name, "user_token": token}) catch |e| {
            self.say(f"trophies: {e.message orelse e.name}");
            return;
        };
        self.trophies = found.get("trophies", []);
        self.say(f"trophies: {self.trophies.len}");
        const tables = await api.send(keys, "scores/tables", {}) catch |e| {
            self.say(f"scores/tables: {e.message orelse e.name}");
            return;
        };
        self.tables = tables.get("tables", []);
        self.say(f"scores/tables: {self.tables.len}");
    }
}
