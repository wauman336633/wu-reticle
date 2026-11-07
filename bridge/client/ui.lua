Bridge = Bridge or {}
Bridge.UI = Bridge.UI or {}

---GTA V 標準のネイティブ通知を表示する（フォールバック用）
---@param message string
local function nativeNotify(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(message or ''))
    EndTextCommandThefeedPostTicker(false, true)
end

---環境に応じて最適な通知を表示する（ox_lib -> qb-core -> ESX -> Native）
---@param message string
---@param notifyType? 'info'|'inform'|'success'|'error'|'warning'
---@param duration? number
function Bridge.UI.Notify(message, notifyType, duration)
    message = tostring(message or '')
    notifyType = notifyType or 'info'
    duration = tonumber(duration) or 4000

    local uiMode = (Config and Config.UI) or Bridge.UIName or 'auto'

    if (uiMode == 'auto' or uiMode == 'ox') and Bridge.ResourceState('ox_lib') then
        local ok = pcall(function()
            exports.ox_lib:notify({
                description = message,
                type = (notifyType == 'info') and 'inform' or notifyType,
                duration = duration,
            })
        end)
        if ok then return end
    end

    if (uiMode == 'auto' or uiMode == 'qb') and Bridge.ResourceState('qb-core') then
        local qbType = (notifyType == 'info' or notifyType == 'inform') and 'primary' or notifyType
        TriggerEvent('QBCore:Notify', message, qbType, duration)
        return
    end

    if (uiMode == 'auto' or uiMode == 'esx') and Bridge.ResourceState('es_extended') then
        TriggerEvent('esx:showNotification', message, notifyType, duration)
        return
    end

    nativeNotify(message)
end
