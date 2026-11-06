Locales = Locales or {}

local FALLBACK_LOCALE = 'en'

--- 現在の設定言語コードを返す
--- @return string
local function getActiveLocale()
    local lang = (Config and Config.Locale) or GetConvar('qb_locale', 'ja')
    if Locales[lang] then
        return lang
    end
    return FALLBACK_LOCALE
end

--- 指定キーの翻訳文字列を取得し、%{var} プレースホルダを置換する
--- @param key string 翻訳キー
--- @param subs table? 置換変数のテーブル（例: { amount = 500 }）
--- @return string
function L(key, subs)
    if not key then return '' end

    local activeLang = getActiveLocale()
    local dict = Locales[activeLang] or {}
    local fallbackDict = Locales[FALLBACK_LOCALE] or {}

    local text = dict[key] or fallbackDict[key] or key

    if type(subs) == 'table' then
        text = text:gsub('%%{([%w_]+)}', function(varName)
            local val = subs[varName]
            return val ~= nil and tostring(val) or ('%{' .. varName .. '}')
        end)
    end

    return text
end

--- NUIへの一括注入用に、フォールバック言語とマージ済みの現在の言語辞書テーブル一式を返す
--- @return table<string, string>
function GetLocaleTable()
    local merged = {}
    local fallbackDict = Locales[FALLBACK_LOCALE] or {}
    for k, v in pairs(fallbackDict) do
        merged[k] = v
    end

    local activeLang = getActiveLocale()
    local activeDict = Locales[activeLang] or {}
    for k, v in pairs(activeDict) do
        merged[k] = v
    end

    return merged
end
