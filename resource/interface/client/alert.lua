--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---@type promise?
local alert = nil
local alertId = 0

---@class AlertDialogProps
---@field header string;
---@field content string;
---@field centered? boolean?;
---@field size? 'xs' | 'sm' | 'md' | 'lg' | 'xl';
---@field overflow? boolean?;
---@field cancel? boolean?;
---@field labels? {cancel?: string, confirm?: string}

---@param data AlertDialogProps
---@param timeout? number Force the window to timeout after `x` milliseconds.
---@return 'cancel' | 'confirm' | nil
---@type promise?
local alert = nil
local alertId = 0

---@class AlertDialogProps
---@field header string
---@field content string
---@field centered? boolean
---@field size? 'xs' | 'sm' | 'md' | 'lg' | 'xl'
---@field overflow? boolean
---@field cancel? boolean
---@field labels? {cancel?: string, confirm?: string}

---@param data AlertDialogProps
---@param timeout? number
---@return 'confirm' | 'cancel' | nil
function lib.alertDialog(data, timeout)
    if alert then return end

    local id = alertId + 1
    alertId = id
    alert = promise.new()

    local events = {
        yes = ('alert:result:%s:%d:yes'):format(GetCurrentResourceName(), GetGameTimer()),
        no = ('alert:result:%s:%d:no'):format(GetCurrentResourceName(), GetGameTimer())
    }

    local description = data.content or ""
    local denyLabel = data.labels and data.labels.cancel or "Cancel"
    local acceptLabel = data.labels and data.labels.confirm or "Confirm"

    exports['pulsar-hud']:ConfirmShow(data.header, events, description, data, denyLabel, acceptLabel)

    local yesHandler = AddEventHandler(events.yes, function()
        if alert and alertId == id then
            local p = alert
            alert = nil
            p:resolve('confirm')
        end
    end)

    local noHandler = AddEventHandler(events.no, function()
        if alert and alertId == id then
            local p = alert
            alert = nil
            p:resolve('cancel')
        end
    end)

    local closedHandler = AddEventHandler('Input:Closed', function()
        if alert and alertId == id then
            local p = alert
            alert = nil
            p:resolve('cancel')
        end
    end)

    if timeout then
        SetTimeout(timeout, function()
            if alert and alertId == id then
                local p = alert
                alert = nil
                p:resolve(nil)
            end
        end)
    end

    local result = Citizen.Await(alert)

    RemoveEventHandler(yesHandler)
    RemoveEventHandler(noHandler)
    RemoveEventHandler(closedHandler)

    return result
end

function lib.closeAlertDialog(reason)
    if not alert then return end

    exports['pulsar-hud']:ConfirmClose()

    local p = alert
    alert = nil

    if reason then
        p:reject(reason)
    else
        p:resolve(nil)
    end
end

RegisterNetEvent('ox_lib:alertDialog', lib.alertDialog)