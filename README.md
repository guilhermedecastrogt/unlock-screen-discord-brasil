# screen-discord-brasil

A proof of concept (PoC) showing that the **screen sharing / video** restriction Discord applies to Brazilian accounts is enforced **client-side**, not on the server.

The script below creates a local override for the `2026-08-video-guard` experiment — the very same mechanism Discord's own client uses to decide whether the feature is on or off — and re-enables the feature without touching anything server-side.

> **In short:** if a feature flag shipped to the client is enough to reverse the restriction, the restriction is not a security control. It is UI.

---

## Disclaimer

This repository exists for **educational and security research purposes**, to document where the validation actually happens.

- Running client mods and modifying the Discord client **violates Discord's Terms of Service** and may get your account suspended.
- Use at your own risk, and only on your own account.
- The author takes no responsibility for any consequences of using this.

---

## Requirements

| Item | Details |
|---|---|
| **Discord Desktop** | The installed client (not the browser version, unless you use the Vencord browser extension) |
| **[Vencord](https://vencord.dev/)** | Required — it exposes the global `Vencord` object with access to Discord's internal Webpack |
| **Brazilian account** | An account that already has the screen/video restriction active (otherwise there is nothing to test) |

### Installing Vencord

1. Download the official installer: **https://vencord.dev/download**
2. Fully quit Discord (check the system tray / `Cmd+Q` on macOS).
3. Run the installer → **Install Vencord** → pick your Discord installation (Stable / PTB / Canary).
4. Open Discord again. If a **Vencord** tab shows up in *User Settings*, it is installed.

> Never install client mods from anywhere other than the official Vencord website.

---

## How to test

### 1. Confirm the restriction is active

Before running anything, join a voice channel and try to start screen sharing or turn on your camera.
You should hit the restriction (disabled button, regional restriction notice, etc.). **Take a screenshot** — that is your "before" evidence.

### 2. Open DevTools

With Vencord installed, Electron's DevTools are unlocked:

| OS | Shortcut |
|---|---|
| Windows / Linux | `Ctrl` + `Shift` + `I` |
| macOS | `Cmd` + `Option` + `I` |

If the shortcut does nothing, go to **Settings → Vencord → Enable React DevTools / Open DevTools**, or launch Discord with the `--remote-debugging-port=9222` flag.

Switch to the **Console** tab.

### 3. Allow pasting in the console

Chrome/Electron blocks pasting into the console the first time as a self-XSS protection. It will ask you to type:

```
allow pasting
```

Type that, hit `Enter`, then paste the script.

### 4. Paste the script

Copy the full contents of [`script.js`](script.js) into the console:

```js
(() => {
    if (!Object.values(Vencord.Webpack.wreq(Vencord.Webpack.findModuleId("2026-08-video-guard"))).find(
        x => x?.definition?.name === "2026-08-video-guard"
    ))
        throw new Error("not found");

    Vencord.Webpack.Common.FluxDispatcher.dispatch({
        type: "APEX_EXPERIMENT_SESSION_OVERRIDE_CREATE",
        experimentName: "2026-08-video-guard",
        variantId: 0
    });

    console.log("enabled!");
})();
```

Press `Enter`.

### 5. Expected result

```
enabled!
```

If you see `enabled!`, the override was applied. Go back to the voice channel and try screen sharing / camera again.

**If it works, the restriction was client-side.** No request was modified, no header was tampered with, no endpoint was bypassed — just a local flag.

---

## How the script works

```js
Vencord.Webpack.findModuleId("2026-08-video-guard")
```
Scans Discord's Webpack bundle for the module whose source contains the string `2026-08-video-guard`. **Key point:** the experiment definition lives *inside the JavaScript shipped to your browser*.

```js
Vencord.Webpack.wreq(id)
```
`wreq` is the internal `__webpack_require__`. It loads the module that was found and returns its exports.

```js
Object.values(...).find(x => x?.definition?.name === "2026-08-video-guard")
```
Looks through the exports for the experiment definition object. If it is not there, the script throws `not found` — which means the experiment name changed (see [Troubleshooting](#troubleshooting)).

```js
Vencord.Webpack.Common.FluxDispatcher.dispatch({
    type: "APEX_EXPERIMENT_SESSION_OVERRIDE_CREATE",
    experimentName: "2026-08-video-guard",
    variantId: 0
});
```
Dispatches an action on Discord's own Flux store. `APEX_EXPERIMENT_SESSION_OVERRIDE_CREATE` is the **native** experiment override mechanism (the same one used by the internal staff panel). `variantId: 0` is the control bucket — meaning "feature off", which for the video guard means **no restriction**.

No patching, no hooking, no monkey-patching. The script simply uses an API that already ships in the client.

---

## Persistence

The override lives in memory only. There is nothing to cache or persist — what has to survive a reload is the **act of reapplying it**.

### Option 1 — Vencord userplugin (recommended)

[`vencord-plugin/index.ts`](vencord-plugin/index.ts) reapplies the override on every gateway connection:

```ts
flux: {
    CONNECTION_OPEN: disableGuard
},
start: disableGuard
```

`CONNECTION_OPEN` matters here. On startup, the experiment store is only populated after the gateway authenticates and the server sends the assigned buckets. Dispatching before that gets overwritten. Hooking `CONNECTION_OPEN` runs after the connection is established — and runs again on every reconnect, so `Ctrl+R`, network drops and laptop sleep are all covered.

Userplugins only compile in a Vencord build made from source — the official installer will not take them:

```bash
git clone https://github.com/Vendicated/Vencord && cd Vencord
pnpm i
mkdir -p src/userplugins/VideoGuardOff
cp /path/to/vencord-plugin/index.ts src/userplugins/VideoGuardOff/index.ts
pnpm build
pnpm inject
```

Then enable **VideoGuardOff** under Settings → Vencord → Plugins. Replace `authors: [Devs.Ven]` with `[{ name: "your-name", id: 0n }]`.

### Option 2 — DevTools snippet

DevTools → **Sources** tab → **Snippets** panel → **New snippet** → paste the script → save.

The snippet is stored in your DevTools profile permanently. After each reload it is one `Ctrl+Enter` away. Not automatic, but it removes the copy-paste and the `allow pasting` step.

---

## How to revert

The override is **per session** and is not persisted. Just:

- press `Ctrl` + `R` (reload the client), **or**
- quit and reopen Discord, **or**
- dispatch the inverse in the console:

```js
Vencord.Webpack.Common.FluxDispatcher.dispatch({
    type: "APEX_EXPERIMENT_SESSION_OVERRIDE_DELETE",
    experimentName: "2026-08-video-guard"
});
```

If you installed the userplugin, disable it under Settings → Vencord → Plugins first, otherwise it reapplies on the next reconnect.

---

## Troubleshooting

| Error / symptom | Likely cause | Fix |
|---|---|---|
| `Vencord is not defined` | Vencord not installed, or you are in a browser console without the extension | Install Vencord and restart Discord |
| `Uncaught Error: not found` | The experiment name changed (e.g. `2026-09-...`) | See "Finding the new name" below |
| Pasting does nothing | Self-XSS protection | Type `allow pasting` in the console first |
| It printed `enabled!` but the button is still blocked | The component was already mounted with the old value | Do **not** press `Ctrl+R` — that clears the override. Leave and rejoin the voice channel |
| DevTools shortcut does not open | Discord build without DevTools unlocked | Settings → Vencord → *Open DevTools* |

### Finding the new name

If Discord renames the experiment, find the new string from the console:

```js
// list every experiment loaded in the client
Object.keys(Vencord.Webpack.Common.FluxDispatcher._actionHandlers._dependencyGraph.nodes)
```

Or search the bundle directly:

```js
Vencord.Webpack.findAll?.(m => JSON.stringify(m)?.includes("video-guard"))
```

Then replace both occurrences of `2026-08-video-guard` in the script.

---

## Why this matters

Regional restrictions implemented as client feature flags are **cosmetic**. They inform the UI, they do not protect anything:

1. The experiment definition is shipped to the client.
2. The client decides on its own whether to show the feature.
3. The override mechanism is part of that same client.

A real control would be enforced on the voice/media server — rejecting the stream at the moment it is published, not hiding the button. As long as the decision dies in the client, anyone with DevTools open reverses it in one line.

---

## License

MIT — see [LICENSE](LICENSE).
