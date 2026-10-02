// A line that says how Game Jolt stands for the game: the player logged in,
// or why nobody is. The Game Jolt status preset's.

struct StatusLabel {
    fn ready(self) {
        const found = app.find("GameJolt");
        if (found == null) {
            self.say("Game Jolt: the plugin is not turned on");
            return;
        }
        const gj = found.?.script();
        gj.logged_in.connect(self.loggedIn);
        gj.log_in_failed.connect(self.failed);
        if (gj.isLoggedIn()) {
            self.loggedIn(gj.name);
        } else {
            self.say("Game Jolt: nobody logged in");
        }
    }

    fn say(self, words: string) {
        self.entity.get(Text2D).text = words;
    }

    fn loggedIn(self, name: string) {
        self.say(f"Game Jolt: {name}");
    }

    fn failed(self, why: string) {
        self.say(f"Game Jolt: {why}");
    }
}
