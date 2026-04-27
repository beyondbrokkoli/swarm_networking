local socket = require("socket")

return function()
    local Server = { Connected = false, CommandInbox = {} }
    local tcp_server = nil
    local peer = nil

    function Server.Init()
        tcp_server = socket.bind("*", 25000)
        tcp_server:settimeout(0)
        print("[IHK-SERVER] Bound to 25000. Listening...")
    end

    function Server.Tick()
        Server.CommandInbox = {}
        if not Server.Connected then
            local client = tcp_server:accept()
            if client then
                client:settimeout(0)
                peer = client
                Server.Connected = true
                print("[IHK-SERVER] Handshake Success.")
            end
        end

        if peer then
            local data, err = peer:receive("*l")
            if data then 
                local cmd = tonumber(data)
                if cmd then table.insert(Server.CommandInbox, cmd) end
            elseif err == "closed" then
                Server.Connected = false
                peer = nil
            end
        end
    end

    function Server.SendCmd(id)
        if peer then peer:send(tostring(id) .. "\n") end
    end

    return Server
end
