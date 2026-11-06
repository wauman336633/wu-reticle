Bridge = Bridge or {}
Bridge.ResourceName = GetCurrentResourceName()
Bridge.IsServer = IsDuplicityVersion()

---指定リソースが稼働中または起動中か判定する
---@param name string リソース名
---@return boolean
function Bridge.ResourceState(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

---デバッグログ出力（Config.Debug が true の場合のみ出力）
---@param ... any
function Bridge.Debug(...)
    if not Config or not Config.Debug then return end
    local args = { ... }
    local strArgs = {}
    for i = 1, #args do
        local v = args[i]
        if type(v) == 'table' then
            local ok, encoded = pcall(json.encode, v)
            strArgs[i] = ok and encoded or tostring(v)
        else
            strArgs[i] = tostring(v)
        end
    end
    print(('^3[%s:Debug]^7 %s'):format(Bridge.ResourceName, table.concat(strArgs, ' ')))
end

---環境（Framework / Inventory / Target / UI / Storage）の自動検出
---@return table activeConfig
function Bridge.Detect()
    local cfg = Config or {}

    -- 1. Framework 自動検出
    local fw = cfg.Framework or 'auto'
    if fw == 'auto' then
        if Bridge.ResourceState('qbx_core') then
            fw = 'qbx'
        elseif Bridge.ResourceState('qb-core') then
            fw = 'qb'
        elseif Bridge.ResourceState('es_extended') then
            fw = 'esx'
        else
            fw = 'standalone'
        end
    end

    -- 2. Inventory 自動検出
    local inv = cfg.Inventory or 'auto'
    if inv == 'auto' then
        if Bridge.ResourceState('ox_inventory') then
            inv = 'ox'
        elseif Bridge.ResourceState('qb-inventory') then
            inv = 'qb'
        elseif Bridge.ResourceState('es_extended') then
            inv = 'esx'
        else
            inv = 'standalone'
        end
    end

    -- 3. Target 自動検出
    local target = cfg.Target or 'auto'
    if target == 'auto' then
        if Bridge.ResourceState('ox_target') then
            target = 'ox'
        elseif Bridge.ResourceState('qb-target') and GetConvar('UseTarget', 'false') == 'true' then
            target = 'qb'
        else
            target = 'drawtext'
        end
    end

    -- 4. UI 自動検出
    local ui = cfg.UI or 'auto'
    if ui == 'auto' then
        if Bridge.ResourceState('ox_lib') then
            ui = 'ox'
        elseif Bridge.ResourceState('qb-core') then
            ui = 'qb'
        else
            ui = 'native'
        end
    end

    -- 5. Storage 自動検出
    local storage = cfg.Storage or 'auto'
    if storage == 'auto' then
        if Bridge.ResourceState('oxmysql') then
            storage = 'mysql'
        else
            storage = 'kvp'
        end
    elseif storage == 'sql' then
        storage = 'mysql'
    end

    Bridge.Active = {
        Framework = fw,
        Inventory = inv,
        Target = target,
        UI = ui,
        Storage = storage,
    }

    Bridge.FrameworkName = fw
    Bridge.InventoryName = inv
    Bridge.TargetName = target
    Bridge.UIName = ui
    Bridge.StorageName = storage

    Bridge.Debug(
        ('Detected Environment -> Framework: %s | Inventory: %s | Target: %s | UI: %s | Storage: %s'):format(
            fw, inv, target, ui, storage
        )
    )

    return Bridge.Active
end

Bridge.Detect()
