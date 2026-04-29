local contextMenus = {}
local openContextMenu = nil
local menuHistory = {}

local function buildListMenus(rootId)
    local menus = {}

    local function buildMenu(id)
        local data = contextMenus[id]
        if not data then return end

        local items = {}

        for k, opt in pairs(data.options or {}) do
            local item = {
                label = opt.title or ('Option %s'):format(k),
                description = opt.description,
                disabled = opt.disabled or opt.readOnly,
            }

            if opt.menu then
                item.submenu = opt.menu
            elseif opt.onSelect or opt.event or opt.serverEvent then
                item.event = '__oxlib:contextSelect'
            end

            item.data = {
                menuId = id,
                optionId = k,
                args = opt.args,
            }

            items[#items + 1] = item
        end

        menus[id == rootId and "main" or id] = {
            label = data.title,
            items = items,
        }

        for _, opt in pairs(data.options or {}) do
            if opt.menu and contextMenus[opt.menu] and not menus[opt.menu] then
                buildMenu(opt.menu)
            end
        end
    end

    buildMenu(rootId)
    return menus
end

function lib.registerContext(context)
    if type(context) == 'table' then
        if context.id then
            contextMenus[context.id] = context
        else
            for _, v in pairs(context) do
                if v and v.id then
                    contextMenus[v.id] = v
                end
            end
        end
    end
end

function lib.showContext(id)
    if not contextMenus[id] then 
        error('No context menu with id "' .. tostring(id) .. '" found.') 
    end

    openContextMenu = id
    menuHistory = { id }

    local built = buildListMenus(id)
    exports['pulsar-hud']:ListMenuShow(built)
end

function lib.hideContext()
    openContextMenu = nil
    menuHistory = {}
    exports['pulsar-hud']:ListMenuClose()
end

function lib.getOpenContextMenu()
    return openContextMenu
end

AddEventHandler('__oxlib:contextSelect', function(data)
    local menu = contextMenus[data.menuId]
    if not menu then return end

    local opt = menu.options[data.optionId]
    if not opt then return end

    exports['pulsar-hud']:ListMenuClose()
    openContextMenu = nil
    menuHistory = {}

    if opt.onSelect then opt.onSelect(data.args) end
    if opt.event then TriggerEvent(opt.event, data.args) end
    if opt.serverEvent then TriggerServerEvent(opt.serverEvent, data.args) end
end)

AddEventHandler('ListMenu:EnterSubMenu', function(submenuId)
    if not contextMenus[submenuId] then return end

    table.insert(menuHistory, submenuId)
    openContextMenu = submenuId

    local built = buildListMenus(submenuId)
    exports['pulsar-hud']:ListMenuShow(built)
end)

AddEventHandler('ListMenu:GoBack', function()
    if #menuHistory > 1 then
        table.remove(menuHistory)
        local previous = menuHistory[#menuHistory]

        openContextMenu = previous
        local built = buildListMenus(previous)
        exports['pulsar-hud']:ListMenuShow(built)
    else
        lib.hideContext()
    end
end)

AddEventHandler('ListMenu:Close', function()
    lib.hideContext()
end)