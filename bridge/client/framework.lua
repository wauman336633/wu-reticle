Bridge = Bridge or {}
Bridge.Framework = Bridge.Framework or {}

local fwObject = nil
local playerLoadedCallbacks = {}
local jobUpdateCallbacks = {}

---フレームワークオブジェクトを遅延取得する
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

---QBCore / Qbox の PlayerData を統一形式に変換
local function normalizeQBPlayerData(pd)
    if not pd or not next(pd) then return nil end
    local charinfo = pd.charinfo or {}
    local fullName = pd.name or 'Unknown'
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
        identifier = pd.citizenid or tostring(GetPlayerServerId(PlayerId())),
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
end

---ESX の PlayerData を統一形式に変換
local function normalizeESXPlayerData(pd)
    if not pd or not next(pd) then return nil end
    local job = pd.job or {}
    local cash, bank = 0, 0
    if type(pd.accounts) == 'table' then
        for _, acc in ipairs(pd.accounts) do
            if acc.name == 'money' or acc.name == 'cash' then
                cash = tonumber(acc.money) or 0
            elseif acc.name == 'bank' then
                bank = tonumber(acc.money) or 0
            end
        end
    end

    return {
        identifier = pd.identifier or tostring(GetPlayerServerId(PlayerId())),
        name = ('%s %s'):format(pd.firstName or '', pd.lastName or ''):gsub('^%s*(.-)%s*$', '%1'),
        job = {
            name = job.name or 'unemployed',
            label = job.label or 'Unemployed',
            grade = tonumber(job.grade) or 0,
            onduty = true,
        },
        money = {
            cash = cash,
            bank = bank,
        },
    }
end

---Standalone のデフォルト PlayerData
local function getStandalonePlayerData()
    local serverId = GetPlayerServerId(PlayerId())
    return {
        identifier = ('standalone:%s'):format(serverId),
        name = GetPlayerName(PlayerId()) or ('Player %d'):format(serverId),
        job = {
            name = 'unemployed',
            label = 'Unemployed',
            grade = 0,
            onduty = true,
        },
        money = {
            cash = 0,
            bank = 0,
        },
    }
end

---クライアント側のプレイヤーデータを正規化形式で取得する
---@return table playerData `{ identifier, name, job = { name, label, grade, onduty }, money = { cash, bank } }`
function Bridge.Framework.GetPlayerData()
    local fw = Bridge.FrameworkName or 'standalone'

    if fw == 'qbx' and Bridge.ResourceState('qbx_core') then
        local ok, pd = pcall(function()
            return exports.qbx_core:GetPlayerData()
        end)
        if ok and pd then
            return normalizeQBPlayerData(pd) or getStandalonePlayerData()
        end
    elseif fw == 'qb' then
        local core = getFrameworkObject()
        if core and core.Functions and core.Functions.GetPlayerData then
            local pd = core.Functions.GetPlayerData()
            return normalizeQBPlayerData(pd) or getStandalonePlayerData()
        end
    elseif fw == 'esx' then
        local esx = getFrameworkObject()
        if esx and esx.GetPlayerData then
            local pd = esx.GetPlayerData()
            return normalizeESXPlayerData(pd) or getStandalonePlayerData()
        end
    end

    return getStandalonePlayerData()
end

---指定したジョブおよび最低グレード条件を満たしているか判定する
---@param jobName string|string[] ジョブ名またはジョブ名配列
---@param minGrade? number 最低グレード（省略時 0）
---@return boolean
function Bridge.Framework.HasJob(jobName, minGrade)
    if not jobName then return true end
    minGrade = tonumber(minGrade) or 0

    local pData = Bridge.Framework.GetPlayerData()
    local currentJob = pData and pData.job
    if not currentJob then return false end

    if type(jobName) == 'table' then
        for _, name in ipairs(jobName) do
            if currentJob.name == name and (currentJob.grade or 0) >= minGrade then
                return true
            end
        end
        return false
    end

    return currentJob.name == jobName and (currentJob.grade or 0) >= minGrade
end

---プレイヤーロード時のコールバックを登録する
---@param cb fun(playerData: table)
function Bridge.Framework.OnPlayerLoaded(cb)
    if type(cb) ~= 'function' then return end
    playerLoadedCallbacks[#playerLoadedCallbacks + 1] = cb
end

---ジョブ変更時のコールバックを登録する
---@param cb fun(jobData: table)
function Bridge.Framework.OnJobUpdate(cb)
    if type(cb) ~= 'function' then return end
    jobUpdateCallbacks[#jobUpdateCallbacks + 1] = cb
end

local function notifyPlayerLoaded()
    local data = Bridge.Framework.GetPlayerData()
    for i = 1, #playerLoadedCallbacks do
        pcall(playerLoadedCallbacks[i], data)
    end
end

local function notifyJobUpdate()
    local data = Bridge.Framework.GetPlayerData()
    local job = data and data.job
    for i = 1, #jobUpdateCallbacks do
        pcall(jobUpdateCallbacks[i], job)
    end
end

-- 各フレームワークのイベントリスナー統合
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    notifyPlayerLoaded()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    notifyJobUpdate()
end)

RegisterNetEvent('esx:playerLoaded', function()
    Wait(500)
    notifyPlayerLoaded()
end)

RegisterNetEvent('esx:setJob', function()
    Wait(100)
    notifyJobUpdate()
end)

-- Standalone またはリソース再起動時に既にスポーン済みの場合のハンドリング
AddEventHandler('playerSpawned', function()
    if Bridge.FrameworkName == 'standalone' then
        notifyPlayerLoaded()
    end
end)
