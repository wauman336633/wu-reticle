Bridge = Bridge or {}
Bridge.Storage = Bridge.Storage or {}

local resourceName = GetCurrentResourceName()
local sqlTableInitialized = false

---KVPキーにリソース名またはServerConfig.StoragePrefixプレフィックスを付与する
---@param key string
---@return string
local function formatKvpKey(key)
    local prefix = (ServerConfig and ServerConfig.StoragePrefix) or resourceName
    return ('%s:kvp:%s'):format(prefix, tostring(key))
end

-- ============================================================================
-- 1. FiveM 内蔵 KVP ドライバ（外部DB一切不要）
-- ============================================================================

---Server KVPから値を取得する（JSON自動デコード対応）
---@param key string キー名
---@param defaultVal? any 未存在時のデフォルト値
---@return any
function Bridge.Storage.GetKvp(key, defaultVal)
    local fullKey = formatKvpKey(key)
    local raw = GetResourceKvpString(fullKey)
    if raw == nil or raw == '' then
        return defaultVal
    end

    local ok, decoded = pcall(json.decode, raw)
    if ok and decoded ~= nil then
        if type(decoded) == 'table' and decoded.__bridge_primitive ~= nil then
            return decoded.__bridge_primitive
        end
        return decoded
    end
    return raw
end

---Server KVPに値を保存する（テーブル・プリミティブのJSON自動エンコード対応）
---@param key string キー名
---@param value any 保存する値
---@return boolean
function Bridge.Storage.SetKvp(key, value)
    if value == nil then
        Bridge.Storage.DeleteKvp(key)
        return true
    end

    local fullKey = formatKvpKey(key)
    local payload = value
    if type(value) ~= 'table' then
        payload = { __bridge_primitive = value }
    end

    local ok, encoded = pcall(json.encode, payload)
    if not ok then
        Bridge.Debug('Storage.SetKvp: json.encode failed for key', key)
        return false
    end

    SetResourceKvp(fullKey, encoded)
    return true
end

---Server KVPからキーを削除する
---@param key string キー名
function Bridge.Storage.DeleteKvp(key)
    DeleteResourceKvp(formatKvpKey(key))
end

-- ============================================================================
-- 2. MySQL ドライバ（fxmanifestでの @oxmysql 参照不要・exports.oxmysql + Promise ラップ）
-- ============================================================================

---oxmysqlが利用可能か判定する
---@return boolean
function Bridge.Storage.IsSQLAvailable()
    return Bridge.ResourceState('oxmysql')
end

---exports.oxmysql の非同期メソッドを promise.new() で同期ラップして呼び出す内部ヘルパー
---@param method string 'query'|'single'|'scalar'|'insert'|'update'
---@param sql string SQL文
---@param params? table パラメータ
---@return any
local function callOxMySQL(method, sql, params)
    if not Bridge.Storage.IsSQLAvailable() then
        Bridge.Debug(('Storage.%s skipped: oxmysql is not running'):format(method))
        return nil
    end

    local p = promise.new()
    local ok, err = pcall(function()
        exports.oxmysql[method](exports.oxmysql, sql, params or {}, function(result)
            p:resolve(result)
        end)
    end)

    if not ok then
        print(('^1[%s:SQL Error]^7 (%s): %s'):format(resourceName, method, tostring(err)))
        p:resolve(nil)
    end

    return Citizen.Await(p)
end

---テーブルが存在しない場合に自動作成する（オートマイグレーション用）
---@param createTableSQL string CREATE TABLE IF NOT EXISTS 文
---@return boolean
function Bridge.Storage.EnsureTable(createTableSQL)
    if not Bridge.Storage.IsSQLAvailable() then return false end
    local res = callOxMySQL('query', createTableSQL, {})
    return res ~= nil
end

---複数行クエリを実行する
---@param sql string
---@param params? table
---@return table|nil
function Bridge.Storage.Query(sql, params)
    return callOxMySQL('query', sql, params)
end

---単一行クエリを実行する
---@param sql string
---@param params? table
---@return table|nil
function Bridge.Storage.Single(sql, params)
    return callOxMySQL('single', sql, params)
end

---単一スカラー値を取得する
---@param sql string
---@param params? table
---@return any
function Bridge.Storage.Scalar(sql, params)
    return callOxMySQL('scalar', sql, params)
end

---INSERT文を実行し insertId を取得する
---@param sql string
---@param params? table
---@return number|nil
function Bridge.Storage.Insert(sql, params)
    return callOxMySQL('insert', sql, params)
end

---UPDATE/DELETE文を実行し affectedRows を取得する
---@param sql string
---@param params? table
---@return number|nil
function Bridge.Storage.Update(sql, params)
    return callOxMySQL('update', sql, params)
end

-- ============================================================================
-- 3. 統一プレイヤーデータ永続化 API（Config.Storage に応じて SQL / KVP 自動切替）
-- ============================================================================

---SQLモード選択時、手動の .sql インポート無しで汎用 `mod_storage` テーブルを自動生成する
local function ensureDefaultStorageTable()
    if sqlTableInitialized then return true end
    if not Bridge.Storage.IsSQLAvailable() then return false end

    local ok = Bridge.Storage.EnsureTable([[
        CREATE TABLE IF NOT EXISTS `mod_storage` (
            `resource` VARCHAR(64) NOT NULL,
            `identifier` VARCHAR(128) NOT NULL,
            `data_key` VARCHAR(128) NOT NULL,
            `data_value` LONGTEXT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`resource`, `identifier`, `data_key`),
            INDEX `idx_identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    if ok then
        sqlTableInitialized = true
        Bridge.Debug('Auto-migrated SQL table `mod_storage` successfully.')
    end
    return ok
end

---現在有効なストレージモード（'mysql' または 'kvp'）を判定する
local function getActiveStorageMode()
    local mode = (Config and Config.Storage) or Bridge.StorageName or 'auto'
    if mode == 'auto' or mode == 'sql' or mode == 'mysql' then
        if Bridge.Storage.IsSQLAvailable() then
            return 'mysql'
        end
    end
    return 'kvp'
end

---プレイヤー別の保存データを取得する（SQL / KVP 透過対応）
---@param identifier string プレイヤー識別子（citizenid / license 等）
---@param key string データキー
---@param defaultVal? any 未保存時のデフォルト値
---@return any
function Bridge.Storage.GetPlayerData(identifier, key, defaultVal)
    if not identifier or not key then return defaultVal end

    if getActiveStorageMode() == 'mysql' and ensureDefaultStorageTable() then
        local raw = Bridge.Storage.Scalar(
            'SELECT `data_value` FROM `mod_storage` WHERE `resource` = ? AND `identifier` = ? AND `data_key` = ? LIMIT 1',
            { resourceName, tostring(identifier), tostring(key) }
        )
        if raw == nil then
            return defaultVal
        end
        local ok, decoded = pcall(json.decode, raw)
        if ok and decoded ~= nil then
            if type(decoded) == 'table' and decoded.__bridge_primitive ~= nil then
                return decoded.__bridge_primitive
            end
            return decoded
        end
        return raw
    end

    -- KVP fallback
    return Bridge.Storage.GetKvp(('player:%s:%s'):format(identifier, key), defaultVal)
end

---プレイヤー別のデータを保存する（SQL / KVP 透過対応）
---@param identifier string プレイヤー識別子
---@param key string データキー
---@param value any 保存するデータ
---@return boolean
function Bridge.Storage.SetPlayerData(identifier, key, value)
    if not identifier or not key then return false end

    if getActiveStorageMode() == 'mysql' and ensureDefaultStorageTable() then
        if value == nil then
            Bridge.Storage.Update(
                'DELETE FROM `mod_storage` WHERE `resource` = ? AND `identifier` = ? AND `data_key` = ?',
                { resourceName, tostring(identifier), tostring(key) }
            )
            return true
        end

        local payload = value
        if type(value) ~= 'table' then
            payload = { __bridge_primitive = value }
        end

        local ok, encoded = pcall(json.encode, payload)
        if not ok then return false end

        local res = Bridge.Storage.Update(
            [[
                INSERT INTO `mod_storage` (`resource`, `identifier`, `data_key`, `data_value`)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE `data_value` = VALUES(`data_value`)
            ]],
            { resourceName, tostring(identifier), tostring(key), encoded }
        )
        return res ~= nil
    end

    -- KVP fallback
    return Bridge.Storage.SetKvp(('player:%s:%s'):format(identifier, key), value)
end

-- リソース起動時にSQLが有効なら自動でテーブルを準備
CreateThread(function()
    Wait(100)
    if getActiveStorageMode() == 'mysql' and (not ServerConfig or ServerConfig.AutoMigrateSQL ~= false) then
        ensureDefaultStorageTable()
    end
end)
