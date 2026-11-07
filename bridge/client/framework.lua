Bridge = Bridge or {}
Bridge.Framework = Bridge.Framework or {}

function Bridge.Framework.IsPlayerLoaded()
    return LocalPlayer and LocalPlayer.state and LocalPlayer.state.isLoggedIn ~= false or true
end
