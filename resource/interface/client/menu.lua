--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---@type { [string]: MenuProps }
local registeredMenus = {}
---@type MenuProps | nil
local openMenu

---@alias MenuPosition 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right'
---@alias MenuChangeFunction fun(selected: number, scrollIndex?: number, args?: any, checked?: boolean)
---@alias MenuScrollSelectChangeFunction fun(selected: number, scrollIndex?: number, args?: any)

---@class MenuOptions
---@field label string
---@field progress? number
---@field colorScheme? string
---@field icon? string | {[1]: IconProp, [2]: string};
---@field iconColor? string
---@field values? table<string | { label: string, description: string }>
---@field checked? boolean
---@field description? string
---@field defaultIndex? number
---@field args? {[any]: any}
---@field close? boolean

---@class MenuProps
---@field id string
---@field title string
---@field options MenuOptions[]
---@field position? MenuPosition
---@field disableInput? boolean
---@field canClose? boolean
---@field onClose? fun(keyPressed?: 'Escape' | 'Backspace')
---@field onSelected? MenuScrollSelectChangeFunction
---@field onSideScroll? MenuScrollSelectChangeFunction
---@field onCheck? fun(selected: number, checked: boolean, args?: any)
---@field cb? MenuChangeFunction

---@param data MenuProps
---@param cb? MenuChangeFunction
local registeredMenus = {}
local openMenu = nil

local function convertOptions(options, cb)
    local items = {}
    for i, opt in ipairs(options) do
        items[#items + 1] = {
            label = opt.label,
            description = opt.description,
            disabled = opt.disabled,
            event = opt.args and opt.args.event or nil,
            data = opt.args,
            -- store index so we can fire cb
            _index = i,
            _cb = cb,
        }
    end
    return items
end

function lib.registerMenu(data, cb)
    if not data.id then error('No menu id was provided.') end
    if not data.title then error('No menu title was provided.') end
    if not data.options then error('No menu options were provided.') end
    data.cb = cb
    registeredMenus[data.id] = data
end

function lib.showMenu(id, startIndex)
    local menu = registeredMenus[id]
    if not menu then
        error(('No menu with id %s was found'):format(id))
    end

    openMenu = menu

    -- Build ListMenu format: single 'main' submenu
    local menus = {
        main = {
            label = menu.title,
            items = {}
        }
    }

    for i, opt in ipairs(menu.options) do
        menus.main.items[#menus.main.items + 1] = {
            label = opt.label,
            description = opt.description,
            disabled = opt.disabled,
            -- We use a synthetic event to pipe selection back through cb
            event = '__oxlib:menuSelect',
            data = { menuId = id, index = i, args = opt.args, scrollIndex = opt.defaultIndex }
        }
    end

    exports['pulsar-hud']:ListMenuShow(menus)
end

function lib.hideMenu(onExit)
    local menu = openMenu
    openMenu = nil

    if not menu then return end

    exports['pulsar-hud']:ListMenuClose()

    if onExit and menu.onClose then
        menu.onClose()
    end
end

function lib.getOpenMenu()
    return openMenu and openMenu.id
end

function lib.setMenuOptions(id, options, index)
    if index then
        registeredMenus[id].options[index] = options
    else
        if not options[1] then error('Invalid override format used, expected table of options.') end
        registeredMenus[id].options = options
    end
end

AddEventHandler('__oxlib:menuSelect', function(data)
    local menu = registeredMenus[data.menuId]
    if not menu or not menu.cb then return end
    menu.cb(data.index, data.scrollIndex, data.args)
end)