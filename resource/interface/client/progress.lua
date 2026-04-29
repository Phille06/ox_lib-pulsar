--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

local progress
local DisableControlAction = DisableControlAction
local DisablePlayerFiring = DisablePlayerFiring
local playerState = LocalPlayer.state
local createdProps = {}
local maxProps = GetConvarInt('ox:progressPropLimit', 2)

---@class ProgressPropProps
---@field model string
---@field bone? number
---@field pos vector3
---@field rot vector3
---@field rotOrder? number

---@class ProgressProps
---@field label? string
---@field duration number
---@field position? 'middle' | 'bottom'
---@field useWhileDead? boolean
---@field allowRagdoll? boolean
---@field allowCuffed? boolean
---@field allowFalling? boolean
---@field allowSwimming? boolean
---@field canCancel? boolean
---@field anim? { dict?: string, clip: string, flag?: number, blendIn?: number, blendOut?: number, duration?: number, playbackRate?: number, lockX?: boolean, lockY?: boolean, lockZ?: boolean, scenario?: string, playEnter?: boolean }
---@field prop? ProgressPropProps | ProgressPropProps[]
---@field disable? { move?: boolean, sprint?: boolean, car?: boolean, combat?: boolean, mouse?: boolean }

local function createProp(ped, prop)
    local ok, result = pcall(lib.requestModel, prop.model)

    if not ok then return lib.print.error(result) end

    local coords = GetEntityCoords(ped)
    local object = CreateObject(result, coords.x, coords.y, coords.z, false, false, false)

    AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, prop.bone or 60309), prop.pos.x, prop.pos.y, prop.pos.z, prop.rot.x, prop.rot.y, prop.rot.z, true,
        true, false, true, prop.rotOrder or 0, true)
    SetModelAsNoLongerNeeded(result)

    return object
end

local function interruptProgress(data)
    if not data.useWhileDead and IsEntityDead(cache.ped) then return true end
    if not data.allowRagdoll and IsPedRagdoll(cache.ped) then return true end
    if not data.allowCuffed and IsPedCuffed(cache.ped) then return true end
    if not data.allowFalling and IsPedFalling(cache.ped) then return true end
    if not data.allowSwimming and IsPedSwimming(cache.ped) then return true end
end

local isFivem = cache.game == 'fivem'

local controls = {
    INPUT_LOOK_LR = isFivem and 1 or 0xA987235F,
    INPUT_LOOK_UD = isFivem and 2 or 0xD2047988,
    INPUT_SPRINT = isFivem and 21 or 0x8FFC75D6,
    INPUT_AIM = isFivem and 25 or 0xF84FA74F,
    INPUT_MOVE_LR = isFivem and 30 or 0x4D8FB4C1,
    INPUT_MOVE_UD = isFivem and 31 or 0xFDA83190,
    INPUT_DUCK = isFivem and 36 or 0xDB096B85,
    INPUT_VEH_MOVE_LEFT_ONLY = isFivem and 63 or 0x9DF54706,
    INPUT_VEH_MOVE_RIGHT_ONLY = isFivem and 64 or 0x97A8FD98,
    INPUT_VEH_ACCELERATE = isFivem and 71 or 0x5B9FD4E2,
    INPUT_VEH_BRAKE = isFivem and 72 or 0x6E1F639B,
    INPUT_VEH_EXIT = isFivem and 75 or 0xFEFAB9B4,
    INPUT_VEH_MOUSE_CONTROL_OVERRIDE = isFivem and 106 or 0x39CCABD5
}

local function convertTonorr(data)
    local disables = {
        disableMovement    = data.disable and (data.disable.move or data.disable.movement) or false,
        disableCarMovement = data.disable and (data.disable.car or data.disable.vehicle) or false,
        disableMouse       = data.disable and (data.disable.mouse) or false,
        disableCombat      = data.disable and (data.disable.combat ~= false) or true,
    }

    local action = {
        name = data.label or "progress",
        duration = data.duration or 0,
        label = data.label or "",
        useWhileDead = data.useWhileDead,
        canCancel = data.canCancel ~= false,
        controlDisables = disables,

        ignoreModifier = true,
        disarm = true,
    }

    if data.anim then
        if type(data.anim) == 'table' then
            local dict  = data.anim.dict or data.anim.animDict
            local clip  = data.anim.clip or data.anim.anim
            local flags = data.anim.flag or data.anim.flags

            if dict and clip then
                local defaultFlags = 49
                action.animation = {
                    animDict = dict,
                    anim = clip,
                    flags = flags or defaultFlags,
                }

            elseif data.anim.scenario then
                action.animation = { task = data.anim.scenario }

            elseif type(data.anim[1]) == 'string' and type(data.anim[2]) == 'string' then
                local defaultFlags = 49
                action.animation = {
                    animDict = data.anim[1],
                    anim = data.anim[2],
                    flags = data.anim[3] or defaultFlags,
                }
            end
        elseif type(data.anim) == 'string' then
            action.animation = { task = data.anim }
        end
    end

    local function convertProp(prop)
        if not prop then return nil end

        return {
            model = prop.model,
            bone = prop.bone,
            coords = prop.pos and {
                x = prop.pos.x,
                y = prop.pos.y,
                z = prop.pos.z,
            } or prop.coords,
            rotation = prop.rot and {
                x = prop.rot.x,
                y = prop.rot.y,
                z = prop.rot.z,
            } or prop.rotation,
        }
    end

    if data.prop then
        if data.prop[1] then
            action.prop = convertProp(data.prop[1])
            action.propTwo = convertProp(data.prop[2])
        else
            action.prop = convertProp(data.prop)
        end
    end

    return action
end

---@param data ProgressProps
local function startProgress(data)
    playerState.invBusy = true
    progress = data
    local anim = data.anim

    if anim then
        if anim.dict then
            lib.requestAnimDict(anim.dict)

            TaskPlayAnim(cache.ped, anim.dict, anim.clip, anim.blendIn or 3.0, anim.blendOut or 1.0, anim.duration or -1, anim.flag or 49, anim.playbackRate or 0,
                anim.lockX, anim.lockY, anim.lockZ)
            RemoveAnimDict(anim.dict)
        elseif anim.scenario then
            TaskStartScenarioInPlace(cache.ped, anim.scenario, 0, anim.playEnter == nil or anim.playEnter --[[@as boolean]])
        end
    end

    if data.prop then
        TriggerServerEvent('ox_lib:progressProps', data.prop)
    end

    local disable = data.disable
    local startTime = GetGameTimer()

    while progress do
        if disable then
            if disable.mouse then
                DisableControlAction(0, controls.INPUT_LOOK_LR, true)
                DisableControlAction(0, controls.INPUT_LOOK_UD, true)
                DisableControlAction(0, controls.INPUT_VEH_MOUSE_CONTROL_OVERRIDE, true)
            end

            if disable.move then
                DisableControlAction(0, controls.INPUT_SPRINT, true)
                DisableControlAction(0, controls.INPUT_MOVE_LR, true)
                DisableControlAction(0, controls.INPUT_MOVE_UD, true)
                DisableControlAction(0, controls.INPUT_DUCK, true)
            end

            if disable.sprint and not disable.move then
                DisableControlAction(0, controls.INPUT_SPRINT, true)
            end

            if disable.car then
                DisableControlAction(0, controls.INPUT_VEH_MOVE_LEFT_ONLY, true)
                DisableControlAction(0, controls.INPUT_VEH_MOVE_RIGHT_ONLY, true)
                DisableControlAction(0, controls.INPUT_VEH_ACCELERATE, true)
                DisableControlAction(0, controls.INPUT_VEH_BRAKE, true)
                DisableControlAction(0, controls.INPUT_VEH_EXIT, true)
            end

            if disable.combat then
                DisableControlAction(0, controls.INPUT_AIM, true)
                DisablePlayerFiring(cache.playerId, true)
            end
        end

        if interruptProgress(progress) then
            progress = false
        end

        Wait(0)
    end

    if data.prop then
        TriggerServerEvent('ox_lib:progressProps', nil)
    end

    if anim then
        if anim.dict then
            StopAnimTask(cache.ped, anim.dict, anim.clip, 1.0)
            Wait(0) -- This is needed here otherwise the StopAnimTask is cancelled
        else
            ClearPedTasks(cache.ped)
        end
    end

    playerState.invBusy = false
    local duration = progress ~= false and GetGameTimer() - startTime + 100 -- give slight leeway

    if progress == false or duration <= data.duration then
        SendNUIMessage({ action = 'progressCancel' })
        return false
    end

    return true
end

---@param data ProgressProps
---@return boolean?
function lib.progressBar(data)
    local action = convertTonorr(data)

    local p = promise.new()

    exports['pulsar-hud']:Progress(action, function(cancelled)
        p:resolve(not cancelled)
    end)

    return Citizen.Await(p)
end

---@param data ProgressProps
---@return boolean?
function lib.progressCircle(data) -- pulsar does not have this we use normal progress bar for it
    return lib.progressBar(data)
end

function lib.cancelProgress()
    exports['pulsar-hud']:ProgressCancel()
end

---@return boolean
function lib.progressActive()
    return LocalPlayer.state.doingAction or false
end

RegisterNUICallback('progressComplete', function(data, cb)
    cb(1)
    progress = nil
end)

RegisterCommand('cancelprogress', function()
    progress = false
    exports['pulsar-hud']:ProgressCancel()
end)

if isFivem then
    RegisterKeyMapping('cancelprogress', locale('cancel_progress'), 'keyboard', 'x')
end

local function deleteProgressProps(serverId)
    local playerProps = createdProps[serverId]

    if not playerProps then return end

    createdProps[serverId] = nil

    for i = 1, #playerProps do
        local prop = playerProps[i]

        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
end

RegisterNetEvent('onPlayerDropped', function(serverId)
    deleteProgressProps(serverId)
end)

AddStateBagChangeHandler('lib:progressProps', nil, function(bagName, key, value, reserved, replicated)
    if replicated then return end

    local ply = GetPlayerFromStateBagName(bagName)
    if ply == 0 then return end

    local ped = GetPlayerPed(ply)
    local serverId = GetPlayerServerId(ply)

    if not value or createdProps[serverId] then
        return deleteProgressProps(serverId)
    end

    local playerProps = {}

    if value.model then
        local prop = createProp(ped, value)

        if prop then
            playerProps[#playerProps + 1] = prop
        end
    else
        local propCount = math.min(maxProps, #value)

        for i = 1, propCount do
            local prop = createProp(ped, value[i])

            if prop then
                playerProps[#playerProps + 1] = prop
            end
        end
    end

    createdProps[serverId] = playerProps
end)
