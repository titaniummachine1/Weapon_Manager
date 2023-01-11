--[[                                ]]--
--[[     Misc Tools for Lmaobox     ]]--
--[[ Modded with auto weapon switch ]]--
--[[          --Authors--           ]]--
--[[     LNX (github.com/lnx00)     ]]--
--[[         SylveonBottle          ]]--
--[[           Terminator           ]]--
--[[  (github.com/titaniummachine1  ]]--
---@type boolean, LNXlib
local libLoaded, Lib = pcall(require, "LNXlib")
assert(libLoaded, "LNXlib not found, please install it!")
assert(Lib.GetVersion() >= 0.89, "LNXlib version is too old, please update it!")

local menuLoaded, MenuLib = pcall(require, "Menu")                                -- Load MenuLib
assert(menuLoaded, "MenuLib not found, please install it!")                       -- If not found, throw error
assert(MenuLib.Version >= 1.44, "MenuLib version is too old, please update it!")  -- If version is too old, throw error



--[[ Menu Sub-categories ]]--
local   ObserverMode    = {  -- Observer Mode
        None            = 0, -- No observer mode
        Deathcam        = 1, -- Deathcam
        FreezeCam       = 2, -- FreezeCam (Frozen)
        Fixed           = 3, -- Fixed Camera (fixed position)
        FirstPerson     = 4, -- First Person (Watching your screen)
        ThirdPerson     = 5, -- Third Person (Default)
        PointOfInterest = 6, -- Point of Interest Camera
        FreeRoaming     = 7  -- Free Roaming Camera
    }
local Removals = {           -- May be removed in the future
    ["RTD Effects"] = false, -- Button to remove RTD effects
    ["HUD Texts"] = false    -- Button to remove HUD Texts
    }
local Callouts = {                   -- Callouts are not yet fully implemented
["Battle Cry Melee"] = false,    -- C2 when using melee and looking at enemy
    -- ["Medic!"] = false,           -- Call for medic when low on health (or spam it if there is no medic?)
    -- ["Yes"] = false,              -- Say "Yes" if someone nearby says No (lmao)
    -- ["No"] = false,               -- Say "No" at certain responses ("You are a spy", etc)
    -- ["Spy"] = false,              -- Callout Spies
    -- ["Teleporter Here"] = false,  -- If we respawn, but there's no teleporters nearby, request a teleporter
    -- ["Activate Charge"] = false,  -- If the medic ubering us has full charge, replace our "Medic!" callout with this
    -- ["Help!"] = false,            -- If there's no medic on our team, call for help at low health when there's a teammate nearby
    -- ["Positive"] = false,         -- When we do anything to get points (assists, sap buildings, etc)
    -- ["Negative"] = false,         -- idk bad things? enemy caps points, our medic dies, etc
    -- ["Nice Shot"] = false,        -- If a sniper nearby gets a headshot
    -- ["Good Job"] = false,         -- If a someone nearby gets a kill
}
local autoswitch_options = {
    ["safe-mode"] = true,
    ["Auto Melee"] = true,
    ["Auto-crit-refill"] = true,
    ["force Change"] = true,
}  
local autswitchClasses = {
    ["Medic"] = true,
    ["Soldier"] = true,
    ["Pyro"] = true,
    ["scout"] = true,
}
--[[ Varibles used for looping ]]--
local LastExtenFreeze = 0  -- Spectator Mode
local prTimer = 0          -- Timer for Random Ping
local flTimer = 0          -- Timer for Fake Latency
local c2Timer = 0          -- Timer for Battle CryoWeaponmAutoweapon raytracing
local c2Timer2 = 0         -- Timer for ^ to prevent spamming
local mfTimer = 0          -- Timer for Medic Finder

--[[ Menu ]]--
local menu = MenuLib.Create("Misc Tools", MenuFlags.AutoSize)
menu.Style.TitleBg = { 205, 95, 50, 255 } -- Title Background Color (Flame Pea)
menu.Style.Outline = true                 -- Outline around the menu


--local mCallouts         = menu:AddComponent(MenuLib.MultiCombo("Auto Voicemenu WIP",   Callouts, ItemFlags.FullWidth))  -- Callouts

--local mFastStop         = menu:AddComponent(MenuLib.Checkbox("FastStop (Debug!)",      false))                          -- FastStop (Doesn't work yet)
local mAutoweapon       = menu:AddComponent(MenuLib.Checkbox("Auto weapon switch",      true))
local mWswitchoptions   = menu:AddComponent(MenuLib.MultiCombo("^Settings",             autoswitch_options, ItemFlags.FullWidth))
local mWswitchclasses   = menu:AddComponent(MenuLib.MultiCombo("^Classes",             autswitchClasses, ItemFlags.FullWidth))                          -- AutooWeaponmAutoweapon Switch
local mcrossbowhealth   = menu:AddComponent(MenuLib.Slider("crossbow min health",    1, 100, 92))
local mAutoWeaponDist   = menu:AddComponent(MenuLib.Slider("melee Switch Distance",    77, 400, 157))                 -- AutooWeaponmAutoweapon Switch Distances
menu:AddComponent(MenuLib.Button("Disable Weapon Sway", function() -- Disable Weapon Sway (Executes commands)
    client.SetConVar("cl_vWeapon_sway_interp",              0)             -- Set cl_vWeapon_sway_interp to 0
    client.SetConVar("cl_jiggle_bone_framerate_cutoff", 0)             -- Set cl_jiggle_bone_framerate_cutoff to 0
    client.SetConVar("cl_bobcycle",                     10000)         -- Set cl_bobcycle to 10000
end, ItemFlags.FullWidth))
local mRetryStunned     = menu:AddComponent(MenuLib.Checkbox("suicide when stunned",     true))
local WFlip             = menu:AddComponent(MenuLib.Checkbox("Auto Weapon Flip",       true))                           -- Auto Weapon Flip (Doesn't work yet)
local mMedicFinder      = menu:AddComponent(MenuLib.Checkbox("Medic Finder",           true))                           -- Medic Finder
local mLegitSpec        = menu:AddComponent(MenuLib.Checkbox("Legit when Spectated",   false))                          -- Legit when Spectated
local mLegitSpecFP      = menu:AddComponent(MenuLib.Checkbox("^Firstperson Only",      false))                          -- Legit when Spectated (Firstperson Only Toggle)
local mLegJitter        = menu:AddComponent(MenuLib.Checkbox("Leg Jitter",             false))                          -- Leg Jitter
local mRocketLines      = menu:AddComponent(MenuLib.Checkbox("Rocket Lines",           false))                          -- Rocket Lines                         -- suicide When Stunned
local mExtendFreeze     = menu:AddComponent(MenuLib.Checkbox("inffinite spectator time", false))
local msandwitchex      = menu:AddComponent(MenuLib.Checkbox("inffinite sandwich exploid", false))                      -- Infinite Respawn Timer
local mRetryLowHP       = menu:AddComponent(MenuLib.Checkbox("Retry When Low HP",      false))                          -- Retry When Low HP
local mRetryLowHPValue  = menu:AddComponent(MenuLib.Slider("Retry HP",                 1, 299, 30))                     -- Retry When Low HP Value
local mAutoFL           = menu:AddComponent(MenuLib.Checkbox("Auto Fake Latency",      false))                          -- Auto Fake Latency
local mAutoFLDist       = menu:AddComponent(MenuLib.Slider("AFL Activation Distance",    100, 700, 530))                -- Auto Fake Latency Distance (530 is based on two players walking towards each other)
local mAutoFLFar        = menu:AddComponent(MenuLib.Slider("AFL Far Value",         0, 1000, 777))                      -- What value to use when not in range (to keep ping consistant and not jumping around)
local mAutoFLNear       = menu:AddComponent(MenuLib.Slider("AFL Close Value",        0, 1000, 477))                     -- Auto Fake Latency Near Value                          -- Random Ping
local mRandPingValue    = menu:AddComponent(MenuLib.Slider("Ping Randomness",          0, 15, 0))                       -- Random Ping Value
local mRandLag          = menu:AddComponent(MenuLib.Checkbox("Random Fakelag",         false))                          -- Random Fakelag
local mRandLagValue     = menu:AddComponent(MenuLib.Slider("Fakelag Randomness",       1, 200, 77))                     -- Random Fakelag Value
local mRandLagMin       = menu:AddComponent(MenuLib.Slider("Fakelag Min",              1, 314, 247))                    -- Random Fakelag Minimum Value
local mRandLagMax       = menu:AddComponent(MenuLib.Slider("Fakelag Max",              2, 315, 315))                    -- Random Fakelag Maximum Value


-- local mUberWarning      = menu:AddComponent(MenuLib.Checkbox("Uber Warning",     false))                          -- Medic Uber Warning (currently no way to check)
-- local mRageSpecKill     = menu:AddComponent(MenuLib.Checkbox("Rage Spectator Killbind", false))                         -- fuck you "pizza pasta", stop spectating me
--local mRemovals         = menu:AddComponent(MenuLib.MultiCombo("Removals",             Removals, ItemFlags.FullWidth))  -- Remove RTD and HUD Texts

--[[ Options management ]]--
local TempOptions = {}                                             -- Temp options

local function ResetTempOptions()                                  -- Reset "TempOptions"
    for k, v in pairs(TempOptions) do                              -- Loop through all options in "TempOptions"
        TempOptions[k].WasUsed = false                             -- Set "WasUsed" to false for each option (so we can check if it was used)
    end
end

local function SetOptionTemp(option, value)                        -- Runs "SetOptionTemp" with the given cheat and setting
    local guiValue = gui.GetValue(option)                          -- Set "guiValue" to the current setting of the given cheat
    if guiValue ~= value then                                      -- Check if "guiValue" is different from the "SetOptionTemp"'s setting
        gui.SetValue(option, value)                                -- Set the cheat to the given setting
        TempOptions[option] = {                                    -- Create a new entry in "TempOptions" for the given cheat
            Value   = guiValue,                                    -- Set the entry's value to the current setting of the cheat
            WasUsed = true    }                                    -- Set the entry's "WasUsed" to true
    end

    if TempOptions[option] ~= nil then                             -- For each option in "TempOptions" (as long as one exists),
        TempOptions[option].WasUsed = true                         -- Set the entry's "WasUsed" to true
    end
end

local function CheckTempOptions()                                  -- When CheckTempOptions is called,
    for k, v in pairs(TempOptions) do                              -- Loop through all options in "TempOptions"
        if not v.WasUsed then                                      -- Check if the entry's "WasUsed" is false.
            gui.SetValue(k, v.Value)                               -- Set the cheat to the entry's value (the value it was set to before) and
            TempOptions[k] = nil                                   -- Remove the entry from "TempOptions" (so it doesn't get checked again)
        end
    end
end

--[[ Code needed to run 66 times a second ]]--
---@param userCmd UserCmd
local function OnCreateMove(pCmd)                    -- Everything within this function will run 66 times a second
    ResetTempOptions()                               -- Immediately reset "TempOptions"
    local pLocal = entities.GetLocalPlayer()         -- Immediately set "pLocal" to the local player (entities.GetLocalPlayer)
    if not pLocal then return end                    -- Immediately check if the local player exists. If it doesn't, return.
    local vVelocity  = pLocal:EstimateAbsVelocity()  -- Immediately set "vVelocity" to the local player's absolute velocity (this is used for any code that needs to know the local player's velocity)
    local cmdButtons = pCmd:GetButtons()             -- Immediately set "cmdButtons" to the local player's buttons (this is used for any code that needs to know what buttons we are pressing)




    --[[ Leg Jitter ]]-- (Messes with certain idle animations. See scout with mad milk / spycrab for a good example)
    if mLegJitter:GetValue() == true then                                -- If Leg Jitter is enabled,
        if (pCmd.forwardmove == 0) and (pCmd.sidemove == 0)              -- Check if we are pressing WASD
                                   and (vVelocity:Length2D() < 10) then  -- Check if we not currently moving 
            if pCmd.command_number % 2 == 0 then                         -- Check if the command number is even. (Potentially inconsistent, but it works).
                pCmd:SetSideMove(9)                                      -- Cycle between moving left and right
            else
                pCmd:SetSideMove(-9)
            end
        end
    end

    --[[ Fast Stop -- (Tries to immediately stop the player's momentum when letting go of WASD)
    if mFastStop:GetValue() == true then                                     -- If Fast Stop is enabled
        if (pLocal:IsAlive()) and (pCmd.forwardmove == 0)                    -- Check if we are alive and not moving
                              and (pCmd.sidemove == 0)
                              and (vVelocity:Length2D() > 10) then           -- Check if our velocity is greater than 10hu
            local fsx, fsy, fsz = vVelocity:Unpack()                         -- Set "fsx", "fsy" and "fsz" to the local player's absolute x, y and z velocity
            print(fsx, fsy, fsz)                                             -- Print the local player's x, y and z velocity (for debugging)
            if (fsz < 0.01) then                                             -- Check if the local player's z velocity is less than 0.01 (if they are not jumping or falling).
                pCmd:SetForwardMove(fsx)                                     -- Set the forwardmove to the local player's absolute x velocity (needs to be translated to the local player's view)
                pCmd:SetSideMove(fsy)                                       -- Set the sidemove to the local player's absolute y velocity (needs to be translated to the local player's view)
                print("Success! X:" .. fsx .. " Y:" .. fsy .. " Z:" .. fsz)  -- Print the local player's absolute x, y and z velocity (for debugging)
            end
        end
    end
    --]]
    --[[ Retry when low hp ]]-- (Rconnects when your hp is below "mRetryHP" (set in the menu) in order to prevent being killed))
    if mRetryLowHP:GetValue() == true then                                                     -- If Retry when low hp is enabled
        if (pLocal:IsAlive()) and (pLocal:GetHealth() > 0                                      -- Check if we are alive and have health
                              and (pLocal:GetHealth()) <= mRetryLowHPValue:GetValue()) then    -- Check if our health is less than "mRetryLowHPValue" (set in the menu)
            client.Command("retry", true)                                                      -- Reconnect to the server
        end
    end

    --[[ Infinite Respawn Timer ]]-- (Increases the respawn timer for yourself, allowing you to infinitely be stuck respawning)
    if mExtendFreeze:GetValue() == true then                                                 -- If Infinite Respawn Timer is enabled
        if (pLocal:IsAlive() == false) and (globals.RealTime() > (LastExtenFreeze + 2)) then -- Check if the player is dead and if it has been more than 2 seconds since the last extendfreeze executed.
            client.Command("extendfreeze", true)                                             -- Extend the respawn timer
            LastExtenFreeze = globals.RealTime()                                             -- Set LastExtenFreeze to the current time
        end
    end

    --[[ Random Fakelag ]]-- (Randomizes FakeLag's value. This can break some cheat's projectile aimbot)
    if mRandLag:GetValue() == true then                                                                    -- If Random Fakelag is enabled
        flTimer = flTimer +1                                                                               -- Increment the fakelag timer
        if (flTimer >= mRandLagValue:GetValue()) then                                                      -- Check if the fakelag timer is greater than "mRandLagValue" (set in the menu)
            flTimer = 0                                                                                    -- Reset the fakelag timer
            local randValue = math.random(mRandLagMin:GetValue(), mRandLagMax:GetValue())                  -- Set "randValue" to a random number between "mRandLagMin" and "mRandLagMax" (set in the menu)
            gui.SetValue("fake lag value", randValue)                                                      -- Set the fakelag value to "randValue"
            -- gui.SetValue("fake lag value", math.random(mRandLagMin:GetValue(), mRandLagMax:GetValue())) -- Untested, but should work.
        end
    end

    --[[ Random Ping ]]-- (Randomly enables Ping Reducer, preventing you from having a steady ping of 341 ping that never increases/descreases (suspicious))
    if mRandPingValue:GetValue() >= 1 then                     -- If Random Ping is enabled
        prTimer = prTimer +1                                 -- Increment the ping timer
        if (prTimer >= mRandPingValue:GetValue() * 66) then  -- Check if the ping timer is greater than "mRandPingValue" (set in the menu).
            prTimer = 0                                      -- Reset the ping timer
            local prActive = gui.GetValue("ping reducer")    -- Set "prActive" to the current value of ping reducer
            -- if (gui.GetValue("ping reducer") == 0) then   -- Untested. This might work better.
            if (prActive == 0) then                          -- Check if ping reducer is currently disabled
                gui.SetValue("ping reducer", 1)              -- If it is disabled, enable it
            elseif (prActive == 1) then                      -- Check if ping reducer is currently enabled
                gui.SetValue("ping reducer", 0)              -- If it is enabled, disable it
            end
        end
    end


    --[[ Anti RTD -- (Stops certain RTD effects. May be removed in the future)
    if mRemovals:IsSelected("RTD Effects") then                           -- If RTD Effects is selected
        if CurrentRTD == "Cursed" then                                    -- If the current RTD effect is "Cursed"
            pCmd:SetForwardMove(pCmd:GetForwardMove() * (-1))             -- Reverse the local player's W and S movement
            pCmd:SetSideMove(pCmd:GetSideMove() * (-1))                   -- Reverse the local player's A and D movement
        elseif CurrentRTD == "Drugged" or CurrentRTD == "Bad Sauce" then  -- If the current RTD effect is "Drugged" or "Bad Sauce"
            --SetOptionTemp("norecoil", 1)                                -- Activate NoRecoil (bannable in community servers)
        end
    end
    ]]--

    --[[ Features that require access to the weapon ]]--
        local pWeapon         = pLocal:GetPropEntity( "m_hActiveWeapon" )            -- Set "pWeapon" to the local player's active weapon
        local pWeaponDefIndex = pWeapon:GetPropInt( "m_iItemDefinitionIndex" )       -- Set "pWeaponDefIndex" to the "pWeapon"'s item definition index
        local pWeaponDef      = itemschema.GetItemDefinitionByID( pWeaponDefIndex )  -- Set "pWeaponDef" to the local "pWeapon"'s item definition
        local pWeaponName     = pWeaponDef:GetName()                                 -- Set "pWeaponName" to the local "pWeapon"'s actual name
        if not pWeapon then return end                                               -- If "pWeapon" is not set, break
    if (pWeapon == "CTFRocketLauncher") or (pWeapon == "CTFCannon") then        -- If the local player's active weapon is a projectile weapon (this doesn't work for some reason????)
        pUsingProjectileWeapon  = true                                               -- Set "pUsingProjectileWeapon" to true
    else pUsingProjectileWeapon = false end                                          -- Set "pUsingProjectileWeapon" to false



    -- It turns out that LMAOBOX is not compatible with the client convar "cl_flipviewmodels". The client convar works in other cheats (such as Fedoraware) but not in LMAOBOX.
    -- The view models DO flip, however it's only visual. The rocket still fires out of the right side of the player..
    -- In Fedoraware, the rocket fires out of the left side of the player when the cl_viewmodels is set to 1.
    -- So this does not work in LMAOBOX.
    -- However, I am leaving this code here in case someone wants to see how it would have worked.
    -- I also don't want to ask for lbox to fix this in the telegram, because the last time I did that I got banned for 2 months.
    --[[ Auto weapon flip ]]-- (Automatically flips your rocket launcher to the left if it would travel farther)
    if (WFlip:GetValue() == true) then                                                                             -- If Auto weapon flip is enabled
        if pUsingProjectileWeapon == true then                                                                            -- If the local player is using a projectile weapon
            local source      = pLocal:GetAbsOrigin() + pLocal:GetPropVector( "localdata", "m_vecViewOffset[0]" );  -- Set "source" to the local player's view offset
            local destination = source + engine.GetViewAngles():Forward() * 1000;                                   -- Find where the player is aiming
            local trace       = engine.TraceLine (source, destination, MASK_SHOT_HULL);                             -- Trace a line from the player's view offset to where they are aiming (for debugging)
            local sourceRight = source + engine.GetViewAngles():Right() * 10;                                       -- Right of the player
            local traceRight  = engine.TraceLine (sourceRight, destination, MASK_SHOT_HULL);                        -- Trace a line from the right of the player to where they are aiming
            local sourceLeft  = source + engine.GetViewAngles():Right() * -10;                                      -- Left of the player
            local traceLeft   = engine.TraceLine (sourceLeft, destination, MASK_SHOT_HULL);                         -- Trace a line from the left of the player to where they are aiming
            if (math.floor(traceLeft.fraction * 1000)) > (math.floor(traceRight.fraction * 1000)) then              -- If the left trace is closer than the right trace
                client.SetConVar("cl_flipviewmodels", 1 )                                                           -- Set the client convar to flip the viewmodels
            elseif (math.floor(traceLeft.fraction * 1000)) < (math.floor(traceRight.fraction * 1000)) then          -- If the right trace is closer than the left trace
                client.SetConVar("cl_flipviewmodels", 0 )                                                           -- Revert the client convar to not flip the viewmodels
            end
        end
    end



    --[[ Features that need to iterate through all players ]]
    local players = entities.FindByClass("CTFPlayer")                              -- Create a table of all players in the game
    for k, vPlayer in pairs(players) do                                            -- For each player in the game
        if vPlayer:IsValid() == false then goto continue end                       -- Check if each player is valid
    local vWeapon = vPlayer:GetPropEntity("m_hActiveWeapon")                       -- Set "vWeapon" to the player's active weapon
    if vWeapon ~= nil then                                                         -- If "vWeapon" is not nil
        local vWeaponDefIndex = vWeapon:GetPropInt("m_iItemDefinitionIndex")       -- Set "vWeaponDefIndex" to the "vWeapon"'s item definition index
        --local vWeaponDef      = itemschema.GetItemDefinitionByID(vWeaponDefIndex)  -- Set "vWeaponDef" to the local "vWeapon"'s item definition (doesn't work for some reason)
        --local vWeaponName     = vWeaponDef:GetName()                               -- Set "vWeaponName" to the local "vWeapon"'s actual name (doesn't work for some reason)
    end

    local sneakyboy = false                       -- Create a new variable for if we're invisible or not, set it to false
    if pLocal:InCond(4) or pLocal:InCond(2) 
                        or pLocal:InCond(13) 
                        or pLocal:InCond(9) then  -- If we are in a condition that makes us invisible
        sneakyboy = true                          -- Set "sneakyboy" to true
    end

        --[[ Legit on spectated players ]]-- (To prevent spectating players from seeing us acting suspiciously)
        if mLegitSpec:GetValue() == true then                                                        -- If Smooth on spectated players is enabled
            local obsMode   = pLocal:GetPropInt("m_iObserverMode")                                   -- Set "obsMode" to the player's observer mode 
            local obsTarget = pLocal:GetPropEntity("m_hObserverTarget")                              -- Set "obsTarget" to the player's observer target
            if obsMode and obsTarget then                                                            -- If "obsMode" and "obsTarget" are set
                if (obsMode == ObserverMode.ThirdPerson) and (mLegitSpecFP:GetValue() == true) then  -- If the player is spectating in third person and Firstperson Only Toggle is enabled
                    return                                                                           -- Stop the code from running
                elseif (obsTarget:GetIndex() == pLocal:GetIndex()) then                              -- If the observer's spectate target is the local player
                    if (pUsingProjectileWeapon == true) and (gui.GetValue("aim method") == "silent") then -- if we're using a projectile weapon, and aim method is set to silent, setOptionTemp aim fov to 10
                        SetOptionTemp("aim fov", 10)
                    else
                        SetOptionTemp("aim method", "assistance")                                   -- Otherwise, if we're not using a projectile weapon, set aim method to assistance
                    end                        
                    if (gui.GetValue("auto backstab") ~= "off") then
                        SetOptionTemp("auto backstab", "legit")                                      -- If autobackstab is enabled, set it to legit
                    end
                    if (gui.GetValue("auto sapper") ~= "off") then
                        SetOptionTemp("auto sapper", "legit")                                        -- If autosapper is enabled, set it to legit
                    end
                    if (gui.GetValue("melee aimbot") ~= "off") then                                  -- IfoWeaponmAutoweapon aimbot is enabled, set it to legit
                        SetOptionTemp("melee aimbot", "legit")  
                    end
                    if (gui.GetValue("auto detonate sticky") ~= "off") then                          -- If autodetonate sticky is enabled, set it to legit
                        SetOptionTemp("auto detonate sticky", "legit")
                    end
                    if (gui.GetValue("auto airblast") ~= "off") then                                 -- If auto airblast is enabled, set it to legit
                        SetOptionTemp("auto airblast", "legit")
                    end
                    -- if (gui.GetValue("sniper: shoot through teammates") ~= "off") then            -- I don't know the correct name for this
                    --     SetOptionTemp("sniper: shoot through teammates", "off")
                    -- end
                    -- if (gui.GetValue("fake latency") ~= "0") then                                 -- for some reason this doesn't work
                    --     SetOptionTemp("fake latency", "0")
                    -- end
                    -- if (gui.GetValue("fake lag") ~= "0") then
                    --     SetOptionTemp("fake lag", "0")
                    -- end
                    -- if (gui.GetValue("ping reducer") ~= "0") then
                    --     SetOptionTemp("ping reducer", "0")
                    -- end
                end
            end

        end

        --[[ Spectator Killbind (Rage) ]]-- (I hate it when a random spy on my team decides to alway spectate me when I'm dead. I just to play the damn game, stop being suspicious of me.)
        -- if mRageSpecKill:GetValue() == true then                           -- If Spectator Killbind is enabled
        --     local obsRTarget = pLocal:GetPropEntity("m_hObserverTarget")   -- Set "obsRTarget" to the player's observer target
        --     if obsRMode and obsRTarget then                                -- If "obsRMode" and "obsRTarget" are set
        --         if (obsRTarget:GetIndex() == ??????                        -- if target has priority >= 1. gui.getpriority() doesn't exist yet :(
        --                 client.command("explode", true)                    -- kill ourselves. explode so they can't see our cosmetics, because fuck whoever this guy is.
        --         end
        --     end
        -- end

        if vPlayer:IsAlive() == false then goto continue end
        if vPlayer:GetIndex() == pLocal:GetIndex() then goto continue end            -- Code below this line doesn't work if you're the only player in the game.

        local distVector = vPlayer:GetAbsOrigin() - pLocal:GetAbsOrigin()            -- Set "distVector" to the distance between us and the player we are iterating through
        local distance   = distVector:Length()                                       -- Set "distance" to the length of "distVector"
        if pLocal:IsAlive() == false then goto continue end                          -- If we are not alive, skip the rest of this code

        if vPlayer:GetTeamNumber() == pLocal:GetTeamNumber() then goto continue end  -- If we are on the same team as the player we are iterating through, skip the rest of this code



        --[[ kill when stunned ]]-- (To prevent us from getting tauntkilled)
        if (mRetryStunned:GetValue() == true) then                                   -- If Retry when stunned is enabled
            if (pLocal:InCond(15)) then                                              -- If we are stunned (15 is TF_COND_STUNNED)
                client.command("kill", true)                                        -- Reconnect to the server
            elseif (pLocal:InCond(7)) and (distance <= 200)                          -- If we are laughing (7 is TF_COND_TAUNTING), and we're within 200hu of the player we are iterating through
                                      and (vWeaponName == "The Holiday Punch") then  -- and the enemy is using The Holiday Punch (untested)
                client.command("kill", true)                                        -- Reconnect to the server
            end
        end

        -- local disguisedboy = false
        -- if pLocal:InCond(47) or pLocal:InCond(3)
        --                     or pLocal:InCond(2) then
        --     disguisedboy = true
        -- end


        --[[ AutooWeaponmAutoweapon Switch ]]-- (Automatically switches to slot3 when an enemy is in range)
        --[[ work in progres auto crit refill
        local state = "slot2"
        local medic = entities.GetLocalPlayer()
        local players = entities.FindByClass("CTFPlayer")  -- Create a table of all players in the game
        
        if mAutoweapon:GetValue() and not sneakyboy then
            for k, vPlayer in pairs(players) do  -- For each player in the game
                if not vPlayer:IsValid() then goto continue end
                local distance = (vPlayer:GetAbsOrigin() - medic:GetAbsOrigin()):Length()
        
                if distance <= mAutoWeaponDist:GetValue() and (vPlayer:GetTeamNumber() ~= medic:GetTeamNumber()) then
                    if distance <= mAutoWeaponDist:GetValue() then
                        state = "slot3"
                                --charge critbucket when empty --
                            if vWeapon ~= nil then
                                local critChance = vWeapon:GetCritChance()
                                -- (the + 0.1 is always added to the comparsion)
                                local cmpCritChance = critChance + 0.1

                                -- If we are allowed to crit
                                if cmpCritChance > vWeapon:CalcObservedCritChance() then
                                    client.Command("+attack", true)
                                    client.Command("-attack", true)
                                end

                            end
                    end
                elseif vPlayer:GetHealth() <= mcrossbowhealth:GetValue() * 0.01 * vPlayer:GetMaxHealth() and
                    vPlayer:GetTeamNumber() ~= medic:GetTeamNumber() then

                    state = "slot2"
                elseif vPlayer:GetHealth() <= mcrossbowhealth:GetValue() * 0.01 * vPlayer:GetMaxHealth() and
                    vPlayer:GetTeamNumber() ~= medic:GetTeamNumber() and (distance <= 400) then
                        
                        if vWeapon:GetPropInt("m_iClip1") < 1 then
                            -- wait until the primary weapon has fired
                            state = "slot2"
                        else
                            state = "slot1"
                        end
                        
                end
            end
        end
        client.Command(state, true)
        --]]

        local state = "slot2"
        local players = entities.FindByClass("CTFPlayer")  -- Create a table of all players in the game
        local LocalPlayer = entities.GetLocalPlayer()
        local KeyHelper, Timer, WPlayer = Lib.Utils.KeyHelper, Lib.Utils.Timer, Lib.TF2.WPlayer
        
        local hasmeleecrits = true
        if pWeapon:GetCritTokenBucket() > 10 then
            hasmeleecrits = true
        else
            hasmeleecrits = false
        end
        
        --if mWswitchoptions:IsSelected("AutoMelee") then
        if sneakyboy then goto continue end
        if mAutoweapon:GetValue() == false then goto continue end
        --if (gui.GetValue("Weapon Switcher") ~= "off") then SetOptionTemp("Weapon Switcher", "off") end -- disable conficting switchers
            for k, vPlayer in pairs(players) do  -- For each player in the game
                local distVector = vPlayer:GetAbsOrigin() - pLocal:GetAbsOrigin()
                local distance   = distVector:Length()
                local minmeleedist = distance <= mAutoWeaponDist:GetValue()
                --local playerClass = lplayer:GetPlayerClass()
                local clip = pWeapon:GetWeaponData("IN_RELOAD")
                local minhealth = vPlayer:GetHealth() <= (vPlayer:GetMaxHealth() * 0.01 * mcrossbowhealth:GetValue())
                local myteam = (vPlayer:GetTeamNumber() == LocalPlayer:GetTeamNumber())
                local PlayerClass = LocalPlayer:GetPropInt("m_iClass")
                local Mode = "Medbot"
                local cooldown = Timer.new()
                local reloading = false
                --and clip == 1
                --pWeapon:IsMeleeWeapon() == true
                if not vPlayer:IsValid() and (distance >= 500) then goto continue end
                --if mWswitchclasses:IsSelected("Medic") and PlayerClass == 7 then
                    if minmeleedist and not myteam then
                        if mWswitchoptions:IsSelected("Auto Melee") then
                            state = "slot3"
                                -- If we are allowed to crit
                                if pWeapon:GetCritTokenBucket() <= 10 then
                                    pCmd:SetButtons(pCmd:GetButtons() | IN_ATTACK)--refill
                                end
                        end
                    elseif not minhealth and not myteam then
                        state = "slot2"
                    elseif minhealth and myteam then
                        state = "slot1"
                    end
                --[[elseif not playerClass == 7 then ent_fire !picker Addoutput "health 99"
                    
                    elseif vweapon:IsMeleeWeapon() then
                       -- state = ("lastinv")
                    end
                    ]]--
                --end
            end
        client.Command(state, true)
        
        

        --[[
        if mAutoweapon:GetValue() and not sneakyboy then
            local players = entities.FindByClass("CTFPlayer")                              -- Create a table of all players in the game
            local medic = entities.GetLocalPlayer()
            local distance = (vPlayer:GetAbsOrigin() - medic:GetAbsOrigin()):Length()
            -- Check if the player is a teammate and is damaged
            for k, vPlayer in pairs(players) do                                            -- For each player in the game
                if vPlayer:IsValid() == false then goto continue end
                local distance = (vPlayer:GetAbsOrigin() - medic:GetAbsOrigin()):Length()
                    if distance <= 400 and distance >= mAutoWeaponDist:GetValue() then                       -- Check if each player is valid
                        -- Check if the player is within the distance limit
                        if distance <= mAutoWeaponDist:GetValue() then
                            -- Switch to slot 3
                            client.Command("slot1", true) break 
                        else if distance >= mAutoWeaponDist:GetValue() and vPlayer:GetHealth() > 0.92 * vPlayer:GetMaxHealth() then
                            -- Switch back to slot 2
                            client.Command("slot2", true) break
                        end

                        if vPlayer:GetHealth() < 0.92 * vPlayer:GetMaxHealth() then
                            if vPlayer:GetTeamNumber() == medic:GetTeamNumber() then
                                client.Command("slot3", true)
                                break
                            end
                        end
                        
                    end
                end
            end
        end
        --]]
        
        --if
        --    client.Command("lastinv", true) -- Execute the "slot3" command (We don't have access to pCmd.weaponselect :( )    
        --end

        --[[ Auto Fake Latency ]]-- (Automatically enables fake latency depending on certain conditions)
        if (mAutoFL:GetValue() == true) and (pWeapon:IoWeaponmAutoweaponWeapon() == true)            -- If Auto Fake Latency is enabled, and we are using aoWeaponmAutoweapon weapon, and we are not invisible
                                        and (sneakyboy == false) then                    
            if (distance <= mAutoFLDist:GetValue()) then                                 -- Check if we are within "mAutoFLDist" (set in the menu) of the enemy
                if (gui.GetValue("fake latency") ~= 1) then                              -- If "fake latency" is not on, turn it on
                    gui.SetValue("fake latency", 1)
                end
                if (gui.GetValue ("fake latency value") ~= mAutoFLNear:GetValue()) then  -- if "fake latency value" is not "mAutoFLNear" (set in the menu), set it to "mAutoFLNear"
                    gui.SetValue("fake latency value", mAutoFLNear:GetValue())
                end
                return
            elseif (distance > mAutoFLDist:GetValue()) then                              -- If are away from the enemy, check if "mAutoFLFar" is set to 0.
                if (mAutoFLFar:GetValue() == 0) then                                     -- If "mAutoFLFar" is set to 0, turn off fake latency.
                    if (gui.GetValue("fake latency") ~= 0) then
                        gui.SetValue("fake latency", 0)
                    end
                elseif (mAutoFLFar:GetValue() >= 1) then                                 -- If "mAutoFLFar" is set to 1 or more, set "fake latency value" to "mAutoFLFar" and turn "fake latency" on (if it's not already on)
                    if (gui.GetValue("fake latency") ~= 1) then
                        gui.SetValue("fake latency", 1)
                    end
                    if (gui.GetValue ("fake latency value") ~= mAutoFLFar:GetValue()) then
                        gui.SetValue("fake latency value", mAutoFLFar:GetValue())
                    end
                end
            end
        end


        --[[ Auto C2 ]]-- (Automatically use "Battle Cry" when looking at an enemy withoWeaponmAutoweapon weapon (for special voicelines))
        if (pWeapon:IsMeleeWeapon() == true)                          -- If we are using the Battle CryoWeaponmAutoweapon callout, and we are using aoWeaponmAutoweapon weapon
                                                    and (sneakyboy == false) then                                         -- and we are not invisible
            c2Timer = c2Timer + 1                                                                                         -- Add 1 to the c2Timer
            c2Timer2 = c2Timer2 + 1                                                                                       -- Add 1 to the c2Timer2
            if (c2Timer >= 0.5 * 66) then                                                                                 -- If the c2Timer is greater than or equal to 0.5 seconds
                c2Timer = 0                                                                                               -- Reset the c2Timer
                local mC2Source      = pLocal:GetAbsOrigin() + pLocal:GetPropVector( "localdata", "m_vecViewOffset[0]" )  -- Set "mC2Source" to the player's view offset
                local mC2Destination = mC2Source + engine.GetViewAngles():Forward() * 500;                                -- Set "mC2Destination" 500hu in front of the player's view angle
                local mC2Trace       = engine.TraceLine(mC2Source, mC2Destination, MASK_SHOT_HULL)                        -- Trace a line from "mC2Source" to "mC2Destination"
                if (mC2Trace.entity ~= nil) and (mC2Trace.entity:GetClass() == "CTFPlayer")                               -- If the trace hit a player
                                            and (mC2Trace.entity:GetTeamNumber() ~= pLocal:GetTeamNumber())               -- and the player is on a different team
                                            and ((c2Timer2 >= 2 * 66)) then                                               -- and the c2Timer2 is greater than to 2 seconds
                    client.Command("voicemenu 2 1", true)                                                                 -- Execute "voicemenu 2 1" in the console
                    --print("Successfully triggered C2")                                                                  -- Print to the console that we successfully triggered C2 (for debugging)
                end
            end
        end
        ::continue::
    end
    CheckTempOptions()
end


local myfont = draw.CreateFont( "Verdana", 16, 800 ) -- Create a font for doDraw
--[[ Code called every frame ]]--
local function doDraw() 
    if engine.Con_IsVisible() or engine.IsGameUIVisible() then
        return
    end



    --[[ Rocket Lines ]]-- (Shows trajectory of rockets (kinda bugged but works))
    if mRocketLines:GetValue() then -- If "Rocket Lines" is enabled
        local rockets = entities.FindByClass("CTFProjectile_Rocket") -- Find all rockets
        for i, rocket in pairs(rockets) do                          -- Loop through all rockets

            local rocketPos = rocket:GetAbsOrigin()               -- Set "rocketPos" to the rocket's position
            local rocketScreenPos = client.WorldToScreen(rocketPos) -- Set "rocketScreenPos" to the x/z coordinates of the rocket's position based on the player's screen
            local rocketDest = vector.Add(rocketPos, rocket:EstimateAbsVelocity()) -- Set "rocketDest" to the rocket's estimated direction based on the rocket's estimated velocity (this should probably be replaced with the rocket's direction)
            local rocketTrace = engine.TraceLine(rocketPos, rocketDest, MASK_SHOT_HULL) -- Trace a line from the rocket's position to the rocket's estimated direction until it hits something
            local hitPosScreen = client.WorldToScreen(rocketTrace.endpos) -- Set "hitPosScreen" to the x/z coordinates of the trace's hit position based on the player's screen

            draw.Color(255, 0, 0, 255) -- Set the color to red
            -- if type(exp) == "table" then printLuaTable(exp) else print( table.concat( {exp}, '\n' ) )
            draw.Line(rocketScreenPos[1], rocketScreenPos[2], hitPosScreen[1], hitPosScreen[2]) --Draw a line from the rocket to the trace's hit position
            draw.Line(rocketScreenPos[1] + 1, rocketScreenPos[2] + 1 , hitPosScreen[1] + 1, hitPosScreen[2]) --Used to make lines thicker (could probably be removed)
            draw.Line(rocketScreenPos[1] - 1, rocketScreenPos[2] - 1 , hitPosScreen[1] - 1, hitPosScreen[2])
        end
    end

    
    local players = entities.FindByClass("CTFPlayer")

    --[[ MEdic Finder ]]-- (Draws a cross on over friendly medics when pressing E (my default keybind for +helpme))
    if mMedicFinder:GetValue() == true then
        
        if (mfTimer == 0) then -- debug (can be removed?)
        end
        if input.IsButtonDown( KEY_E ) then                                                                                                    -- If the E key is pressed
            mfTimer = 1                                                                                                                        -- Activate Medic Finder
        end
        if (mfTimer >= 1) and (mfTimer < 12 * 66) then                                                                                         -- If the timer is >1/<12 seconds, show the cross
            mfTimer = mfTimer + 1
            if (mfTimer >= 3) then -- debug (can be removed?)
            end
            for i, p in ipairs(players) do
                if p:IsAlive() and p:GetTeamNumber() == entities.GetLocalPlayer():GetTeamNumber() then                                         -- If the player is alive and on the same team as the local player
                    local pWeapon = p:GetPropEntity("m_hActiveWeapon")                                                                         -- Set "pWeapon" to the player's active weapon
                    if pWeapon ~= nil then                                                                                                     -- Validate "pWeapon"
                        pWeaponIs = pWeapon:GetClass()                                                                                         -- Set "pWeaponIs" to the player's active weapon's class
                        if p:IsAlive() and not p:IsDormant() and (p:GetTeamNumber() == entities.GetLocalPlayer():GetTeamNumber()) then         -- If the player is alive and not dormant and on the same team as the local player
                            if (pWeaponIs == "CTFCrossbow")                                                                                    -- Check if the player's active weapon is a crossbow, bonesaw, syringe, or medigun. If so, they're a medic
                                    or (pWeaponIs == "CTFBonesaw") 
                                    or (pWeaponIs == "CTFSyringeGun") 
                                    or (pWeaponIs == "CWeaponMedigun") then                                                                    -- For some reason this doesn't work with decorated weapons
                                
                                local pPos = p:GetAbsOrigin() -- + (p:GetAbsOrigin() + p:GetPropVector("localdata", "m_vecViewOffset[0]") * 1  -- Set "pPos" to the medic's position
                                local pScreenPos2 = client.WorldToScreen(pPos)                                                                 -- Find the co-ords of the medic's absolute position based on the player's screen
                                local pScreenPos = client.WorldToScreen(pPos + p:GetPropVector("localdata", "m_vecViewOffset[0]"))             -- Find the co-ords of the medic's view offset
                                if (pScreenPos2 ~= nil) and (pScreenPos ~= nil) then                                                           -- Validate the co-ords
                                    local pScreenDistance = (pScreenPos2[2] - pScreenPos[2]) * 0.01                                            -- Find the distance between the medic's absolute position and view offset
                                    if pSCreenDistance == 0 then                                                                               -- If the distance is 0, set it to 1
                                        pScreenDistance = 1
                                    end
                                    -- Change the color based on distance from entities.GetLocalPlayer()
                                    distance = vector.Distance( pPos, entities.GetLocalPlayer():GetAbsOrigin() )                               -- Find the distance between the medic and the local player
                                    distanceMax = 1000                                                                                         -- Maximum range at which alpha is 100%/255
                                    distanceMin = 200                                                                                          -- Minimum range at which alpha is 0%/0
                                    distanceMaxColor = 255                                                                                     --Ranges for alpha
                                    distanceMinColor = 0                                                                                       -- Set this to ~100 to make the cross always visible despite the distance
                                    distanceColor = math.floor( (distanceMaxColor) * (distance - distanceMin) / (distanceMax - distanceMin) )  -- Calculate the alpha based on the distance
                                    if distanceColor < 0 then                                                                                  -- If the alpha is less than 0, set it to 0
                                        distanceColor = 0
                                    elseif distanceColor > 255 then                                                                            -- If the alpha is greater than 255, set it to 255
                                        distanceColor = 255
                                    end
                                    draw.Color(255, 0, 0, distanceColor)                                                                       -- Set the color to red with the calculated alpha
                                    
                                    local def1 = 15                                                                                            -- vvvvMath shit for the crossvvvv
                                    local def2 = 40
                                    local def3 = 50
                                    local def4 = 70
                                    local def5 = 110
                                    def1 = math.floor(def1 * pScreenDistance)
                                    def2 = math.floor(def2 * pScreenDistance)
                                    def3 = math.floor(def3 * pScreenDistance)
                                    def4 = math.floor(def4 * pScreenDistance)
                                    def5 = math.floor(def5 * pScreenDistance)
                                    draw.Line(pScreenPos2[1] + def1, pScreenPos2[2], pScreenPos2[1] - def1, pScreenPos2[2])                    -- vvv Draw the cross vvv
                                    draw.Line(pScreenPos2[1] + def1, pScreenPos2[2], pScreenPos2[1] + def1, pScreenPos2[2] - def2)
                                    draw.Line(pScreenPos2[1] + def1, pScreenPos2[2] - def2, pScreenPos2[1] + def3, pScreenPos2[2] - def2)
                                    draw.Line(pScreenPos2[1] + def3, pScreenPos2[2] - def2, pScreenPos2[1] + def3, pScreenPos2[2] - def4)
                                    draw.Line(pScreenPos2[1] + def3, pScreenPos2[2] - def4, pScreenPos2[1] + def1, pScreenPos2[2] - def4)
                                    draw.Line(pScreenPos2[1] + def1, pScreenPos2[2] - def4, pScreenPos2[1] + def1, pScreenPos2[2] - def5)
                                    draw.Line(pScreenPos2[1] + def1, pScreenPos2[2] - def5, pScreenPos2[1] - def1, pScreenPos2[2] - def5)
                                    draw.Line(pScreenPos2[1] - def1, pScreenPos2[2] - def5, pScreenPos2[1] - def1, pScreenPos2[2] - def4)
                                    draw.Line(pScreenPos2[1] - def1, pScreenPos2[2] - def4, pScreenPos2[1] - def3, pScreenPos2[2] - def4)
                                    draw.Line(pScreenPos2[1] - def3, pScreenPos2[2] - def4, pScreenPos2[1] - def3, pScreenPos2[2] - def2)
                                    draw.Line(pScreenPos2[1] - def3, pScreenPos2[2] - def2, pScreenPos2[1] - def1, pScreenPos2[2] - def2)
                                    draw.Line(pScreenPos2[1] - def1, pScreenPos2[2] - def2, pScreenPos2[1] - def1, pScreenPos2[2])
                                    draw.Line(pScreenPos2[1] + def1 + 1, pScreenPos2[2] + 1, pScreenPos2[1] - def1 + 1, pScreenPos2[2] + 1)    -- vvv Draw the cross again for extra width vvv
                                    draw.Line(pScreenPos2[1] + def1 + 1, pScreenPos2[2] + 1, pScreenPos2[1] + def1 + 1, pScreenPos2[2] - def2 + 1)
                                    draw.Line(pScreenPos2[1] + def1 + 1, pScreenPos2[2] - def2 + 1, pScreenPos2[1] + def3 + 1, pScreenPos2[2] - def2 + 1)
                                    draw.Line(pScreenPos2[1] + def3 + 1, pScreenPos2[2] - def2 + 1, pScreenPos2[1] + def3 + 1, pScreenPos2[2] - def4 + 1)
                                    draw.Line(pScreenPos2[1] + def3 + 1, pScreenPos2[2] - def4 + 1, pScreenPos2[1] + def1 + 1, pScreenPos2[2] - def4 + 1)
                                    draw.Line(pScreenPos2[1] + def1 + 1, pScreenPos2[2] - def4 + 1, pScreenPos2[1] + def1 + 1, pScreenPos2[2] - def5 + 1)
                                    draw.Line(pScreenPos2[1] + def1 + 1, pScreenPos2[2] - def5 + 1, pScreenPos2[1] - def1 + 1, pScreenPos2[2] - def5 + 1)
                                    draw.Line(pScreenPos2[1] - def1 + 1, pScreenPos2[2] - def5 + 1, pScreenPos2[1] - def1 + 1, pScreenPos2[2] - def4 + 1)
                                    draw.Line(pScreenPos2[1] - def1 + 1, pScreenPos2[2] - def4 + 1, pScreenPos2[1] - def3 + 1, pScreenPos2[2] - def4 + 1)
                                    draw.Line(pScreenPos2[1] - def3 + 1, pScreenPos2[2] - def4 + 1, pScreenPos2[1] - def3 + 1, pScreenPos2[2] - def2 + 1)
                                    draw.Line(pScreenPos2[1] - def3 + 1, pScreenPos2[2] - def2 + 1, pScreenPos2[1] - def1 + 1, pScreenPos2[2] - def2 + 1)
                                    draw.Line(pScreenPos2[1] - def1 + 1, pScreenPos2[2] - def2 + 1, pScreenPos2[1] - def1 + 1, pScreenPos2[2] + 1)
                                end
                            end
                        --else
                        -- todo: Color cross based on uber %, rainbow at 100% uber
                        -- todo: Display distance from player in the cross
                        -- todo: Warnings if no medics were found
                        end
                    end
                end
            end
        end
        if (mfTimer > 12 * 66) then                                                                                                            -- Remove the cross after 12 seconds (isn't this fps-based? on 144hz monitors, 66 = 5.5 seconds. In that case, this may show longer than it should for others)
            mfTimer = 0
        end
    end

end


--[[ Executes upon stringCmd ]]--
local function OnStringCmd(stringCmd)  -- Called when a string command is sent
    local cmd = stringCmd:Get()        -- Set "cmd" to the string command
    local blockCmd = false             -- Set "blockCmd" to false

    --[[ Allow \n in chat ]]-- (This method is scuffed, but it works.)
                 -- If Chat New Line is enabled
        cmd = cmd:gsub("\\n", "\n")                 -- Replace all instances of "\\n" with "\n"
        if cmd:find("say_team", 1, true) == 1 then  -- If the command is "say_team"
            cmd = cmd:sub(11, -2)                   -- Remove the first 11 characters ("say_team ") and the last 2 characters (");")
            client.ChatTeamSay(cmd)                 -- Send the modified command to the server
            blockCmd = true                         -- Execute the "blockCmd" function
        elseif cmd:find("say", 1, true) == 1 then   -- If the command is "say"
            cmd = cmd:sub(6, -2)                    -- Remove the first 6 characters ("say ") and the last 2 characters (");")
            client.ChatSay(cmd)                     -- Send the modified command to the server
            blockCmd = true                         -- Execute the "blockCmd" function
        end

    --[[ Block Commands ]]-- 
    if blockCmd then       -- If "blockCmd" is triggered
        stringCmd:Set("")  -- Set the string command to "", disabling the command
    end
end

--[[ Executes upon receiving a message ]]--
local function OnUserMessage(userMsg)  -- Called when a user message is received
    local blockMessage = false         -- Set "blockMessage" to false (used to keep track of whether or not to block the message)

    --[[ Removals: RTD Effects ]]-- (Attempt to negate bad RTD effects)
    if mRemovals:IsSelected("RTD Effects") then                                                                                    -- If RTD Effects is enabled
        if userMsg:GetID() == Shake then blockMessage = true end                                                                   -- If the message is "Shake", block the message
        if userMsg:GetID() == Fade  then blockMessage = true end                                                                   -- If the message is "Fade", block the message

        if userMsg:GetID() == TextMsg then                                                                                         -- If the message is "TextMsg"
            userMsg:Reset()                                                                                                        -- Reset the message
            local msgDest = userMsg:ReadByte()                                                                                     -- Set "msgDest" to the message destination
            local msgName = userMsg:ReadString(256)                                                                                -- Set "msgName" to the message name

            if string.find(msgName, "[RTD]") then                                                                                  -- If the message name contains "[RTD]"
                if string.find(msgName, "Your perk has worn off") or string.find(msgName, "You have died during your roll") then   -- If the message name contains "Your perk has worn off" or "You have died during your roll"
                    CurrentRTD = ""                                                                                                -- Reset the current RTD, so we can detect when it changes
                elseif string.find(msgName, "Cursed")    then CurrentRTD = "Cursed"                                                -- If the message name contains "Cursed", set the current RTD to "Cursed"
                elseif string.find(msgName, "Drugged")   then CurrentRTD = "Drugged"                                               -- If the message name contains "Drugged", set the current RTD to "Drugged"
                elseif string.find(msgName, "Bad Sauce") then CurrentRTD = "Bad Sauce"                                             -- If the message name contains "Bad Sauce", set the current RTD to "Bad Sauce"
                end
            end
        end
    else
        CurrentRTD = "" -- Reset the current RTD if RTD Effects is disabled
    end

    --[[ Removals: Hud Text  (Remove the hud text of bad RTD effects)
    if mRemovals:IsSelected("HUD Texts") then                                                    -- If HUD Texts is enabled
        if userMsg:GetID() == HudText or userMsg:GetID() == HudMsg then blockMessage = true end  -- If the message is "HudText" or "HudMsg", block the message
    end
    ]]--s
    --[[ Block messages ]]--
    if blockMessage then                        -- If "blockMessage" is triggered
        local msgLength = userMsg:GetDataBits() -- Set "msgLength" to the message length in bits
        userMsg:Reset()                         -- Reset the message
        for i = 1, msgLength do                 -- For each bit in the message, starting at 1
            userMsg:WriteBit(0)                 -- Write a 0, effectively removing the message
        end
    end
end

--[[ Remove the menu when unloaded ]]--
local function OnUnload()                                -- Called when the script is unloaded
    MenuLib.RemoveMenu(menu)                             -- Remove the menu
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

--[[inffinite sandwitch exploid]]


local KeyHelper, Timer, WPlayer = Lib.Utils.KeyHelper, Lib.Utils.Timer, Lib.TF2.WPlayer
local key = KeyHelper.new(KEY_J)
local tauntTimer = Timer.new()

        ---@param userCmd UserCmd
        local function OnUserCmd(userCmd)
                local localPlayer = WPlayer.GetLocal()
                local weapon = localPlayer:GetActiveWeapon()
                if not localPlayer:IsAlive()
                    or not key:Down()
                    or engine.IsGameUIVisible()
                    or msandwitchex:GetValue() == false
                    or playerClass ~= 5
                    then return end
                if weapon:IsShootingWeapon() or weapon:IsMeleeWeapon() then return end

                userCmd:SetButtons(userCmd:GetButtons() | IN_ATTACK)

                if tauntTimer:Run(0.5) then
                    client.Command("taunt", true)
                end
        end
    


--[[ Unregister previous callbacks ]]--
callbacks.Unregister("CreateMove", "MCT_CreateMove")            -- Unregister the "CreateMove" callback
callbacks.Unregister("SendStringCmd", "MCT_StringCmd")          -- Unregister the "SendStringCmd" callback
callbacks.Unregister("DispatchUserMessage", "MCT_UserMessage")  -- Unregister the "DispatchUserMessage" callback
callbacks.Unregister("Unload", "MCT_Unload")                    -- Unregister the "Unload" callback
callbacks.Unregister("Draw", "MCT_Draw")                        -- Unregister the "Draw" callback
callbacks.Unregister("CreateMove", "LNX_IF_UserCmd")

--[[ Register callbacks ]]--
callbacks.Register("CreateMove", "MCT_CreateMove", OnCreateMove)             -- Register the "CreateMove" callback
callbacks.Register("SendStringCmd", "MCT_StringCmd", OnStringCmd)            -- Register the "SendStringCmd" callback
callbacks.Register("DispatchUserMessage", "MCT_UserMessage", OnUserMessage)  -- Register the "DispatchUserMessage" callback
callbacks.Register("Unload", "MCT_Unload", OnUnload)                         -- Register the "Unload" callback
callbacks.Register("Draw", "MCT_Draw", doDraw)                               -- Register the "Draw" callback
callbacks.Register("CreateMove", "LNX_IF_UserCmd", OnUserCmd)
--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded
