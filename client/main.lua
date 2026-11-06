local isEditorOpen = false
local isNuiReady = false
local lastHudVisible = nil

local KVP_STORAGE_KEY = 'wu_reticle:profile_v1'

-- クライアント保持ステート
local clientProfile = {
    activeCode = (Config and Config.DefaultShareCode)
        or 'RT1:n=Default Cyan;d=1,c,3,00ffcc,100,1,1,000000,80;i=1,0,6,2,3,0,00ffcc,100,1,1,000000,80,0',
    displayMode = (Config and Config.DefaultDisplayMode) or 'aim_only',
    hideOnScope = (Config and Config.DefaultHideOnScope ~= false),
    showInFirstPerson = (Config and Config.DefaultShowInFirstPerson ~= false),
    presets = {},
    updatedAt = 0,
}

---サーバー設定（Config.AllowedDisplayModes）に照らして有効な表示モードを返す
---@param requestedMode? string
---@return string
local function resolveAllowedDisplayMode(requestedMode)
    local allowed = (Config and Config.AllowedDisplayModes) or {
        aim_only = true,
        armed = true,
        always = true,
        off = true,
    }

    local mode = type(requestedMode) == 'string' and requestedMode or clientProfile.displayMode
    if allowed[mode] then
        return mode
    end

    local defaultMode = (Config and Config.DefaultDisplayMode) or 'aim_only'
    if allowed[defaultMode] then
        return defaultMode
    end

    for _, fallback in ipairs({ 'aim_only', 'armed', 'always', 'off' }) do
        if allowed[fallback] then
            return fallback
        end
    end

    return 'aim_only'
end

---Config.UITheme を NUI 側が受け取れる正規化テーブルに整形する
---@return table
local function buildThemePayload()
    local theme = Config and Config.UITheme or {}
    return {
        primaryColor = theme.primaryColor or '#10b981',
        accentColor = theme.accentColor or '#3b82f6',
        bgOpacity = theme.backgroundOpacity or theme.bgOpacity or '0.94',
        borderRadius = theme.borderRadius or '12px',
        position = theme.position or 'right',
    }
end

---クライアントKVPから保存済みプロファイルを読み込む（サーバー通信ゼロで即座に復元）
---@return boolean loaded
local function loadFromClientKvp()
    local raw = GetResourceKvpString(KVP_STORAGE_KEY)
    if not raw or raw == '' then
        clientProfile.displayMode = resolveAllowedDisplayMode(clientProfile.displayMode)
        return false
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        clientProfile.displayMode = resolveAllowedDisplayMode(clientProfile.displayMode)
        return false
    end

    if type(decoded.activeCode) == 'string' and decoded.activeCode:sub(1, 4) == 'RT1:' then
        clientProfile.activeCode = decoded.activeCode
    end
    clientProfile.displayMode = resolveAllowedDisplayMode(decoded.displayMode)
    if type(decoded.hideOnScope) == 'boolean' then
        clientProfile.hideOnScope = decoded.hideOnScope
    end
    if type(decoded.showInFirstPerson) == 'boolean' then
        clientProfile.showInFirstPerson = decoded.showInFirstPerson
    end
    if type(decoded.presets) == 'table' then
        clientProfile.presets = decoded.presets
    end
    clientProfile.updatedAt = tonumber(decoded.updatedAt) or 0
    return true
end

---クライアントKVPへプロファイルを保存し、非同期でサーバーStorageにもバックアップする
---@param syncToServer? boolean
local function saveProfile(syncToServer)
    clientProfile.displayMode = resolveAllowedDisplayMode(clientProfile.displayMode)
    clientProfile.updatedAt = GetCloudTimeAsInt()

    local ok, encoded = pcall(json.encode, clientProfile)
    if ok and encoded then
        SetResourceKvp(KVP_STORAGE_KEY, encoded)
    end

    if syncToServer ~= false then
        CreateThread(function()
            Bridge.Callback.Await('wu-reticle:saveServerData', {
                activeCode = clientProfile.activeCode,
                displayMode = clientProfile.displayMode,
                hideOnScope = clientProfile.hideOnScope,
                showInFirstPerson = clientProfile.showInFirstPerson,
                presets = clientProfile.presets,
            })
        end)
    end
end

---NUI側へ最新プロファイル・設定一式を同期する
local function pushProfileToNui()
    if not isNuiReady then return end
    SendNUIMessage({
        action = 'SYNC_PROFILE',
        theme = buildThemePayload(),
        locales = GetLocaleTable(),
        config = {
            allowedDisplayModes = (Config and Config.AllowedDisplayModes) or {
                aim_only = true,
                armed = true,
                always = true,
                off = true,
            },
            maxPlayerPresets = (Config and tonumber(Config.MaxPlayerPresets)) or 20,
            maxCustomLayers = (Config and tonumber(Config.MaxCustomLayers)) or 6,
            defaultShareCode = (Config and Config.DefaultShareCode) or clientProfile.activeCode,
            builtInPresets = (Config and Config.BuiltInPresets) or {},
        },
        profile = clientProfile,
    })
end

---サーバー側Storageとハイブリッド同期を行う（クライアントKVPが空ならサーバーから復元、逆ならサーバーへバックアップ）
local function syncWithServerStorage()
    local hadLocalKvp = loadFromClientKvp()
    pushProfileToNui()

    local res = Bridge.Callback.Await('wu-reticle:getServerData')
    if not res or not res.ok then
        return
    end

    local srv = res.profile
    if type(srv) == 'table' and type(srv.activeCode) == 'string' then
        local srvUpdated = tonumber(srv.updatedAt) or 0
        -- クライアントKVPが未作成、またはサーバー側のデータが新しい場合はサーバーデータを取り込む
        if (not hadLocalKvp) or (srvUpdated > clientProfile.updatedAt and #clientProfile.presets == 0) then
            clientProfile.activeCode = srv.activeCode
            clientProfile.displayMode = resolveAllowedDisplayMode(srv.displayMode)
            if type(srv.hideOnScope) == 'boolean' then
                clientProfile.hideOnScope = srv.hideOnScope
            end
            if type(srv.showInFirstPerson) == 'boolean' then
                clientProfile.showInFirstPerson = srv.showInFirstPerson
            end
            if type(srv.presets) == 'table' then
                clientProfile.presets = srv.presets
            end
            clientProfile.updatedAt = srvUpdated
            saveProfile(false)
            pushProfileToNui()
        end
    elseif hadLocalKvp then
        -- クライアントKVPにデータがありサーバー側が未保存ならサーバーへバックアップ
        saveProfile(true)
    end
end

---FiveM Native の戻り値（boolean または 1/0）を確実に boolean へ変換する
---@param val any
---@return boolean
local function isTruthy(val)
    return val == true or val == 1
end

---現在装備中の武器が銃器・射撃武器かどうかを判定する
---@param ped number
---@param weaponHash number
---@return boolean
local function checkIsArmed(ped, weaponHash)
    if isTruthy(IsPedArmed(ped, 4)) or isTruthy(IsPedArmed(ped, 6)) then
        return true
    end
    if not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        return false
    end
    local group = GetWeapontypeGroup(weaponHash)
    if group == `GROUP_UNARMED` or group == `GROUP_MELEE` then
        return false
    end
    return true
end

---現在プレイヤーがエイム（ADS / 構え）状態かどうかを判定する
---@param playerId number
---@param ped number
---@param isArmed boolean
---@return boolean
local function checkIsAiming(playerId, ped, isArmed)
    if isTruthy(IsPlayerFreeAiming(playerId))
        or isTruthy(IsAimCamActive())
        or isTruthy(IsAimCamThirdPersonActive())
    then
        return true
    end

    -- 銃器装備中（または車内ドライブバイ可能時）にエイム入力（右クリック / INPUT_AIM: 25）を押している場合もカバー
    if isArmed or IsPedInAnyVehicle(ped, false) then
        if isTruthy(IsControlPressed(0, 25)) or isTruthy(IsDisabledControlPressed(0, 25)) then
            return true
        end
    end

    return false
end

---現在のゲームプレイ状態からHUDレティクルを表示すべきか判定する
---@param ped number
---@param weaponHash number
---@param isArmed boolean
---@param isAiming boolean
---@return boolean
local function evaluateShouldShowReticle(ped, weaponHash, isArmed, isAiming)
    -- エディタが開いている最中は実画面プレビューとして常時表示
    if isEditorOpen then
        return true
    end

    local mode = resolveAllowedDisplayMode(clientProfile.displayMode)
    if mode == 'off' then
        return false
    end

    -- ポーズメニュー（ESC）、画面フェードアウト、他リソースのNUI操作中は自動で隠す
    if isTruthy(IsPauseMenuActive()) or isTruthy(IsScreenFadedOut()) or isTruthy(IsNuiFocused()) then
        return false
    end

    if isTruthy(IsPedDeadOrDying(ped, true)) then
        return false
    end

    -- 車両乗車中判定
    if isTruthy(IsPedInAnyVehicle(ped, false)) and (Config and Config.AllowVehicleDriveby == false) then
        return false
    end

    -- スナイパースコープ等のフルスクリーンスコープ覗き込み中
    if clientProfile.hideOnScope and isTruthy(IsFirstPersonAimCamActive()) then
        local isSniper = weaponHash and (GetWeapontypeGroup(weaponHash) == `GROUP_SNIPER`)
        if GetFollowPedCamViewMode() ~= 4 or isSniper then
            return false
        end
    end

    -- 一人称視点（FPS）エイム時の表示設定チェック
    if not clientProfile.showInFirstPerson and isAiming and GetFollowPedCamViewMode() == 4 then
        return false
    end

    -- 表示モード別の判定
    local visibleByMode = false
    if mode == 'always' then
        visibleByMode = true
    elseif mode == 'armed' then
        visibleByMode = isArmed or isAiming
    elseif mode == 'aim_only' then
        visibleByMode = isAiming
    end

    if not visibleByMode then
        return false
    end

    if Hooks and Hooks.ShouldShowReticle then
        local hookAllowed = Hooks.ShouldShowReticle(ped, weaponHash, mode)
        if not hookAllowed then
            return false
        end
    end

    return true
end

---NUI側へHUD表示・非表示状態の変化のみを送信する（差分送信で負荷ゼロ）
---@param visible boolean
local function updateHudVisibility(visible)
    if not isNuiReady then return end
    if lastHudVisible == visible then return end
    lastHudVisible = visible
    SendNUIMessage({
        action = 'SET_HUD_VISIBLE',
        visible = visible,
    })
end

---レティクルエディタを開く
local function openReticleEditor()
    if isEditorOpen then return end

    if Hooks and Hooks.OnOpenUI and not Hooks.OnOpenUI() then
        Bridge.UI.Notify(L('error_cannot_interact'), 'error')
        return
    end

    clientProfile.displayMode = resolveAllowedDisplayMode(clientProfile.displayMode)
    isEditorOpen = true
    SetNuiFocus(true, true)
    -- エディタ操作中もカメラや背景を見やすく保つ
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        action = 'OPEN_EDITOR',
        theme = buildThemePayload(),
        locales = GetLocaleTable(),
        config = {
            allowedDisplayModes = (Config and Config.AllowedDisplayModes) or {
                aim_only = true,
                armed = true,
                always = true,
                off = true,
            },
            maxPlayerPresets = (Config and tonumber(Config.MaxPlayerPresets)) or 20,
            maxCustomLayers = (Config and tonumber(Config.MaxCustomLayers)) or 6,
            defaultShareCode = (Config and Config.DefaultShareCode) or clientProfile.activeCode,
            builtInPresets = (Config and Config.BuiltInPresets) or {},
        },
        profile = clientProfile,
    })

    updateHudVisibility(true)
end

---レティクルエディタを閉じる
local function closeReticleEditor()
    if not isEditorOpen then return end
    isEditorOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'CLOSE_EDITOR' })
    -- 閉じた直後に現在の表示モードに従った表示状態へ戻す
    lastHudVisible = nil
end

-- ============================================================================
-- NUI Callbacks
-- ============================================================================

RegisterNUICallback('ready', function(_, cb)
    isNuiReady = true
    loadFromClientKvp()
    pushProfileToNui()
    cb({ ok = true })
end)

RegisterNUICallback('close', function(body, cb)
    if type(body) == 'table' and type(body.profile) == 'table' then
        local p = body.profile
        if type(p.activeCode) == 'string' and p.activeCode:sub(1, 4) == 'RT1:' then
            clientProfile.activeCode = p.activeCode
        end
        clientProfile.displayMode = resolveAllowedDisplayMode(p.displayMode)
        if type(p.hideOnScope) == 'boolean' then
            clientProfile.hideOnScope = p.hideOnScope
        end
        if type(p.showInFirstPerson) == 'boolean' then
            clientProfile.showInFirstPerson = p.showInFirstPerson
        end
        if type(p.presets) == 'table' then
            clientProfile.presets = p.presets
        end
        saveProfile(true)
    end

    isEditorOpen = false
    SetNuiFocus(false, false)
    lastHudVisible = nil
    cb({ ok = true })
end)

RegisterNUICallback('saveProfile', function(body, cb)
    if type(body) == 'table' then
        if type(body.activeCode) == 'string' and body.activeCode:sub(1, 4) == 'RT1:' then
            clientProfile.activeCode = body.activeCode
        end
        if body.displayMode ~= nil then
            clientProfile.displayMode = resolveAllowedDisplayMode(body.displayMode)
        end
        if type(body.hideOnScope) == 'boolean' then
            clientProfile.hideOnScope = body.hideOnScope
        end
        if type(body.showInFirstPerson) == 'boolean' then
            clientProfile.showInFirstPerson = body.showInFirstPerson
        end
        if type(body.presets) == 'table' then
            clientProfile.presets = body.presets
        end

        saveProfile(body.syncServer ~= false)
        lastHudVisible = nil
        if body.notify and body.notifyMessage then
            Bridge.UI.Notify(tostring(body.notifyMessage), body.notifyType or 'success')
        end
    end

    cb({
        ok = true,
        profile = clientProfile,
    })
end)

RegisterNUICallback('notify', function(body, cb)
    if type(body) == 'table' and body.message then
        Bridge.UI.Notify(tostring(body.message), body.type or 'info')
    end
    cb({ ok = true })
end)

-- ============================================================================
-- 監視スレッド（非武装時は低頻度ポーリング、武装時のみフレーム制御を行う省電力設計）
-- ============================================================================

CreateThread(function()
    Wait(500)
    syncWithServerStorage()

    local playerId = PlayerId()
    local hideVanilla = (Config and Config.HideVanillaReticle ~= false)

    while true do
        local ped = PlayerPedId()
        local weaponHash = GetSelectedPedWeapon(ped)
        local isArmed = checkIsArmed(ped, weaponHash)
        local isAiming = checkIsAiming(playerId, ped, isArmed)

        local shouldShow = evaluateShouldShowReticle(ped, weaponHash, isArmed, isAiming)
        updateHudVisibility(shouldShow)

        if isArmed or isAiming then
            if hideVanilla then
                -- 純正レティクル（HUD Component 14）を抑制
                HideHudComponentThisFrame(14)
                Wait(0)
            else
                Wait(30)
            end
        else
            -- 非武装時は100msスリープでCPU負荷 0.00ms を維持
            Wait(100)
        end
    end
end)

-- ============================================================================
-- コマンド・キーバインド・Exports・イベント連携
-- ============================================================================

CreateThread(function()
    local commands = (Config and Config.Commands) or { 'reticle' }
    if type(commands) == 'string' then
        commands = { commands }
    end

    for i = 1, #commands do
        local cmd = commands[i]
        if type(cmd) == 'string' and cmd ~= '' then
            RegisterCommand(cmd, function()
                if isEditorOpen then
                    closeReticleEditor()
                else
                    openReticleEditor()
                end
            end, false)
        end
    end

    local keybind = Config and Config.Keybind or ''
    if type(keybind) == 'string' and keybind ~= '' and commands[1] then
        RegisterKeyMapping(commands[1], L('ui_title'), 'keyboard', keybind)
    end
end)

RegisterNetEvent('wu-reticle:client:openEditor', function()
    openReticleEditor()
end)

RegisterNetEvent('wu-reticle:client:closeEditor', function()
    closeReticleEditor()
end)

-- 他リソース連携用 Exports
exports('OpenEditor', openReticleEditor)
exports('CloseEditor', closeReticleEditor)
exports('GetActiveShareCode', function()
    return clientProfile.activeCode
end)
exports('SetShareCode', function(shareCode)
    if type(shareCode) ~= 'string' or shareCode:sub(1, 4) ~= 'RT1:' then
        return false
    end
    clientProfile.activeCode = shareCode
    saveProfile(true)
    pushProfileToNui()
    return true
end)
exports('SetDisplayMode', function(mode)
    clientProfile.displayMode = resolveAllowedDisplayMode(mode)
    saveProfile(true)
    pushProfileToNui()
    lastHudVisible = nil
    return clientProfile.displayMode
end)

-- リソース停止時のクリーンアップ
AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    if isEditorOpen then
        SetNuiFocus(false, false)
    end
end)
