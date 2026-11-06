Bridge = Bridge or {}
Bridge.Inventory = Bridge.Inventory or {}

---Standalone KVP インベントリのキーを取得する
local function getStandaloneInvKey(source)
    local id = (Bridge.Framework and Bridge.Framework.GetIdentifier and Bridge.Framework.GetIdentifier(source)) or tostring(source)
    return ('%s:standalone_inv:%s'):format(GetCurrentResourceName(), id)
end

---Standalone KVP インベントリのテーブルを読み込む
local function loadStandaloneInv(source)
    local raw = GetResourceKvpString(getStandaloneInvKey(source))
    if not raw or raw == '' then return {} end
    local ok, decoded = pcall(json.decode, raw)
    return (ok and type(decoded) == 'table') and decoded or {}
end

---Standalone KVP インベントリのテーブルを保存する
local function saveStandaloneInv(source, invTable)
    local ok, encoded = pcall(json.encode, invTable or {})
    if ok then
        SetResourceKvp(getStandaloneInvKey(source), encoded)
    end
end

---指定アイテムの所持数を取得する
---@param source number サーバーID
---@param itemName string アイテム名
---@return number
function Bridge.Inventory.GetItemCount(source, itemName)
    source = tonumber(source)
    if not source or not itemName then return 0 end

    local invMode = Bridge.InventoryName or (Bridge.Active and Bridge.Active.Inventory) or 'standalone'

    -- 1. ox_inventory
    if invMode == 'ox' and Bridge.ResourceState('ox_inventory') then
        local ok, count = pcall(function()
            return exports.ox_inventory:Search(source, 'count', itemName)
        end)
        if ok then return tonumber(count) or 0 end
    end

    -- 2. qb-inventory / QBCore Player.Functions
    if invMode == 'qb' or Bridge.FrameworkName == 'qb' or Bridge.FrameworkName == 'qbx' then
        local player = Bridge.Framework.GetPlayer(source)
        if player and player.Functions and player.Functions.GetItemsByName then
            local items = player.Functions.GetItemsByName(itemName)
            local total = 0
            if type(items) == 'table' then
                for _, item in pairs(items) do
                    total = total + (tonumber(item.amount or item.count) or 0)
                end
            end
            return total
        elseif player and player.Functions and player.Functions.GetItemByName then
            local item = player.Functions.GetItemByName(itemName)
            return item and (tonumber(item.amount or item.count) or 0) or 0
        end
    end

    -- 3. es_extended
    if invMode == 'esx' or Bridge.FrameworkName == 'esx' then
        local player = Bridge.Framework.GetPlayer(source)
        if player and player.getInventoryItem then
            local item = player.getInventoryItem(itemName)
            return item and (tonumber(item.count) or 0) or 0
        end
    end

    -- 4. Standalone KVP fallback
    local inv = loadStandaloneInv(source)
    local entry = inv[itemName]
    return entry and (tonumber(entry.count) or 0) or 0
end

---指定数のアイテムを所持しているか判定する
---@param source number サーバーID
---@param itemName string アイテム名
---@param count? number 必要個数（省略時 1）
---@return boolean
function Bridge.Inventory.HasItem(source, itemName, count)
    count = math.max(1, tonumber(count) or 1)
    return Bridge.Inventory.GetItemCount(source, itemName) >= count
end

---プレイヤーにアイテムを付与する
---@param source number サーバーID
---@param itemName string アイテム名
---@param count? number 個数（デフォルト 1）
---@param metadata? table メタデータ/info
---@return boolean
function Bridge.Inventory.AddItem(source, itemName, count, metadata)
    source = tonumber(source)
    count = math.floor(tonumber(count) or 1)
    if not source or not itemName or count <= 0 then return false end

    local invMode = Bridge.InventoryName or (Bridge.Active and Bridge.Active.Inventory) or 'standalone'

    -- 1. ox_inventory
    if invMode == 'ox' and Bridge.ResourceState('ox_inventory') then
        local ok, success = pcall(function()
            return exports.ox_inventory:AddItem(source, itemName, count, metadata)
        end)
        if ok then return success == true end
    end

    -- 2. qb-inventory (v2 exports or Player.Functions.AddItem)
    if invMode == 'qb' or Bridge.FrameworkName == 'qb' or Bridge.FrameworkName == 'qbx' then
        if Bridge.ResourceState('qb-inventory') then
            local ok, res = pcall(function()
                return exports['qb-inventory']:AddItem(source, itemName, count, false, metadata, Bridge.ResourceName)
            end)
            if ok and res ~= nil then return res == true end
        end

        local player = Bridge.Framework.GetPlayer(source)
        if player and player.Functions and player.Functions.AddItem then
            return player.Functions.AddItem(itemName, count, false, metadata) == true
        end
    end

    -- 3. es_extended
    if invMode == 'esx' or Bridge.FrameworkName == 'esx' then
        local player = Bridge.Framework.GetPlayer(source)
        if player and player.addInventoryItem then
            player.addInventoryItem(itemName, count)
            return true
        end
    end

    -- 4. Standalone KVP fallback
    local inv = loadStandaloneInv(source)
    local current = inv[itemName] and tonumber(inv[itemName].count) or 0
    inv[itemName] = {
        name = itemName,
        count = current + count,
        metadata = metadata or (inv[itemName] and inv[itemName].metadata) or {},
    }
    saveStandaloneInv(source, inv)
    return true
end

---プレイヤーからアイテムを削除する
---@param source number サーバーID
---@param itemName string アイテム名
---@param count? number 個数（デフォルト 1）
---@param metadata? table メタデータ
---@return boolean
function Bridge.Inventory.RemoveItem(source, itemName, count, metadata)
    source = tonumber(source)
    count = math.floor(tonumber(count) or 1)
    if not source or not itemName or count <= 0 then return false end

    if not Bridge.Inventory.HasItem(source, itemName, count) then
        return false
    end

    local invMode = Bridge.InventoryName or (Bridge.Active and Bridge.Active.Inventory) or 'standalone'

    -- 1. ox_inventory
    if invMode == 'ox' and Bridge.ResourceState('ox_inventory') then
        local ok, success = pcall(function()
            return exports.ox_inventory:RemoveItem(source, itemName, count, metadata)
        end)
        if ok then return success == true end
    end

    -- 2. qb-inventory (v2 exports or Player.Functions.RemoveItem)
    if invMode == 'qb' or Bridge.FrameworkName == 'qb' or Bridge.FrameworkName == 'qbx' then
        if Bridge.ResourceState('qb-inventory') then
            local ok, res = pcall(function()
                return exports['qb-inventory']:RemoveItem(source, itemName, count, false, Bridge.ResourceName)
            end)
            if ok and res ~= nil then return res == true end
        end

        local player = Bridge.Framework.GetPlayer(source)
        if player and player.Functions and player.Functions.RemoveItem then
            return player.Functions.RemoveItem(itemName, count, false) == true
        end
    end

    -- 3. es_extended
    if invMode == 'esx' or Bridge.FrameworkName == 'esx' then
        local player = Bridge.Framework.GetPlayer(source)
        if player and player.removeInventoryItem then
            player.removeInventoryItem(itemName, count)
            return true
        end
    end

    -- 4. Standalone KVP fallback
    local inv = loadStandaloneInv(source)
    local current = inv[itemName] and tonumber(inv[itemName].count) or 0
    if current < count then return false end

    if current - count <= 0 then
        inv[itemName] = nil
    else
        inv[itemName].count = current - count
    end
    saveStandaloneInv(source, inv)
    return true
end
