// GameJolt: Game Jolt's game API in the game - the player, a session,
// trophies, scores, the data store, friends and the server's time. The
// plugin's manifest opens it before the project's own autoloads; a script
// finds it with `app.find("GameJolt").?.script()`.
//
// Each call is a task that ends with what Game Jolt said, or an error with
// why not: `await` it, and `catch` what can go wrong. Two calls at once are
// two tasks, each with its own answer.

const api = @import("api.flux");

struct GameJolt {
    /// Said once the player is known.
    signal logged_in(name: string);
    /// Said when logging in did not work, with why.
    signal log_in_failed(why: string);

    var keys: api.Keys = api.Keys{};
    /// The player, once logged in.
    var name: string = "";
    var token: string = "";
    var settings: any = null;
    var session_open: bool = false;
    var in_front: bool = true;

    fn ready(self) {
        self.keys = api.keysNow();
        self.settings = app.pluginSettings("game_jolt") catch null;
        app.focus_changed.connect(self.focusChanged);
        app.quitting.connect(self.quitting);
        if (self.settings != null and self.settings.log_in_by_itself) {
            self.logInByItself();
        }
    }

    // ---------------------------------------------------------------------
    // The player
    // ---------------------------------------------------------------------

    /// Whether a player is logged in.
    fn isLoggedIn(self) bool {
        return self.name != "";
    }

    /// Log in the player Game Jolt runs the game for: the page's
    /// `gjapi_username` and `gjapi_token` on the web, the launcher's
    /// `.gj-credentials` beside the program, or the editor's debug player,
    /// which Play passes. Nobody to log in is no mistake.
    fn logInByItself(self) {
        const page_name = app.pageParameter("gjapi_username");
        const page_token = app.pageParameter("gjapi_token");
        if (page_name != null and page_token != null) {
            _ = self.logIn(page_name.?, page_token.?);
            return;
        }
        const credentials = files.readText("program://.gj-credentials") catch "";
        const lines = credentials.lines();
        if (lines.len >= 3) {
            _ = self.logIn(lines[1].trim(), lines[2].trim());
            return;
        }
        const debug_name = app.commandArgument("gj-user");
        if (debug_name != null and debug_name.? != "") {
            _ = self.logIn(debug_name.?, app.commandArgument("gj-token") orelse "");
        }
    }

    /// Log in as `name` with their game token: `logged_in` once it worked,
    /// `log_in_failed` if not. A session opens after, if the settings keep
    /// one.
    fn logIn(self, name: string, token: string) {
        _ = await api.send(self.keys, "users/auth", {"username": name, "user_token": token}) catch |e| {
            self.log_in_failed.emit(e.message orelse e.name);
            return;
        };
        self.name = name;
        self.token = token;
        self.logged_in.emit(name);
        if (self.settings != null and self.settings.keep_a_session_open) {
            _ = self.openSession();
        }
    }

    /// Log out: the session closed, the player forgotten.
    fn logOut(self) {
        self.closeSession();
        self.name = "";
        self.token = "";
    }

    /// The player's own `username` and `user_token`, for a request.
    fn player(self) [string: string] {
        return {"username": self.name, "user_token": self.token};
    }

    fn needPlayer(self) !void {
        if (!self.isLoggedIn()) {
            return error.NotLoggedIn("no player is logged in");
        }
    }

    /// A player's details: theirs by name, or the one logged in.
    fn user(self, name: string = "") !any {
        const wanted = if (name != "") name else self.name;
        const answer = try await api.send(self.keys, "users", {"username": wanted});
        return answer.get("users")[0];
    }

    /// The player's friends, by their user IDs.
    fn friends(self) !any {
        try self.needPlayer();
        const answer = try await api.send(self.keys, "friends", self.player());
        return answer.get("friends", []);
    }

    // ---------------------------------------------------------------------
    // The session
    // ---------------------------------------------------------------------

    /// Open a session for the player and keep it: pinged every 30 seconds,
    /// `active` while the game is in front and `idle` behind, until it is
    /// closed or the game ends.
    fn openSession(self) {
        if (!self.isLoggedIn() or self.session_open) {
            return;
        }
        _ = await api.send(self.keys, "sessions/open", self.player()) catch return;
        self.session_open = true;
        while (self.session_open) {
            await wait(30.0);
            if (!self.session_open) {
                return;
            }
            var params = self.player();
            params["status"] = if (self.in_front) "active" else "idle";
            _ = await api.send(self.keys, "sessions/ping", params) catch null;
        }
    }

    /// Close the session; the answer is not waited for.
    fn closeSession(self) {
        if (!self.session_open) {
            return;
        }
        self.session_open = false;
        _ = web.get(api.address(self.keys, "sessions/close", self.player()));
    }

    fn focusChanged(self, front: bool) {
        self.in_front = front;
    }

    fn quitting(self) {
        self.closeSession();
    }

    // ---------------------------------------------------------------------
    // Trophies
    // ---------------------------------------------------------------------

    /// Give the player a trophy.
    fn achieve(self, trophy_id: int) !void {
        try self.needPlayer();
        var params = self.player();
        params["trophy_id"] = str(trophy_id);
        _ = try await api.send(self.keys, "trophies/add-achieved", params);
    }

    /// Take a trophy back from the player.
    fn unachieve(self, trophy_id: int) !void {
        try self.needPlayer();
        var params = self.player();
        params["trophy_id"] = str(trophy_id);
        _ = try await api.send(self.keys, "trophies/remove-achieved", params);
    }

    /// The game's trophies, with whether the player has each: all of them,
    /// or only those `achieved` says.
    fn trophies(self, achieved: string = "") !any {
        try self.needPlayer();
        var params = self.player();
        if (achieved != "") {
            params["achieved"] = achieved;
        }
        const answer = try await api.send(self.keys, "trophies", params);
        return answer.get("trophies", []);
    }

    // ---------------------------------------------------------------------
    // Scores
    // ---------------------------------------------------------------------

    /// A score for the player - or for `guest`, by that name, when nobody
    /// is logged in. `score` is how it reads, `sort` the number it is
    /// ranked by.
    fn addScore(self, score: string, sort: int, table_id: int = 0, extra_data: string = "", guest: string = "Guest") !void {
        var params: [string: string] = {"score": score, "sort": str(sort)};
        if (self.isLoggedIn()) {
            params["username"] = self.name;
            params["user_token"] = self.token;
        } else {
            params["guest"] = guest;
        }
        if (table_id != 0) {
            params["table_id"] = str(table_id);
        }
        if (extra_data != "") {
            params["extra_data"] = extra_data;
        }
        _ = try await api.send(self.keys, "scores/add", params);
    }

    /// A table's best scores - the game's main table for 0 - or only the
    /// player's.
    fn scores(self, table_id: int = 0, limit: int = 10, mine: bool = false) !any {
        var params: [string: string] = {"limit": str(limit)};
        if (table_id != 0) {
            params["table_id"] = str(table_id);
        }
        if (mine) {
            try self.needPlayer();
            params["username"] = self.name;
            params["user_token"] = self.token;
        }
        const answer = try await api.send(self.keys, "scores", params);
        return answer.get("scores", []);
    }

    /// Where a `sort` would rank in a table.
    fn rank(self, sort: int, table_id: int = 0) !int {
        var params: [string: string] = {"sort": str(sort)};
        if (table_id != 0) {
            params["table_id"] = str(table_id);
        }
        const answer = try await api.send(self.keys, "scores/get-rank", params);
        return int(str(answer.get("rank", "0"))) catch 0;
    }

    /// The game's score tables.
    fn tables(self) !any {
        const answer = try await api.send(self.keys, "scores/tables", {});
        return answer.get("tables", []);
    }

    // ---------------------------------------------------------------------
    // The data store: the game's, or the player's own with `mine`
    // ---------------------------------------------------------------------

    fn storeParams(self, key: string, mine: bool) ![string: string] {
        var params: [string: string] = {"key": key};
        if (mine) {
            try self.needPlayer();
            params["username"] = self.name;
            params["user_token"] = self.token;
        }
        return params;
    }

    /// What `key` holds.
    fn getData(self, key: string, mine: bool = false) !string {
        const answer = try await api.send(self.keys, "data-store", try self.storeParams(key, mine));
        return str(answer.get("data", ""));
    }

    /// Keep `data` under `key`. It goes as the request's body, so it may be
    /// long.
    fn setData(self, key: string, data: string, mine: bool = false) !void {
        _ = try await api.sendForm(self.keys, "data-store/set", try self.storeParams(key, mine), {"data": data});
    }

    /// Change what `key` holds in place - `add`, `subtract`, `multiply`,
    /// `divide`, `append`, `prepend` - and give what it holds after.
    fn updateData(self, key: string, operation: string, value: string, mine: bool = false) !string {
        var params = try self.storeParams(key, mine);
        params["operation"] = operation;
        params["value"] = value;
        const answer = try await api.send(self.keys, "data-store/update", params);
        return str(answer.get("data", ""));
    }

    /// Take `key` out of the store.
    fn removeData(self, key: string, mine: bool = false) !void {
        _ = try await api.send(self.keys, "data-store/remove", try self.storeParams(key, mine));
    }

    /// The keys in the store, all or those `pattern` matches (`*` for any
    /// run of characters).
    fn dataKeys(self, mine: bool = false, pattern: string = "") !any {
        var params: [string: string] = {};
        if (mine) {
            try self.needPlayer();
            params = self.player();
        }
        if (pattern != "") {
            params["pattern"] = pattern;
        }
        const answer = try await api.send(self.keys, "data-store/get-keys", params);
        return answer.get("keys", []);
    }

    // ---------------------------------------------------------------------
    // The rest
    // ---------------------------------------------------------------------

    /// The time on Game Jolt's server: `timestamp`, `timezone`, `year` and
    /// the rest.
    fn serverTime(self) !any {
        return try await api.send(self.keys, "time", {});
    }

    /// A request for a batch: what `batch` takes a list of. `params` is a
    /// map of what the endpoint takes, its values written as text.
    fn part(self, endpoint: string, params: any) string {
        var given: [string: string] = {};
        for (params) |key, value| {
            given[str(key)] = str(value);
        }
        return api.batchPart(self.keys, endpoint, given);
    }

    /// Up to 50 requests in one, each made with `part`: their answers, in
    /// order.
    fn batch(self, parts: any, parallel: bool = false, break_on_error: bool = false) !any {
        var given: [string] = [];
        for (parts) |each| {
            given.push(str(each));
        }
        const answer = try await api.sendBatch(self.keys, given, parallel, break_on_error);
        return answer.get("responses", []);
    }
}
