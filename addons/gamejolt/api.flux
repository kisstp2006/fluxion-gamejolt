// Game Jolt's game API, version 1.2: a request made and signed as it wants
// it, and its answer read. The game's singleton and the plugin's editor part
// both send through here. https://gamejolt.com/game-api/doc

const hash = @import("hash");
const url = @import("url");

/// Where the requests go, unless the settings say otherwise.
const default_address = "https://api.gamejolt.com/api/game/v1_2/";

/// What a request is sent and signed with: the game's ID and private key,
/// from the plugin's settings, and where the API is.
struct Keys {
    var game_id: string = "";
    var private_key: string = "";
    var address: string = default_address;

    /// Whether there is a game to ask about.
    fn ready(self) bool {
        return self.game_id != "" and self.private_key != "";
    }
}

/// The game's keys, as the project's settings for the plugin say: in the
/// game or in the editor.
fn keysNow() Keys {
    const settings: any = app.pluginSettings("game_jolt") catch null;
    if (settings == null) return Keys{};
    var keys = Keys{ .game_id = settings.game_id, .private_key = settings.private_key };
    if (settings.api_address != "") keys.address = settings.api_address;
    return keys;
}

/// The address of `endpoint` with `params`, the game's ID and the format,
/// signed as Game Jolt asks: the MD5 of the address and the private key.
fn address(keys: Keys, endpoint: string, params: [string: string]) string {
    const unsigned = unsignedAddress(keys, endpoint, params);
    return f"{unsigned}&signature={hash.md5(unsigned + keys.private_key)}";
}

fn unsignedAddress(keys: Keys, endpoint: string, params: [string: string]) string {
    var all = params.copy();
    all["game_id"] = keys.game_id;
    all["format"] = "json";
    return f"{keys.address}{endpoint}/?{url.query(all)}";
}

/// The same, for a request whose `form` goes as its body - a large value of
/// the data store's: the form's keys and values, in the order of the keys,
/// are signed after the address.
fn postAddress(keys: Keys, endpoint: string, params: [string: string], form: [string: string]) string {
    const unsigned = unsignedAddress(keys, endpoint, params);
    var signed = unsigned;
    var names = form.keys();
    names.sort();
    for (names) |name| {
        signed = signed + name + form[name];
    }
    return f"{unsigned}&signature={hash.md5(signed + keys.private_key)}";
}

/// A request inside a batch: its path, signed as a request of its own.
fn batchPart(keys: Keys, endpoint: string, params: [string: string]) string {
    var all = params.copy();
    all["game_id"] = keys.game_id;
    const unsigned = f"/{endpoint}/?{url.query(all)}";
    return f"{unsigned}&signature={hash.md5(unsigned + keys.private_key)}";
}

/// The address of a batch of `parts`, each made with `batchPart`.
fn batchAddress(keys: Keys, parts: [string], parallel: bool, break_on_error: bool) string {
    var query = f"game_id={url.encode(keys.game_id)}";
    for (parts) |part| {
        query = query + "&requests[]=" + url.encode(part);
    }
    if (parallel) {
        query = query + "&parallel=true";
    }
    if (break_on_error) {
        query = query + "&break_on_error=true";
    }
    const unsigned = f"{keys.address}batch/?{query}&format=json";
    return f"{unsigned}&signature={hash.md5(unsigned + keys.private_key)}";
}

/// Ask `endpoint` with `params`, and give what its answer's `response`
/// holds - or an error with what went wrong: the keys not set, the web, or
/// Game Jolt's own message.
fn send(keys: Keys, endpoint: string, params: [string: string]) !any {
    if (!keys.ready()) {
        return error.NoKeys("set the game's ID and private key: Project Settings, Plugins, Game Jolt");
    }
    const reply = await web.get(address(keys, endpoint, params)) catch |e| {
        return error.Web(e.message orelse e.name);
    };
    return answerOf(reply);
}

/// `send`, with `form` as the request's body.
fn sendForm(keys: Keys, endpoint: string, params: [string: string], form: [string: string]) !any {
    if (!keys.ready()) {
        return error.NoKeys("set the game's ID and private key: Project Settings, Plugins, Game Jolt");
    }
    const reply = await web.postForm(postAddress(keys, endpoint, params, form), form) catch |e| {
        return error.Web(e.message orelse e.name);
    };
    return answerOf(reply);
}

/// Several requests in one: `parts` made with `batchPart`.
fn sendBatch(keys: Keys, parts: [string], parallel: bool, break_on_error: bool) !any {
    if (!keys.ready()) {
        return error.NoKeys("set the game's ID and private key: Project Settings, Plugins, Game Jolt");
    }
    const reply = await web.get(batchAddress(keys, parts, parallel, break_on_error)) catch |e| {
        return error.Web(e.message orelse e.name);
    };
    return answerOf(reply);
}

/// What Game Jolt answered, read: its `response`, when it says it worked.
/// It answers 200 either way, and says so inside.
fn answerOf(reply: Response) !any {
    if (!reply.ok) {
        return error.Web(f"Game Jolt answered {reply.status}");
    }
    const data = reply.json();
    if (data == null) {
        return error.Unreadable("Game Jolt's answer is not JSON");
    }
    const response = data.get("response");
    if (response == null) {
        return error.Unreadable("Game Jolt's answer has no response");
    }
    if (str(response.get("success", "false")) != "true") {
        return error.Refused(str(response.get("message", "Game Jolt said no")));
    }
    return response;
}
