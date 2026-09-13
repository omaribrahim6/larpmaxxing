# UI integration contract
Codex owns these additions. Do not create a second HUD or change the baseline snapshot to install them.

## Installed mapping
| Repository | Studio |
|---|---|
| src/client/CodexUI/Bootstrap.client.lua | StarterPlayer.StarterPlayerScripts.CodexUI.Bootstrap (LocalScript) |
| src/client/CodexUI/{Controller,View,Model,RemoteAdapter,Onboarding,InputController,InputPolicy,FocusPolicy,Layout,SettingValue,ToastPolicy,Wayfinder,Theme,Juice,Hud,Celebrate,Tutorial,TutorialArt}.lua | StarterPlayer.StarterPlayerScripts.CodexUI/<same name> (ModuleScripts) |
| src/config/UIConfig.lua | StarterPlayer.StarterPlayerScripts.CodexUI.UIConfig |
| src/shared/CodexShared/{Cleanup,RateLimiter}.lua | ReplicatedStorage.CodexShared/<same name> |
| tests/UnitSuite.lua | ServerStorage.CodexTests.UnitSuite (manual only) |
| tests/ServerFixture.lua | Repo only; inject during an isolated Studio playtest |
| tests/ClientSuite.client.lua | Repo only; inject into the test player's PlayerScripts |

Bootstrap creates PlayerGui.LarpCodexUI (ResetOnSpawn=false). Nothing is installed in StarterGui or Claude's namespaces. Client-owned SoundService.CodexMusic and CodexSFX are created during play and cleaned up on teardown. New package source is mirrored in src; old Claude sources remain historical snapshots.

The 14-source UI package is installed. Latest focus/persistence/CCTV/wayfinding native regression remains pending the next Codex test lease. Scatter maps to ReplicatedStorage.CodexShared.Scatter when pickup placement is installed; it is outside the UI-only manifest.

## Already connected remote contracts
The adapter watches Larp.Remotes without blocking startup, including remotes added later.
- ProfileSync(table) / StatsChanged(table): stats, total, wins; optional settings and persistent. Rank is derived using existing RankMath and Catalog.
- ChallengeIncoming(id, fromUserId, fromName, fromRankIndex, seconds): replaces old popup, capped at ten seconds. Consumed ids remembered in a bounded 64-id replay cache. A replacement declines the previous request.
- ChallengeClosed(id): only closes the matching request.
- Notice(text,kind), Announce(text), RankUp(rankIndex): notices. CodexUI no longer subscribes to PickupCollected: floating pickup text belongs to PickupFx.
- RespondChallenge(id,accept): sent once per active request on click, expiry, preference opt-out, match entry or respawn.
- UpdateSetting(key,value): acceptLarpOffs, clipMode, reduceEffects, showCosmetics, musicVolume, sfxVolume. Claude installed/tested the extended schema; client flags now match it.
- RequestChallenge(targetUserId,{rematch=true}) / RequestPractice({rematch=true}): sent once when rematch pressed.

No server bootstrap, DataStore call or new production RemoteEvent was added. Missing remotes show a usable waiting HUD.
**Server remains responsible for validating every request**, current challenge identity/participants, timeout, distance, rate limit, opt-out, match availability and cooldown. This UI cannot enforce security.

## Current SceneDirector hooks
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
ui:ShowReward({won = true, upset = false, bonus = 312, rounds = 3, against = 2}) -- result card once the match ends
ui:Collected("Bag", 15, "Uncommon", worldPosition) -- PickupFx: points fly into the HUD bar; returns the combo length
```
Since 2026-09-12 the look lives in Theme (fonts, primitives) and Juice (tweens, button feel, roll-up numbers, UI sounds), the HUD in Hud, and the full-screen promotion, scene-upgrade and result moments in Celebrate (the `LarpCelebrate` ScreenGui, DisplayOrder 45). RankUp celebrates instead of toasting.
Claude's SceneDirector already calls these hooks. Match packets/cinematography and rematch eligibility remain with their owners. UI permits one request per displayed offer. During CCTV matches, SetMatchActive hides guide/HUD/settings and pauses notifications while preserving remaining reading time. The round chip and verdict stamps remain available.

Claude's LarpClient starts CodexUI before sending ClientReady; StatService replies with ProfileSync. CodexUI does not create a competing bootstrap or new remotes.

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
