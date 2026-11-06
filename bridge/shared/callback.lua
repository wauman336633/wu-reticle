Bridge = Bridge or {}
Bridge.Callback = Bridge.Callback or {}

local resourceName = GetCurrentResourceName()
local REQ_EVENT = ('%s:bridge:cb:req'):format(resourceName)
local RES_EVENT = ('%s:bridge:cb:res'):format(resourceName)
local DEFAULT_TIMEOUT_MS = 10000

if IsDuplicityVersion() then
    -- ============================================================================
    -- Server Side Callback Handler
    -- ============================================================================
    local registeredCallbacks = {}

    ---サーバーコールバックを登録する
    ---@param name string コールバック名
    ---@param fn fun(source: number, ...: any): any
    function Bridge.Callback.Register(name, fn)
        if type(name) ~= 'string' or type(fn) ~= 'function' then
            Bridge.Debug('Callback.Register: invalid arguments', name)
            return
        end
        registeredCallbacks[name] = fn
        Bridge.Debug('Registered Server Callback:', name)
    end

    RegisterNetEvent(REQ_EVENT, function(cbName, requestId, ...)
        local src = source
        if type(cbName) ~= 'string' or type(requestId) ~= 'number' then return end

        local handler = registeredCallbacks[cbName]
        if not handler then
            Bridge.Debug(('Unregistered callback requested by [%d]: %s'):format(src, cbName))
            TriggerClientEvent(RES_EVENT, src, requestId, nil)
            return
        end

        local args = { ... }
        CreateThread(function()
            local results = { xpcall(function()
                return handler(src, table.unpack(args))
            end, debug.traceback) }

            local ok = table.remove(results, 1)
            if not ok then
                print(('^1[%s:CallbackError]^7 (%s): %s'):format(resourceName, cbName, tostring(results[1])))
                TriggerClientEvent(RES_EVENT, src, requestId, nil)
                return
            end

            TriggerClientEvent(RES_EVENT, src, requestId, table.unpack(results))
        end)
    end)
else
    -- ============================================================================
    -- Client Side Callback Trigger / Await
    -- ============================================================================
    local pendingRequests = {}
    local requestCounter = 0

    RegisterNetEvent(RES_EVENT, function(requestId, ...)
        local entry = pendingRequests[requestId]
        if not entry then return end
        pendingRequests[requestId] = nil

        if entry.type == 'promise' then
            entry.promise:resolve({ ... })
        elseif entry.type == 'callback' and entry.cb then
            entry.cb(...)
        end
    end)

    ---非同期でサーバーコールバックを呼び出す
    ---@param name string コールバック名
    ---@param cb fun(...: any) コールバック関数
    ---@param ... any サーバーへ渡す引数
    function Bridge.Callback.Trigger(name, cb, ...)
        requestCounter = (requestCounter % 1000000) + 1
        local reqId = requestCounter

        pendingRequests[reqId] = {
            type = 'callback',
            cb = cb,
        }

        SetTimeout(DEFAULT_TIMEOUT_MS, function()
            if pendingRequests[reqId] then
                pendingRequests[reqId] = nil
                Bridge.Debug(('Callback.Trigger timed out (%dms): %s'):format(DEFAULT_TIMEOUT_MS, name))
                if cb then cb(nil) end
            end
        end)

        TriggerServerEvent(REQ_EVENT, name, reqId, ...)
    end

    ---同期的にサーバーコールバックを呼び出し結果を待つ（Promise + Citizen.Await）
    ---@param name string コールバック名
    ---@param ... any サーバーへ渡す引数
    ---@return any ...
    function Bridge.Callback.Await(name, ...)
        requestCounter = (requestCounter % 1000000) + 1
        local reqId = requestCounter
        local p = promise.new()

        pendingRequests[reqId] = {
            type = 'promise',
            promise = p,
        }

        SetTimeout(DEFAULT_TIMEOUT_MS, function()
            if pendingRequests[reqId] then
                pendingRequests[reqId] = nil
                Bridge.Debug(('Callback.Await timed out (%dms): %s'):format(DEFAULT_TIMEOUT_MS, name))
                p:resolve({ nil })
            end
        end)

        TriggerServerEvent(REQ_EVENT, name, reqId, ...)

        local result = Citizen.Await(p)
        if type(result) == 'table' then
            return table.unpack(result)
        end
        return nil
    end
end
