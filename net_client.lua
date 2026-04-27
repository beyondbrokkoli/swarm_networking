local socket = require("socket")

return function()
    local Client = { Connected = false, CommandInbox = {} }
    local tcp_client = nil

    function Client.Init()
        tcp_client = socket.tcp()
        tcp_client:settimeout(0)
        tcp_client:connect("127.0.0.1", 25000)
        print("[IHK-CLIENT] Dialing 127.0.0.1...")
    end

    function Client.Tick()
        Client.CommandInbox = {}
        local data, err = tcp_client:receive("*l")
        if data then
            Client.Connected = true
            local cmd = tonumber(data)
            if cmd then table.insert(Client.CommandInbox, cmd) end
        elseif err == "closed" then
            Client.Connected = false
            print("[IHK-CLIENT] Server went offline.")
        end
    end

    function Client.SendCmd(id)
        tcp_client:send(tostring(id) .. "\n")
    end

    return Client
end
