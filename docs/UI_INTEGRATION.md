# UI integration contract
Codex owns these additions. Do not create a second HUD or change the baseline snapshot to install them.

## Installed mapping
| Repository | Studio |
|---|---|
| src/client/CodexUI/Bootstrap.client.lua | StarterPlayer.StarterPlayerScripts.CodexUI.Bootstrap (LocalScript) |
| src/client/CodexUI/{Controller,View,Model,RemoteAdapter}.lua | StarterPlayer.StarterPlayerScripts.CodexUI/<same name> (ModuleScripts) |
| src/config/UIConfig.lua | StarterPlayer.StarterPlayerScripts.CodexUI.UIConfig |
| src/shared/CodexShared/{Cleanup,RateLimiter}.lua | ReplicatedStorage.CodexShared/<same name> |
| tests/UnitSuite.lua | ServerStorage.CodexTests.UnitSuite (manual only) |
| tests/ServerFixture.lua | Repo only; inject during an isolated Studio playtest |
| tests/ClientSuite.client.lua | Repo only; inject into the test player's PlayerScripts |

Bootstrap creates PlayerGui.LarpCodexUI (ResetOnSpawn=false). Nothing is installed in StarterGui or Claude's namespaces. Client-owned SoundService.CodexMusic and CodexSFX are created during play and cleaned up on teardown. New package source is mirrored in src; old Claude sources remain historical snapshots.

## Already connected remote contracts
The adapter watches Larp.Remotes without blocking startup, including remotes added later.
- ProfileSync(table) / StatsChanged(table): stats, total, wins; optional settings and persistent. Rank is derived using existing RankMath and Catalog.
- ChallengeIncoming(id, fromUserId, fromName, fromRankIndex, seconds): replaces old popup, capped at ten seconds. Consumed ids remembered in a bounded 64-id replay cache. A replacement declines the previous request.
- ChallengeClosed(id): only closes the matching request.
- Notice(text,kind), Announce(text), RankUp(rankIndex), PickupCollected(itemId,points,statId,...): notices/pickup feedback.
- RespondChallenge(id,accept): sent once per active request on click, expiry, preference opt-out, match entry or respawn.
- UpdateSetting(key,value): current server schema only (acceptLarpOffs, clipMode, reduceEffects).
- RequestChallenge(targetUserId,{rematch=true}) / RequestPractice({rematch=true}): sent once when rematch pressed.

No server bootstrap, DataStore call or new production RemoteEvent was added. Missing remotes show a usable waiting HUD.
**Server remains responsible for validating every request**, current challenge identity/participants, timeout, distance, rate limit, opt-out, match availability and cooldown. This UI cannot enforce security.

## SceneDirector hooks (Claude to connect)
From a normal client LocalScript / client ModuleScript:
```lua
local Players = game:GetService("Players")
local ui = require(Players.LocalPlayer.PlayerScripts:WaitForChild("CodexUI"):WaitForChild("Controller")).start()
ui:SetMatchActive(true)             -- hides HUD, closes pending challenge/settings
ui:SetRound("Bag", 1, 1)           -- validated configured stat and round index
ui:ShowStamp("Ate", 0.9)           -- Ate, Fumbled, Certified, Exposed, Upset, Viral, Draw
-- Scene and verdict finished:
ui:SetMatchActive(false)
ui:ShowRematch("Player", opponentUserId, 60) -- or ("Npc", 0, 60)
ui:Notify("You earned bonus points", "success") -- only after server confirms reward
```
MatchBegin/MatchRound/MatchVerdict payload shapes are not defined by existing source, so Codex did NOT guess adapters for them. The future scene director must call these hooks. Rematch eligibility and server rejection need to be resolved by that service; current UI permits one request per displayed offer.

ProfileSync currently has no ready/request handshake in Net. Claude's bootstrap must ensure the client listener is ready (or add an explicit snapshot request/ready handshake) so an early one-shot profile is not lost. This race was not solved by adding an unauthorized competing server bootstrap.

## Settings / effects / sound
```lua
sound.SoundGroup = ui:GetAudioGroup("Music") -- or "SFX"; volumes affect assigned sounds
if not ui:GetSetting("reduceEffects") then -- enable camera shake / flash end
if ui:GetSetting("clipMode") then -- apply scene-owned crop/framing end
local connection = ui:OnSettingChanged(function(key, value)
    -- scene or cosmetic owner applies supported preference
end)
connection:Disconnect() -- when consumer ends
```
Reduce Effects already removes stamp motion. Clip Mode and Show Cosmetics expose values/listeners; their camera/world behavior belongs to Claude's future scene/cosmetic renderer. Music/SFX/cosmetics are explicitly session-only. No sound assets were fabricated and existing sounds are not reassigned.
Settings volume buttons cycle 100% -> 0% -> 25% -> 50% -> 75% -> 100%. Touch Grass count omitted from challenge because neither profiles nor remote carries it and rebirth is out of scope.

## Future timer API
ui:SetEvent(label, workspace:GetServerTimeNow()+duration) displays a countdown; ui:SetEvent(nil) clears it. Caller supplies server time; no events are scheduled by this package.

## Utilities
Cleanup.new():Add(connection|instance|function|destroyable), :Destroy() is idempotent; returns errors while finishing remaining disposers.
RateLimiter.new(capacity,refillPerSecond,maxKeys,clock?):Allow(player,cost?) -> allowed,retrySeconds; :Remove(player) on PlayerRemoving; :Destroy(). Bounded key count, no credit from negative/NaN/infinite costs; separate from existing PairLimiter rewards.

