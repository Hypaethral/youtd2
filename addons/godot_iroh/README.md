The godot-iroh plugin is not committed to the git repo (same as the WebRTC
plugin). You need to install it separately. It provides the "Internet (P2P)"
multiplayer connection option (a QUIC peer-to-peer transport that prefers direct
connections and falls back to public relays).

The plugin is a native GDExtension, so it is only available on desktop builds
(Windows / Linux / macOS). On platforms where it isn't installed, the
"Internet (P2P)" button is hidden automatically.

The plugin is not often maintained and can no longer be nabbed from the asset store

original repo: https://github.com/tipragot/godot-iroh
fork with latest updates: https://github.com/Hypaethral/godot-iroh

You can copy artifacts from GHA runs in the above repos, or build from source with
`cargo build --release`. Ensure that the godot_iroh.gdextension file refers to the 
actual paths of your .dll / .so / .dylib files

Once installed, the extension registers the `IrohServer` / `IrohClient` classes
(and an `IrohRuntime` singleton) that the game's Iroh connection flow uses. Not installing
this networking feature is handled gracefully and it is not required for development.
