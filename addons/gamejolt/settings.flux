// The Game Jolt plugin's section of the project's settings: a page of
// Project Settings, under Plugins. The game reads it with
// `app.pluginSettings("game_jolt")`.

struct Settings {
    @group("Game")
    /// The game's ID: on Game Jolt, the game's page, Manage Game, Game API,
    /// API Settings.
    @export var game_id: string = "";
    /// The game's private key, from the same page. Kept in
    /// .fluxion/secrets.json, out of the project file and of version
    /// control; an export puts it in the game's pack, where a player can
    /// find it, as in every game that signs its own requests.
    @export @secret var private_key: string = "";

    @group("Player")
    /// Log the player in as the game starts: the one Game Jolt's launcher or
    /// site runs it for, or the editor's debug player on Play.
    @export var log_in_by_itself: bool = true;
    /// Once logged in, keep a session open - pinged every 30 seconds, idle
    /// while the game is behind another program - so Game Jolt counts the
    /// time played.
    @export var keep_a_session_open: bool = true;

    @group("Advanced")
    /// Where the API is: empty for Game Jolt's own.
    @export var api_address: string = "";
}
