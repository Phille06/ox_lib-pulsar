--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---@type promise?
local skillcheck

---@alias SkillCheckDifficulity 'easy' | 'medium' | 'hard' | { areaSize: number, speedMultiplier: number }

local difficultyMap = {
    easy   = { rate = 1.5, size = 12 },
    medium = { rate = 2.5, size = 8 },
    hard   = { rate = 4.0, size = 6 },
}

local isActive = false

---@param difficulty SkillCheckDifficulity | SkillCheckDifficulity[]
---@param inputs string[]?
---@return boolean?
function lib.skillCheck(difficulty, inputs)
    if isActive then return end

    if type(difficulty) == "table" and difficulty[1] then
        for i = 1, #difficulty do
            local result = lib.skillCheck(difficulty[i], inputs)
            if not result then return false end
        end
        return true
    end

    local rate, size

    if type(difficulty) == "string" then
        local preset = difficultyMap[difficulty] or difficultyMap.medium
        rate = preset.rate
        size = preset.size
    elseif type(difficulty) == "table" then
        size = difficulty.areaSize or 25
        rate = difficulty.speedMultiplier or 2.5
    else
        rate = 2.5
        size = 25
    end

    local p = promise:new()
    isActive = true

    exports['pulsar-games']:MinigamePlayRoundSkillbar(
        rate,
        size,
        {
            onSuccess = function()
                isActive = false
                p:resolve(true)
            end,
            onFail = function()
                isActive = false
                p:resolve(false)
            end,
        },
        {
            animation = false,
        }
    )

    return Citizen.Await(p)
end

function lib.cancelSkillCheck()
    if not isActive then
        error('No skillCheck is active')
    end
    exports["norr-base"]:FetchComponent("Minigame"):Cancel()
    isActive = false
end

function lib.skillCheckActive()
    return isActive
end