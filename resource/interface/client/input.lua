--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

local inputPromise

---@class InputDialogRowProps
---@field type 'input' | 'number' | 'checkbox' | 'select' | 'slider' | 'multi-select' | 'date' | 'date-range' | 'time' | 'textarea' | 'color'
---@field label string
---@field options? table
---@field password? boolean
---@field icon? string
---@field placeholder? string
---@field default? any
---@field disabled? boolean
---@field checked? boolean
---@field min? number
---@field max? number
---@field step? number
---@field required? boolean
---@field minLength? number
---@field maxLength? number
---@field description? string

---@class InputDialogOptionsProps
---@field allowCancel? boolean
---@field size? 'xs' | 'sm' | 'md' | 'lg' | 'xl'

local function normalizeRows(rows)
    local normalized = {}

    for i, row in ipairs(rows or {}) do
        if type(row) == 'string' then
            row = { type = 'input', label = row }
        end

        local inputType = row.type or 'text'
        if inputType == 'input' then
            inputType = 'text'
        end

        local options = row.options or {}
        local inputProps = options.inputProps or {}

        if row.min ~= nil then inputProps.min = row.min end
        if row.max ~= nil then inputProps.max = row.max end
        if row.minLength ~= nil then inputProps.minLength = row.minLength end
        if row.maxLength ~= nil then inputProps.maxLength = row.maxLength end
        if row.required ~= nil then inputProps.required = row.required end
        if row.placeholder then inputProps.placeholder = row.placeholder end

        if next(inputProps) then
            options.inputProps = inputProps
        end

        if row.default ~= nil and options.value == nil then
            options.value = row.default
        end

        normalized[i] = {
            id = row.id or ('field_' .. i),
            label = row.label,
            type = inputType,
            options = options,
        }
    end

    return normalized
end

function lib.inputDialog(heading, rows, options)
    if inputPromise then return end

    inputPromise = promise.new()

    local inputs = normalizeRows(rows)

    local callbackEvent = ('input:result:%s:%d'):format(GetCurrentResourceName(), GetGameTimer())

    local resultHandler = AddEventHandler(callbackEvent, function(values)
        if inputPromise then
            local p = inputPromise
            inputPromise = nil

            local result = {}
            for i = 1, #inputs do
                local id = inputs[i].id
                result[i] = values and values[id] or nil
            end

            p:resolve(result)
        end
    end)

    local closedHandler = AddEventHandler('Input:Closed', function(closedEvent)
        if closedEvent == callbackEvent and inputPromise then
            local p = inputPromise
            inputPromise = nil
            p:resolve(nil)
        end
    end)

    exports['pulsar-hud']:InputShow(heading, heading, inputs, callbackEvent, options or {})

    local result = Citizen.Await(inputPromise)

    RemoveEventHandler(resultHandler)
    RemoveEventHandler(closedHandler)

    return result
end

function lib.closeInputDialog()
    if not inputPromise then return end

    exports['pulsar-hud']:InputClose()

    local p = inputPromise
    inputPromise = nil
    p:resolve(nil)
end