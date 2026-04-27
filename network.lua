return function()
    local NetModule = {}

    function NetModule.Init(is_server)
        if is_server then
            -- We dynamically load and return the Server specialist
            return require("modules.net_server")()
        else
            -- We dynamically load and return the Client specialist
            return require("modules.net_client")()
        end
    end

    return NetModule
end
