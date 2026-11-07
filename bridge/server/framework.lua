Bridge = Bridge or {}
Bridge.Framework = Bridge.Framework or {}

local cachedCore = nil

local function getFrameworkObject()
    if cachedCore then return cachedCore end
    local fw = Bridge.FrameworkName

    if fw == 'qb' and Bridge.ResourceState('qb-core') then
        local ok, obj = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok and obj then
            cachedCore = obj
            return cachedCore
        end
    elseif fw == 'esx' and Bridge.ResourceState('es_extended') then
        local ok, obj = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and obj then
            cachedCore = obj
            return cachedCore
        end
    end
    return nil
end

---プレイヤーオブジェクトを取得する
---@param source number
---@return table|nil
function Bridge.Framework.GetPlayer(source)
    source = tonumber(source)
    if not source or source <= 0 then return nil end

    local fw = Bridge.FrameworkName
    if fw == 'qbx' and Bridge.ResourceState('qbx_core') then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(source)
        end)
        if ok and player then return player end
    end

    if fw == 'qb' then
        local core = getFrameworkObject()
        if core and core.Functions and core.Functions.GetPlayer then
            return core.Functions.GetPlayer(source)
        end
    elseif fw == 'esx' then
        local esx = getFrameworkObject()
        if esx and esx.GetPlayerFromId then
            return esx.GetPlayerFromId(source)
        end
    end
    return nil
end

---プレイヤーの一意識別子（citizenid / license 等）を取得する
---@param source number
---@return string|nil
function Bridge.Framework.GetIdentifier(source)
    source = tonumber(source)
    if not source or source <= 0 then return nil end

    local player = Bridge.Framework.GetPlayer(source)
    local fw = Bridge.FrameworkName

    if (fw == 'qb' or fw == 'qbx') and player and player.PlayerData then
        return player.PlayerData.citizenid or player.PlayerData.license
    elseif fw == 'esx' and player then
        if type(player.identifier) == 'string' then
            return player.identifier
        elseif type(player.getIdentifier) == 'function' then
            return player.getIdentifier()
        end
    end

    local license = GetPlayerIdentifierByType and GetPlayerIdentifierByType(source, 'license')
    if license and license ~= '' then return license end

    local numIds = GetNumPlayerIdentifiers(source) or 0
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id and id:find('^license:') then
            return id
        end
    end
    return ('src:%d'):format(source)
end

---プレイヤー情報（identifier / name）を統一形式で取得する
---@param source number
---@return table|nil
function Bridge.Framework.GetPlayerInfo(source)
    source = tonumber(source)
    if not source or source <= 0 then return nil end

    local identifier = Bridge.Framework.GetIdentifier(source)
    if not identifier then return nil end

    return {
        source = source,
        identifier = identifier,
        name = GetPlayerName(source) or ('Player %d'):format(source),
    }
end
