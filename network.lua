return function()
    local NetModule = {}

    function NetModule.Init(is_server)
        if is_server then
            -- We dynamically load and return the Server specialist
            return require("net_server")()
        else
            -- We dynamically load and return the Client specialist
            return require(".net_client")()
        end
    end

    return NetModule
end
