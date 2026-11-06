Bridge = Bridge or {}
Bridge.UI = Bridge.UI or {}

local isNativeTextUIShowing = false
local currentNativeText = ''

---通知を表示する（ox_lib -> qb-core -> esx -> GTA V Native）
---@param message string 通知メッセージ
---@param notifyType? 'inform'|'info'|'success'|'error'|'warning' 通知タイプ
---@param duration? number 表示ミリ秒（デフォルト 5000）
function Bridge.UI.Notify(message, notifyType, duration)
    message = tostring(message or '')
    notifyType = notifyType or 'info'
    duration = tonumber(duration) or 5000

    local uiMode = Bridge.UIName or (Bridge.Active and Bridge.Active.UI) or 'native'

    -- 1. ox_lib
    if uiMode == 'ox' or Bridge.ResourceState('ox_lib') then
        local oxType = notifyType == 'info' and 'inform' or notifyType
        local ok = pcall(function()
            exports.ox_lib:notify({
                description = message,
                type = oxType,
                duration = duration,
            })
        end)
        if ok then return end
    end

    -- 2. qb-core
    if uiMode == 'qb' or Bridge.ResourceState('qb-core') then
        local qbType = notifyType
        if qbType == 'inform' or qbType == 'info' then qbType = 'primary' end
        TriggerEvent('QBCore:Notify', message, qbType, duration)
        return
    end

    -- 3. es_extended
    if Bridge.ResourceState('es_extended') then
        TriggerEvent('esx:showNotification', message, notifyType, duration)
        return
    end

    -- 4. GTA V Native Fallback
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, true)
end

---画面上に操作ガイド（TextUI）を表示する（ox_lib -> qb-core -> GTA V Native HelpText）
---@param text string 表示テキスト
---@param position? 'right-center'|'left-center'|'top-center' 表示位置
function Bridge.UI.ShowTextUI(text, position)
    text = tostring(text or '')
    position = position or 'left-center'

    local uiMode = Bridge.UIName or (Bridge.Active and Bridge.Active.UI) or 'native'

    -- 1. ox_lib
    if uiMode == 'ox' or Bridge.ResourceState('ox_lib') then
        local ok = pcall(function()
            exports.ox_lib:showTextUI(text, { position = position })
        end)
        if ok then return end
    end

    -- 2. qb-core DrawText
    if uiMode == 'qb' or Bridge.ResourceState('qb-core') then
        local qbPos = 'left'
        if position == 'right-center' then qbPos = 'right'
        elseif position == 'top-center' then qbPos = 'top' end
        local ok = pcall(function()
            exports['qb-core']:DrawText(text, qbPos)
        end)
        if ok then return end
    end

    -- 3. GTA V Native HelpText (軽量ループで表示維持)
    currentNativeText = text
    if not isNativeTextUIShowing then
        isNativeTextUIShowing = true
        CreateThread(function()
            while isNativeTextUIShowing do
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(currentNativeText)
                EndTextCommandDisplayHelp(0, false, true, -1)
                Wait(0)
            end
        end)
    end
end

---表示中の操作ガイド（TextUI）を非表示にする
function Bridge.UI.HideTextUI()
    isNativeTextUIShowing = false
    currentNativeText = ''

    local uiMode = Bridge.UIName or (Bridge.Active and Bridge.Active.UI) or 'native'

    if uiMode == 'ox' or Bridge.ResourceState('ox_lib') then
        local ok = pcall(function()
            exports.ox_lib:hideTextUI()
        end)
        if ok then return end
    end

    if uiMode == 'qb' or Bridge.ResourceState('qb-core') then
        local ok = pcall(function()
            exports['qb-core']:HideText()
        end)
        if ok then return end
    end
end

---プログレスバーを表示し完了まで待機する（ox_lib -> progressbar -> 内蔵タイマー＋アニメーション）
---@param opts table `{ label: string, duration: number, animDict?: string, animClip?: string, canCancel?: boolean }`
---@return boolean completed キャンセルされずに完了した場合 true
function Bridge.UI.ProgressBar(opts)
    opts = opts or {}
    local label = opts.label or 'Processing...'
    local duration = tonumber(opts.duration) or 3000
    local animDict = opts.animDict
    local animClip = opts.animClip
    local canCancel = opts.canCancel ~= false

    -- 1. ox_lib
    if Bridge.ResourceState('ox_lib') then
        local ok, res = pcall(function()
            return exports.ox_lib:progressBar({
                duration = duration,
                label = label,
                useWhileDead = false,
                canCancel = canCancel,
                disable = {
                    move = opts.disableMove or false,
                    car = opts.disableCar or false,
                    combat = opts.disableCombat ~= false,
                },
                anim = (animDict and animClip) and {
                    dict = animDict,
                    clip = animClip,
                } or nil,
            })
        end)
        if ok then return res == true end
    end

    -- 2. progressbar (QBCore standalone standard)
    if Bridge.ResourceState('progressbar') then
        local p = promise.new()
        local name = ('%s_prog_%d'):format(GetCurrentResourceName(), GetGameTimer())
        local ok = pcall(function()
            exports['progressbar']:Progress({
                name = name,
                duration = duration,
                label = label,
                useWhileDead = false,
                canCancel = canCancel,
                controlDisables = {
                    disableMovement = opts.disableMove or false,
                    disableCarMovement = opts.disableCar or false,
                    disableMouse = false,
                    disableCombat = opts.disableCombat ~= false,
                },
                animation = (animDict and animClip) and {
                    animDict = animDict,
                    anim = animClip,
                    flags = 49,
                } or {},
            }, function(cancelled)
                p:resolve(not cancelled)
            end)
        end)
        if ok then
            return Citizen.Await(p)
        end
    end

    -- 3. Built-in Fallback (Animation + Timer + Cancel Key Detection)
    local ped = PlayerPedId()
    if animDict and animClip then
        RequestAnimDict(animDict)
        local timeout = GetGameTimer() + 1000
        while not HasAnimDictLoaded(animDict) and GetGameTimer() < timeout do
            Wait(10)
        end
        if HasAnimDictLoaded(animDict) then
            TaskPlayAnim(ped, animDict, animClip, 8.0, -8.0, duration, 49, 0, false, false, false)
        end
    end

    local p = promise.new()
    CreateThread(function()
        local endTime = GetGameTimer() + duration
        local cancelled = false

        while GetGameTimer() < endTime do
            if canCancel and IsControlJustReleased(0, 73) then -- X key (INPUT_VEH_DUCK)
                cancelled = true
                break
            end
            Wait(0)
        end

        if animDict and animClip then
            StopAnimTask(ped, animDict, animClip, 1.0)
        end
        p:resolve(not cancelled)
    end)

    return Citizen.Await(p)
end

-- Server Standalone Fallback 通知受信用イベント
RegisterNetEvent(('%s:client:notify'):format(GetCurrentResourceName()), function(message, notifyType, duration)
    Bridge.UI.Notify(message, notifyType, duration)
end)

