fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'wu-reticle'
author 'wu'
description 'Custom Parametric & Multi-Layer Reticle Builder with Share Codes'
version '1.0.0'

-- 注意: 特定リソース未導入環境での起動クラッシュを防ぐため、
-- '@qb-core/...', '@ox_lib/...', '@oxmysql/...' 等の外部ファイル参照は一切記述しないこと。
-- 外部リソース連携はすべて bridge/ 内部で GetResourceState() と exports を用いて動的に解決します。

shared_scripts {
    'config/shared.lua',
    'locales/init.lua',
    'locales/*.lua',
    'bridge/init.lua',
    'bridge/shared/*.lua',
}

client_scripts {
    'bridge/client/*.lua',
    'config/hooks.lua',
    'client/*.lua',
}

server_scripts {
    'config/server.lua',
    'bridge/server/*.lua',
    'config/hooks.lua',
    'server/*.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}
