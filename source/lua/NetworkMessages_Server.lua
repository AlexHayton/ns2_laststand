// ======= Copyright (c) 2003-2011, Unknown Worlds Entertainment, Inc. All rights reserved. =======
//
// lua\NetworkMessages_Server.lua
//
//    Created by:   Charlie Cleveland (charlie@unknownworlds.com) and
//                  Max McGuire (max@unknownworlds.com)
//
// See the Messages section of the Networking docs in Spark Engine scripting docs for details.
//
// ========= For more information, visit us at http://www.unknownworlds.com =====================

function OnCommandCommMarqueeSelect(client, message)
    
    local player = client:GetControllingPlayer()
    if player:GetIsCommander() then
        player:MarqueeSelectEntities(ParseCommMarqueeSelectMessage(message))
    end
    
end

function OnCommandParseSelectHotkeyGroup(client, message)

    local player = client:GetControllingPlayer()
    if player:GetIsCommander() then
        player:SelectHotkeyGroup(ParseSelectHotkeyGroupMessage(message))
    end
    
end

function OnCommandParseCreateHotkeyGroup(client, message)

    local player = client:GetControllingPlayer()
    if player:GetIsCommander() then
        player:CreateHotkeyGroup(message.groupNumber)
    end
    
end

function OnCommandCommAction(client, message)

    local techId = ParseCommActionMessage(message)
    
    local player = client:GetControllingPlayer()
    if player and player:GetIsCommander() then
        player:ProcessTechTreeAction(techId, nil, nil)
    else
        Shared.Message("CommAction message received with invalid player. TechID: " .. EnumToString(kTechId, techId))
    end
    
end

function OnCommandCommTargetedAction(client, message)

    local player = client:GetControllingPlayer()
    if player:GetIsCommander() then
    
        local techId, pickVec, orientation, entityId = ParseCommTargetedActionMessage(message)
        player:ProcessTechTreeAction(techId, pickVec, orientation, false, entityId)
    
    end
    
end

function OnCommandCommTargetedActionWorld(client, message)

    local player = client:GetControllingPlayer()
    if player:GetIsCommander() then
    
        local techId, pickVec, orientation, entityId = ParseCommTargetedActionMessage(message)
        player:ProcessTechTreeAction(techId, pickVec, orientation, true, entityId)
    
    end
    
end

function OnCommandGorgeBuildStructure(client, message)

    local player = client:GetControllingPlayer()
    local origin, direction, structureIndex, lastClickedPosition = ParseGorgeBuildMessage(message)
    
    local dropStructureAbility = player:GetWeapon(DropStructureAbility.kMapName)
    // The player may not have an active weapon if the message is sent
    // after the player has gone back to the ready room for example.
    if dropStructureAbility then
        dropStructureAbility:OnDropStructure(origin, direction, structureIndex, lastClickedPosition)
    end
    
end

function OnCommandMutePlayer(client, message)

    local player = client:GetControllingPlayer()
    local muteClientIndex, setMute = ParseMutePlayerMessage(message)
    player:SetClientMuted(muteClientIndex, setMute)
    
end

function OnCommandCommClickSelect(client, message)

    local player = client:GetControllingPlayer()
    if player:GetIsCommander() then
        player:ClickSelectEntities(ParseCommClickSelectMessage(message))
    end
    
end

function OnCommandSelectUnit(client, message)

    local player = client:GetControllingPlayer()
    if player:isa("Commander") then
    
        local teamNumber, unit, selected, keepSelection = ParseSelectUnitMessage(message)
        
        if not keepSelection then
            DeselectAllUnits(player:GetTeamNumber())
        end
        
        if unit then
            unit:SetSelected(teamNumber, selected)
        end
    
    end

end

local kChatsPerSecondAdded = 1
local kMaxChatsInBucket = 5
local function CheckChatAllowed(client)

    client.chatTokenBucket = client.chatTokenBucket or CreateTokenBucket(kChatsPerSecondAdded, kMaxChatsInBucket)
    // Returns true if there was a token to remove.
    return client.chatTokenBucket:RemoveTokens(1)
    
end

local function GetChatPlayerData(client)

    local playerName = "Admin"
    local playerLocationId = -1
    local playerTeamNumber = kTeamReadyRoom
    local playerTeamType = kNeutralTeamType
    
    if client then
    
        local player = client:GetControllingPlayer()
        if not player then
            return
        end
        playerName = player:GetName()
        playerLocationId = player.locationId
        playerTeamNumber = player:GetTeamNumber()
        playerTeamType = player:GetTeamType()
        
    end
    
    return playerName, playerLocationId, playerTeamNumber, playerTeamType
    
end

local function OnChatReceived(client, message)

    if not CheckChatAllowed(client) then
        return
    end
    
    chatMessage = string.sub(message.message, 1, kMaxChatLength)
    if chatMessage and string.len(chatMessage) > 0 then
    
        local playerName, playerLocationId, playerTeamNumber, playerTeamType = GetChatPlayerData(client)
        
        if playerName then
        
            if message.teamOnly then
            
                local players = GetEntitiesForTeam("Player", playerTeamNumber)
                for index, player in ipairs(players) do
                    Server.SendNetworkMessage(player, "Chat", BuildChatMessage(true, playerName, playerLocationId, playerTeamNumber, playerTeamType, chatMessage), true)
                end
                
            else
                Server.SendNetworkMessage("Chat", BuildChatMessage(false, playerName, playerLocationId, playerTeamNumber, playerTeamType, chatMessage), true)
            end
            
            Shared.Message("Chat " .. (message.teamOnly and "Team - " or "All - ") .. playerName .. ": " .. chatMessage)
            
            // We save a history of chat messages received on the Server.
            Server.AddChatToHistory(chatMessage, playerName, client:GetUserId(), playerTeamNumber, message.teamOnly)
            
        end
        
    end
    
end

local function OnCommandCommPing(client, message)

    if Server then
    
        local player = client:GetControllingPlayer()
        if player then
            local team = player:GetTeam()
            team:SetCommanderPing(message.position)
        end
    
    end

end

local function OnCommandSetRookieMode(client, networkMessage)

    if client ~= nil then
    
        local player = client:GetControllingPlayer()
        if player then 
        
            local rookieMode = ParseRookieMessage(networkMessage)
            player:SetRookieMode(rookieMode)
            
        end
        
    end

end

local function OnCommandSetCommStatus(client, networkMessage)

    if client ~= nil then
    
        local player = client:GetControllingPlayer()
        if player then 
        
            local commStatus = ParseCommunicationStatus(networkMessage)
            player:SetCommunicationStatus(commStatus)
            
        end
        
    end

end

local function OnMessageBuy(client, buyMessage)

    local player = client:GetControllingPlayer()
    
    if player and player:GetIsAllowedToBuy() then
    
        local purchaseTechIds = ParseBuyMessage(buyMessage)
        player:ProcessBuyAction(purchaseTechIds)
        
    end
    
end


local function OnVoiceMessage(client, message)

    local voiceId = ParseVoiceMessage(message)
    local player = client:GetControllingPlayer()
    
    if player then
    
        local soundData = GetVoiceSoundData(voiceId)
        if soundData then
        
            local soundName = soundData.Sound
            
            if soundData.Function then            
                soundName = soundData.Function(player) or soundName    
            end
            
            // the request sounds always play for everyone since its something the player is doing actively
            // the auto voice overs are triggered somewhere else server side and play for team only
            if soundName then
                StartSoundEffectOnEntity(soundName, player)
            end
            
            local team = player:GetTeam()
            if team then

                // send alert so a marine commander for example gets notified about players who need a medpack / ammo etc.
                if not GetIsPointInGorgeTunnel(player:GetOrigin()) and soundData.AlertTechId and soundData.AlertTechId ~= kTechId.None then
                    team:TriggerAlert(soundData.AlertTechId, player)
                end
                
            end
        
        end
    
    end

end

local function OnConnectMessage(client, message)

    local armorType = ParseConnectMessage(message)
    if client then
    
        local allowed = armorType == kArmorType.Green or
                       (armorType == kArmorType.Black and GetHasBlackArmor(client)) or
                       (armorType == kArmorType.Deluxe and GetHasDeluxeEdition(client))
                        
        if allowed then
            client.armorType = armorType
        end
        
        local player = client:GetControllingPlayer()
        if player then
            player:OnClientUpdated(client)
        end
    
    end

end

local function OnSetNameMessage(client, message)

    local name = message.name
    if client ~= nil and name ~= nil then
    
        local player = client:GetControllingPlayer()
        
        name = TrimName(name)
        
        // Treat "NsPlayer" as special.
        if name ~= player:GetName() and name ~= kDefaultPlayerName and string.len(name) > 0 then
        
            local prevName = player:GetName()
            player:SetName(name)
            
            if prevName == kDefaultPlayerName then
                Server.Broadcast(nil, string.format("%s connected.", player:GetName()))
            elseif prevName ~= player:GetName() then
                Server.Broadcast(nil, string.format("%s is now known as %s.", prevName, player:GetName()))
            end
            
        end
        
    end
    
end
Server.HookNetworkMessage("SetName", OnSetNameMessage)

local function onSpectatePlayer(client, message)

    local spectatorPlayer = client:GetControllingPlayer()
    if spectatorPlayer then

        // This only works for players on the spectator team.
        if spectatorPlayer:GetTeamNumber() == kSpectatorIndex then
            client:GetControllingPlayer():SelectEntity(message.entityId)
        end
        
    end
    
end
Server.HookNetworkMessage("SpectatePlayer", onSpectatePlayer)

local function OnSwitchFromFirstPersonSpectate(client, message)

    local spectatorPlayer = client:GetControllingPlayer()
    if client:GetSpectatingPlayer() and spectatorPlayer then
    
        // This only works for players on the spectator team.
        if spectatorPlayer:GetTeamNumber() == kSpectatorIndex then
            client:GetControllingPlayer():SetSpectatorMode(message.mode)
        end
        
    end
    
end
Server.HookNetworkMessage("SwitchFromFirstPersonSpectate", OnSwitchFromFirstPersonSpectate)

local function OnSwitchFirstPersonSpectatePlayer(client, message)

    if client:GetSpectatingPlayer() and client:GetControllingPlayer() then
    
        if client:GetControllingPlayer().CycleSpectatingPlayer then
            client:GetControllingPlayer():CycleSpectatingPlayer(client:GetSpectatingPlayer(), message.forward)
        end
        
    end
    
end
Server.HookNetworkMessage("SwitchFirstPersonSpectatePlayer", OnSwitchFirstPersonSpectatePlayer)

Server.HookNetworkMessage("SelectUnit", OnCommandSelectUnit)
Server.HookNetworkMessage("SelectHotkeyGroup", OnCommandParseSelectHotkeyGroup)
Server.HookNetworkMessage("CreateHotKeyGroup", OnCommandParseCreateHotkeyGroup)
Server.HookNetworkMessage("CommAction", OnCommandCommAction)
Server.HookNetworkMessage("CommTargetedAction", OnCommandCommTargetedAction)
Server.HookNetworkMessage("CommTargetedActionWorld", OnCommandCommTargetedActionWorld)
Server.HookNetworkMessage("GorgeBuildStructure", OnCommandGorgeBuildStructure)
Server.HookNetworkMessage("MutePlayer", OnCommandMutePlayer)
Server.HookNetworkMessage("ChatClient", OnChatReceived)
Server.HookNetworkMessage("CommanderPing", OnCommandCommPing)
Server.HookNetworkMessage("SetRookieMode", OnCommandSetRookieMode)
Server.HookNetworkMessage("SetCommunicationStatus", OnCommandSetCommStatus)
Server.HookNetworkMessage("Buy", OnMessageBuy)
Server.HookNetworkMessage("VoiceMessage", OnVoiceMessage)
Server.HookNetworkMessage("ConnectMessage", OnConnectMessage)


// Last Stand messages
local function OnSpawnAlien(client, message)
    
    local spectatorPlayer = client:GetControllingPlayer()
    if spectatorPlayer then
        spectatorPlayer:OnSpawnAlien(message.choice)
    end

end

local function OnJoinTeam(client, message)
    local player = client:GetControllingPlayer()    
    if GetGamerules():GetCanJoinTeamNumber(message.teamIndex) then
        GetGamerules():JoinTeam(player, message.teamIndex)
    end    
end

Server.HookNetworkMessage("SpawnAlien", OnSpawnAlien)
Server.HookNetworkMessage("JoinTeam", OnJoinTeam)
