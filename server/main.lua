local playerCooldowns = {}

---プレイヤーの保存クールダウンを確認・更新する
---@param source number
---@return boolean allowed, number remainingSeconds
local function checkCooldown(source)
    local cdSeconds = (ServerConfig and tonumber(ServerConfig.CooldownSeconds)) or 1
    if cdSeconds <= 0 then return true, 0 end

    local now = os.time()
    local nextAllowed = playerCooldowns[source] or 0
    if now < nextAllowed then
        return false, (nextAllowed - now)
    end

    playerCooldowns[source] = now + cdSeconds
    return true, 0
end

---シェアコード文字列を検証・サニタイズする
---@param code any
---@return string|nil
local function sanitizeShareCode(code)
    if type(code) ~= 'string' then return nil end
    local trimmed = code:gsub('^%s+', ''):gsub('%s+$', '')
    local maxLen = (ServerConfig and tonumber(ServerConfig.MaxShareCodeLength)) or 600
    if #trimmed < 4 or #trimmed > maxLen then
        return nil
    end
    if trimmed:sub(1, 4) ~= 'RT1:' then
        return nil
    end
    -- 制御文字やHTMLタグ文字を除去
    if trimmed:find('[<>%c]') then
        return nil
    end
    return trimmed
end

---サーバー側で許可された表示モードに正規化する
---@param mode any
---@return string
local function normalizeDisplayMode(mode)
    local allowed = (Config and Config.AllowedDisplayModes) or {
        aim_only = true,
        armed = true,
        always = true,
        off = true,
    }
    local requested = type(mode) == 'string' and mode or (Config and Config.DefaultDisplayMode) or 'aim_only'
    if allowed[requested] then
        return requested
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

---マイプリセット配列を検証・サニタイズする
---@param rawPresets any
---@return table
local function sanitizePresets(rawPresets)
    if type(rawPresets) ~= 'table' then return {} end

    local maxPresets = (ServerConfig and tonumber(ServerConfig.MaxPresets))
        or (Config and tonumber(Config.MaxPlayerPresets))
        or 20

    local sanitized = {}
    for i = 1, #rawPresets do
        if #sanitized >= maxPresets then break end
        local item = rawPresets[i]
        if type(item) == 'table' then
            local validCode = sanitizeShareCode(item.code)
            if validCode then
                local rawName = tostring(item.name or ('Preset #' .. tostring(#sanitized + 1)))
                rawName = rawName:gsub('[<>%c]', ''):sub(1, 40)
                if rawName == '' then
                    rawName = 'Preset #' .. tostring(#sanitized + 1)
                end

                local rawId = tostring(item.id or ('p_' .. tostring(i) .. '_' .. tostring(os.time())))
                rawId = rawId:gsub('[^%w_%-]', ''):sub(1, 48)

                sanitized[#sanitized + 1] = {
                    id = rawId ~= '' and rawId or ('p_' .. tostring(#sanitized + 1)),
                    name = rawName,
                    code = validCode,
                    updatedAt = tonumber(item.updatedAt) or os.time(),
                }
            end
        end
    end

    return sanitized
end

-- ============================================================================
-- Server Callbacks
-- ============================================================================

---クライアント起動・UIオープン時にサーバー保存データを取得する
Bridge.Callback.Register('wu-reticle:getServerData', function(source)
    local playerInfo = Bridge.Framework.GetPlayerInfo(source)
    if not playerInfo or not playerInfo.identifier then
        return {
            ok = false,
            error = 'error_invalid_player',
        }
    end

    local savedProfile = Bridge.Storage.GetPlayerData(playerInfo.identifier, 'reticle_profile', nil)

    return {
        ok = true,
        player = playerInfo,
        profile = savedProfile,
        framework = Bridge.FrameworkName,
        storage = (Config and Config.Storage) or Bridge.StorageName,
    }
end)

---クライアントからのレティクル設定・マイプリセット保存リクエストを処理する
Bridge.Callback.Register('wu-reticle:saveServerData', function(source, payload)
    payload = type(payload) == 'table' and payload or {}

    if Hooks and Hooks.CanExecuteAction then
        local allowed, reasonKey = Hooks.CanExecuteAction(source, 'save_reticle', payload)
        if not allowed then
            return {
                ok = false,
                message = L(reasonKey or 'error_cannot_interact'),
            }
        end
    end

    local cdOk = checkCooldown(source)
    if not cdOk then
        return {
            ok = false,
            throttled = true,
        }
    end

    local playerInfo = Bridge.Framework.GetPlayerInfo(source)
    if not playerInfo or not playerInfo.identifier then
        return {
            ok = false,
            message = L('error_invalid_player'),
        }
    end

    local defaultCode = (Config and Config.DefaultShareCode)
        or 'RT1:n=Default Cyan;d=1,c,3,00ffcc,100,1,1,000000,80;i=1,0,6,2,3,0,00ffcc,100,1,1,000000,80,0'

    local activeCode = sanitizeShareCode(payload.activeCode) or defaultCode
    local displayMode = normalizeDisplayMode(payload.displayMode)
    local hideOnScope = payload.hideOnScope ~= false
    local showInFirstPerson = payload.showInFirstPerson ~= false
    local presets = sanitizePresets(payload.presets)

    local profileToSave = {
        activeCode = activeCode,
        displayMode = displayMode,
        hideOnScope = hideOnScope,
        showInFirstPerson = showInFirstPerson,
        presets = presets,
        updatedAt = os.time(),
    }

    local saved = Bridge.Storage.SetPlayerData(playerInfo.identifier, 'reticle_profile', profileToSave)

    if saved and Hooks and Hooks.OnActionSuccess then
        pcall(Hooks.OnActionSuccess, source, 'save_reticle', {
            presetCount = #presets,
            displayMode = displayMode,
        })
    end

    return {
        ok = saved == true,
        profile = profileToSave,
        message = L('msg_saved_sync'),
    }
end)

AddEventHandler('playerDropped', function()
    local src = source
    playerCooldowns[src] = nil
end)
