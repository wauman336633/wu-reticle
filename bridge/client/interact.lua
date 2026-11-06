Bridge = Bridge or {}
Bridge.Interact = Bridge.Interact or {}

local zones = {}
local drawTextLoopRunning = false
local activeZoneId = nil

-- キー名とGTA V Control IDのマッピング（デフォルト E = 38）
local KEY_CONTROLS = {
    ['E'] = 38,
    ['G'] = 47,
    ['F'] = 23,
    ['H'] = 74,
    ['Q'] = 44,
}

---DrawTextフォールバック用の単一最適化スレッドを起動する
---遠距離待機時は Wait(1000) で resmon 0.00ms を維持し、近距離進入時のみ TextUI 表示＆キー検知を行う
local function ensureDrawTextLoop()
    if drawTextLoopRunning then return end
    drawTextLoopRunning = true

    CreateThread(function()
        while drawTextLoopRunning do
            local sleep = 1000
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)

            local nearestId = nil
            local nearestDist = 999999.0
            local nearestZone = nil

            for id, zone in pairs(zones) do
                if zone.mode == 'drawtext' and zone.coords then
                    local dist = #(pCoords - zone.coords)
                    if dist < 15.0 then
                        sleep = math.min(sleep, 250)
                    end
                    if dist <= zone.radius and dist < nearestDist then
                        local allowed = true
                        if zone.canInteract then
                            local ok, res = pcall(zone.canInteract)
                            allowed = ok and (res ~= false)
                        end
                        if allowed then
                            nearestId = id
                            nearestDist = dist
                            nearestZone = zone
                        end
                    end
                end
            end

            if nearestZone then
                sleep = 0
                if activeZoneId ~= nearestId then
                    activeZoneId = nearestId
                    local keyStr = nearestZone.key or 'E'
                    local labelStr = nearestZone.label or 'Interact'
                    local promptText
                    if type(L) == 'function' then
                        promptText = L('interact_prompt_prefix', { key = keyStr, label = labelStr })
                    else
                        promptText = ('[%s] %s'):format(keyStr, labelStr)
                    end
                    Bridge.UI.ShowTextUI(promptText, 'left-center')
                end

                local controlId = KEY_CONTROLS[nearestZone.key or 'E'] or 38
                if IsControlJustReleased(0, controlId) then
                    if nearestZone.onSelect then
                        -- 連打防止の軽いウェイトと安全な呼び出し
                        CreateThread(function()
                            pcall(nearestZone.onSelect, { id = nearestId, coords = nearestZone.coords })
                        end)
                    end
                    Wait(300)
                end
            else
                if activeZoneId ~= nil then
                    activeZoneId = nil
                    Bridge.UI.HideTextUI()
                end
            end

            -- ゾーンが1つも無ければスレッドを停止
            local hasDrawTextZones = false
            for _, z in pairs(zones) do
                if z.mode == 'drawtext' then
                    hasDrawTextZones = true
                    break
                end
            end
            if not hasDrawTextZones then
                if activeZoneId ~= nil then
                    activeZoneId = nil
                    Bridge.UI.HideTextUI()
                end
                drawTextLoopRunning = false
                break
            end

            Wait(sleep)
        end
    end)
end

---インタラクションゾーンを登録する（ox_target -> qb-target -> 0.00ms DrawText Fallback）
---@param id string ゾーンの一意識別子
---@param opts table `{ coords = vector3, radius = 2.0, size = vector3(1.5,1.5,2.0), heading = 0.0, label = '...', icon = 'fas fa-hand', key = 'E', canInteract = fn, onSelect = fn }`
function Bridge.Interact.AddZone(id, opts)
    if not id or type(opts) ~= 'table' or not opts.coords then
        Bridge.Debug('Interact.AddZone: invalid zone definition', id)
        return
    end

    -- 既存の同名ゾーンがあれば先にクリーンアップ
    if zones[id] then
        Bridge.Interact.RemoveZone(id)
    end

    local coords = vector3(opts.coords.x, opts.coords.y, opts.coords.z)
    local radius = tonumber(opts.radius) or 2.0
    local size = opts.size or vector3(1.5, 1.5, 2.0)
    local heading = tonumber(opts.heading) or 0.0
    local label = opts.label or 'Interact'
    local icon = opts.icon or 'fas fa-hand'
    local key = opts.key or 'E'
    local canInteract = opts.canInteract
    local onSelect = opts.onSelect

    local targetMode = Bridge.TargetName or (Bridge.Active and Bridge.Active.Target) or 'drawtext'

    -- 1. ox_target
    if targetMode == 'ox' and Bridge.ResourceState('ox_target') then
        local ok, oxId = pcall(function()
            return exports.ox_target:addBoxZone({
                coords = coords,
                size = size,
                rotation = heading,
                debug = Config and Config.Debug or false,
                options = {
                    {
                        name = ('%s_%s'):format(Bridge.ResourceName, id),
                        icon = icon,
                        label = label,
                        distance = radius,
                        canInteract = function(entity, distance, coords, name, bone)
                            if canInteract then
                                return canInteract(entity, distance)
                            end
                            return true
                        end,
                        onSelect = function(data)
                            if onSelect then onSelect(data) end
                        end,
                    },
                },
            })
        end)

        if ok and oxId then
            zones[id] = { mode = 'ox', targetId = oxId }
            Bridge.Debug('Registered ox_target zone:', id)
            return
        end
    end

    -- 2. qb-target (Convar UseTarget == 'true' 時、または Config.Target == 'qb' 明示指定時)
    if targetMode == 'qb' and Bridge.ResourceState('qb-target') then
        local zoneName = ('%s_zone_%s'):format(Bridge.ResourceName, id)
        local ok = pcall(function()
            exports['qb-target']:AddBoxZone(zoneName, coords, size.x, size.y, {
                name = zoneName,
                heading = heading,
                debugPoly = Config and Config.Debug or false,
                minZ = coords.z - (size.z / 2),
                maxZ = coords.z + (size.z / 2),
            }, {
                options = {
                    {
                        icon = icon,
                        label = label,
                        action = function(entity)
                            if onSelect then onSelect({ entity = entity, id = id, coords = coords }) end
                        end,
                        canInteract = function(entity, distance, data)
                            if canInteract then
                                return canInteract(entity, distance)
                            end
                            return true
                        end,
                    },
                },
                distance = radius,
            })
        end)

        if ok then
            zones[id] = { mode = 'qb', targetId = zoneName }
            Bridge.Debug('Registered qb-target zone:', id)
            return
        end
    end

    -- 3. DrawText + Distance Check Fallback (0.00ms Idle Optimized)
    zones[id] = {
        mode = 'drawtext',
        coords = coords,
        radius = radius,
        label = label,
        key = key,
        canInteract = canInteract,
        onSelect = onSelect,
    }
    Bridge.Debug('Registered drawtext fallback zone:', id)
    ensureDrawTextLoop()
end

---登録されたインタラクションゾーンを削除する
---@param id string ゾーンID
function Bridge.Interact.RemoveZone(id)
    local zone = zones[id]
    if not zone then return end

    if zone.mode == 'ox' and zone.targetId and Bridge.ResourceState('ox_target') then
        pcall(function()
            exports.ox_target:removeZone(zone.targetId)
        end)
    elseif zone.mode == 'qb' and zone.targetId and Bridge.ResourceState('qb-target') then
        pcall(function()
            exports['qb-target']:RemoveZone(zone.targetId)
        end)
    elseif zone.mode == 'drawtext' then
        if activeZoneId == id then
            activeZoneId = nil
            Bridge.UI.HideTextUI()
        end
    end

    zones[id] = nil
    Bridge.Debug('Removed interact zone:', id)
end

---全ゾーンをクリーンアップする
function Bridge.Interact.ClearAll()
    for id in pairs(zones) do
        Bridge.Interact.RemoveZone(id)
    end
    drawTextLoopRunning = false
    if activeZoneId ~= nil then
        activeZoneId = nil
        Bridge.UI.HideTextUI()
    end
end

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    Bridge.Interact.ClearAll()
end)
