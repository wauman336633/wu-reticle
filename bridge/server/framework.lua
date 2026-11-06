Bridge = Bridge or {}
Bridge.Framework = Bridge.Framework or {}

local fwObject = nil

---サーバー側フレームワークオブジェクトを遅延取得する
local function getFrameworkObject()
    if fwObject then return fwObject end
    local fw = Bridge.FrameworkName or (Bridge.Active and Bridge.Active.Framework) or 'standalone'

    if fw == 'qb' and Bridge.ResourceState('qb-core') then
        local ok, obj = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok then fwObject = obj end
    elseif fw == 'esx' and Bridge.ResourceState('es_extended') then
        local ok, obj = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok then fwObject = obj end
    end

    return fwObject
end

---Standalone用のKVP所持金キーを生成する
local function getStandaloneMoneyKey(source, moneyType)
    local id = Bridge.Framework.GetIdentifier(source) or tostring(source)
    return ('%s:standalone_money:%s:%s'):format(GetCurrentResourceName(), id, moneyType or 'cash')
end

---フレームワーク固有のPlayerオブジェクトを取得する
---@param source number プレイヤーのサーバーID
---@return table|nil
function Bridge.Framework.GetPlayer(source)
    source = tonumber(source)
    if not source or source <= 0 then return nil end

    local fw = Bridge.FrameworkName or 'standalone'

    if fw == 'qbx' and Bridge.ResourceState('qbx_core') then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(source)
        end)
        if ok then return player end
    elseif fw == 'qb' then
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

    -- Standalone fallback object
    return {
        source = source,
        standalone = true,
    }
end

---プレイヤーの一意識別子（citizenid / identifier / license）を取得する
---@param source number プレイヤーのサーバーID
---@return string|nil
function Bridge.Framework.GetIdentifier(source)
    source = tonumber(source)
    if not source or source <= 0 then return nil end

    local fw = Bridge.FrameworkName or 'standalone'
    local player = Bridge.Framework.GetPlayer(source)

    if (fw == 'qb' or fw == 'qbx') and player and player.PlayerData then
        return player.PlayerData.citizenid
    elseif fw == 'esx' and player and player.identifier then
        return player.identifier
    end

    -- Standalone: license 識別子を取得（未取得時は discord -> steam -> source フォールバック）
    if GetPlayerIdentifierByType then
        local license = GetPlayerIdentifierByType(source, 'license')
        if license then return license end
        local discord = GetPlayerIdentifierByType(source, 'discord')
        if discord then return discord end
    end

    local numIds = GetNumPlayerIdentifiers(source) or 0
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id and id:find('^license:') then
            return id
        end
    end

    return ('standalone:%d'):format(source)
end

---正規化されたプレイヤー情報を取得する
---@param source number プレイヤーのサーバーID
---@return table|nil `{ source, identifier, name, job = { name, label, grade, onduty }, money = { cash, bank } }`
function Bridge.Framework.GetPlayerInfo(source)
    source = tonumber(source)
    if not source or source <= 0 then return nil end

    local fw = Bridge.FrameworkName or 'standalone'
    local player = Bridge.Framework.GetPlayer(source)
    local identifier = Bridge.Framework.GetIdentifier(source)
    if not identifier then return nil end

    if (fw == 'qb' or fw == 'qbx') and player and player.PlayerData then
        local pd = player.PlayerData
        local charinfo = pd.charinfo or {}
        local fullName = GetPlayerName(source) or 'Unknown'
        if charinfo.firstname or charinfo.lastname then
            fullName = ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''):gsub('^%s*(.-)%s*$', '%1')
        end

        local job = pd.job or {}
        local gradeLevel = 0
        if type(job.grade) == 'table' then
            gradeLevel = tonumber(job.grade.level) or 0
        else
            gradeLevel = tonumber(job.grade) or 0
        end

        local money = pd.money or {}

        return {
            source = source,
            identifier = identifier,
            name = fullName,
            job = {
                name = job.name or 'unemployed',
                label = job.label or 'Unemployed',
                grade = gradeLevel,
                onduty = job.onduty ~= false,
            },
            money = {
                cash = tonumber(money.cash) or 0,
                bank = tonumber(money.bank) or 0,
            },
        }
    elseif fw == 'esx' and player then
        local job = (player.getJob and player.getJob()) or player.job or {}
        local name = (player.getName and player.getName()) or GetPlayerName(source) or 'Unknown'

        return {
            source = source,
            identifier = identifier,
            name = name,
            job = {
                name = job.name or 'unemployed',
                label = job.label or 'Unemployed',
                grade = tonumber(job.grade) or 0,
                onduty = true,
            },
            money = {
                cash = Bridge.Framework.GetMoney(source, 'cash'),
                bank = Bridge.Framework.GetMoney(source, 'bank'),
            },
        }
    end

    -- Standalone
    return {
        source = source,
        identifier = identifier,
        name = GetPlayerName(source) or ('Player %d'):format(source),
        job = {
            name = 'unemployed',
            label = 'Unemployed',
            grade = 0,
            onduty = true,
        },
        money = {
            cash = Bridge.Framework.GetMoney(source, 'cash'),
            bank = Bridge.Framework.GetMoney(source, 'bank'),
        },
    }
end

---所持金を取得する
---@param source number サーバーID
---@param moneyType? 'cash'|'bank' 通貨種別（デフォルト 'cash'）
---@return number
function Bridge.Framework.GetMoney(source, moneyType)
    moneyType = moneyType or 'cash'
    local fw = Bridge.FrameworkName or 'standalone'
    local player = Bridge.Framework.GetPlayer(source)

    if (fw == 'qb' or fw == 'qbx') and player then
        if player.Functions and player.Functions.GetMoney then
            return tonumber(player.Functions.GetMoney(moneyType)) or 0
        elseif player.PlayerData and player.PlayerData.money then
            return tonumber(player.PlayerData.money[moneyType]) or 0
        end
    elseif fw == 'esx' and player then
        local esxAccount = (moneyType == 'cash') and 'money' or moneyType
        if player.getAccount then
            local acc = player.getAccount(esxAccount)
            return acc and tonumber(acc.money) or 0
        end
    end

    -- Standalone: Server KVP上の仮想所持金（初期値 10000）
    local key = getStandaloneMoneyKey(source, moneyType)
    local val = GetResourceKvpInt(key)
    if val == 0 and GetResourceKvpString(key .. '_init') ~= '1' then
        SetResourceKvpInt(key, 10000)
        SetResourceKvp(key .. '_init', '1')
        return 10000
    end
    return val
end

---所持金を追加する
---@param source number サーバーID
---@param moneyType? 'cash'|'bank' 通貨種別
---@param amount number 金額
---@param reason? string 理由
---@return boolean
function Bridge.Framework.AddMoney(source, moneyType, amount, reason)
    moneyType = moneyType or 'cash'
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end

    local fw = Bridge.FrameworkName or 'standalone'
    local player = Bridge.Framework.GetPlayer(source)

    if (fw == 'qb' or fw == 'qbx') and player and player.Functions and player.Functions.AddMoney then
        return player.Functions.AddMoney(moneyType, amount, reason or Bridge.ResourceName) == true
    elseif fw == 'esx' and player then
        local esxAccount = (moneyType == 'cash') and 'money' or moneyType
        if player.addAccountMoney then
            player.addAccountMoney(esxAccount, amount, reason or Bridge.ResourceName)
            return true
        end
    end

    -- Standalone: Server KVP上の仮想所持金を更新
    local current = Bridge.Framework.GetMoney(source, moneyType)
    local key = getStandaloneMoneyKey(source, moneyType)
    SetResourceKvpInt(key, current + amount)
    SetResourceKvp(key .. '_init', '1')
    return true
end

---所持金を減算する
---@param source number サーバーID
---@param moneyType? 'cash'|'bank' 通貨種別
---@param amount number 金額
---@param reason? string 理由
---@return boolean
function Bridge.Framework.RemoveMoney(source, moneyType, amount, reason)
    moneyType = moneyType or 'cash'
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end

    local current = Bridge.Framework.GetMoney(source, moneyType)
    if current < amount then return false end

    local fw = Bridge.FrameworkName or 'standalone'
    local player = Bridge.Framework.GetPlayer(source)

    if (fw == 'qb' or fw == 'qbx') and player and player.Functions and player.Functions.RemoveMoney then
        return player.Functions.RemoveMoney(moneyType, amount, reason or Bridge.ResourceName) == true
    elseif fw == 'esx' and player then
        local esxAccount = (moneyType == 'cash') and 'money' or moneyType
        if player.removeAccountMoney then
            player.removeAccountMoney(esxAccount, amount, reason or Bridge.ResourceName)
            return true
        end
    end

    -- Standalone: Server KVP上の仮想所持金を減算
    local key = getStandaloneMoneyKey(source, moneyType)
    SetResourceKvpInt(key, current - amount)
    SetResourceKvp(key .. '_init', '1')
    return true
end

---使用可能アイテムを登録する
---@param itemName string アイテム名
---@param cb fun(source: number, item: table)
function Bridge.Framework.RegisterUsableItem(itemName, cb)
    if type(itemName) ~= 'string' or type(cb) ~= 'function' then return end
    local fw = Bridge.FrameworkName or 'standalone'

    if fw == 'qbx' and Bridge.ResourceState('qbx_core') then
        pcall(function()
            exports.qbx_core:CreateUseableItem(itemName, function(source, item)
                cb(source, item)
            end)
        end)
        return
    elseif fw == 'qb' then
        local core = getFrameworkObject()
        if core and core.Functions and core.Functions.CreateUseableItem then
            core.Functions.CreateUseableItem(itemName, function(source, item)
                cb(source, item)
            end)
            return
        end
    elseif fw == 'esx' then
        local esx = getFrameworkObject()
        if esx and esx.RegisterUsableItem then
            esx.RegisterUsableItem(itemName, function(source, _, item)
                cb(source, item or { name = itemName })
            end)
            return
        end
    end

    Bridge.Debug('RegisterUsableItem skipped (standalone mode):', itemName)
end

---サーバーから対象クライアントに通知を送信する
---@param source number サーバーID
---@param message string メッセージ
---@param notifyType? 'inform'|'info'|'success'|'error'|'warning'
---@param duration? number ミリ秒
function Bridge.Framework.Notify(source, message, notifyType, duration)
    source = tonumber(source)
    if not source or source <= 0 then return end
    message = tostring(message or '')
    notifyType = notifyType or 'info'
    duration = tonumber(duration) or 5000

    if Bridge.ResourceState('ox_lib') then
        TriggerClientEvent('ox_lib:notify', source, {
            description = message,
            type = notifyType == 'info' and 'inform' or notifyType,
            duration = duration,
        })
        return
    end

    if Bridge.ResourceState('qb-core') then
        local qbType = (notifyType == 'info' or notifyType == 'inform') and 'primary' or notifyType
        TriggerClientEvent('QBCore:Notify', source, message, qbType, duration)
        return
    end

    if Bridge.ResourceState('es_extended') then
        TriggerClientEvent('esx:showNotification', source, message, notifyType, duration)
        return
    end

    TriggerClientEvent(('%s:client:notify'):format(Bridge.ResourceName), source, message, notifyType, duration)
end
