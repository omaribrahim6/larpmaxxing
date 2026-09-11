# src/larp: read-only mirror of Claude-owned Studio scripts
Studio is the live, authoritative source. These files are exported copies, for review, history and offline reading. Editing them changes nothing in the game. There is no Rojo and no importer.

Layout follows the Studio path: `ReplicatedStorage.Larp.Shared.Resolver` is at `ReplicatedStorage/Larp/Shared/Resolver.lua`. Suffixes:
- `.server.lua` for a Script
- `.client.lua` for a LocalScript
- `.lua` for a ModuleScript

A script with children becomes a folder with `init.<suffix>.lua`. For example, the `LarpClient` LocalScript is `LarpClient/init.client.lua`.

Covered roots:
- ReplicatedStorage.Larp
- ServerScriptService.Larp
- ServerScriptService.UnitTestRunner
- StarterPlayer.StarterPlayerScripts.LarpClient
- ServerStorage.UnitTest

Codex's CodexUI and CodexShared live in `src/client`, `src/config` and `src/shared` and are not part of this mirror.

## Checking the mirror against Studio
1. In Studio, run this in the command bar or through MCP `execute_luau`. Any DataModel with the scripts works, including a play server. Save the output to a file.
```lua
local function fnv(s)
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (bit32.lshift(h, 24) + h * 403) % 4294967296
	end
	return string.format("%08x", h)
end
local roots = { game.ReplicatedStorage.Larp, game.ServerScriptService.Larp, game.StarterPlayer.StarterPlayerScripts.LarpClient, game.ServerStorage.UnitTest, game.ServerScriptService:FindFirstChild("UnitTestRunner") }
local out = {}
for _, r in roots do
	local list = r:GetDescendants(); table.insert(list, 1, r)
	for _, d in list do
		if d:IsA("LuaSourceContainer") then
			table.insert(out, table.concat({ d:GetFullName(), d.ClassName, fnv(d.Source), #d.Source }, "|"))
		end
	end
end
return table.concat(out, "\n")
```
2. Run `powershell -File tools/verify-larp-mirror.ps1 -Manifest <that file>`. It prints MISSING or DIFFERS for each file that doesn't match, then `N/N match`.
