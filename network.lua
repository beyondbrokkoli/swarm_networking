local socket = require("socket")

return function()
    local NetModule = {}
    
    local server = nil
    local client = nil
    local peer = nil -- This will hold the active connection line

    NetModule.IsServer = false
    NetModule.Connected = false
    NetModule.CommandInbox = {}

    function NetModule.Init(is_server)
        NetModule.IsServer = is_server
        if is_server then
            -- 1. Bind the TCP Server to port 25000
            server = socket.bind("*", 25000)
            server:settimeout(0) -- CRITICAL: Make it non-blocking so it doesn't freeze the game!
            print("[NET-TCP] IHK Server listening on Port 25000...")
        else
            -- 2. Create a TCP Client and connect
            client = socket.tcp()
            client:settimeout(0) -- CRITICAL: Non-blocking
            client:connect("127.0.0.1", 25000)
            peer = client
            print("[NET-TCP] Client attempting to connect to 127.0.0.1:25000...")
        end
    end

    function NetModule.Tick()
        NetModule.CommandInbox = {}

        -- If we are the Server, we have to actively check if anyone is knocking on the door
        if NetModule.IsServer and not NetModule.Connected then
            local new_client = server:accept()
            if new_client then
                new_client:settimeout(0)
                peer = new_client
                NetModule.Connected = true
                print("[NET-TCP] Handshake Complete: Client Connected!")
            end
        end

        -- If we have an active connection (Peer), read the stream!
        if peer then
            -- Read the stream until we hit a newline ("*l" means line)
            local data, err = peer:receive("*l")
            
            if data then
                if not NetModule.Connected then
                    NetModule.Connected = true
                    print("[NET-TCP] Connection Confirmed!")
                end
                
                print("<<< [RECEIVED PING]: " .. data)
                
                local cmd = tonumber(data)
                if cmd then table.insert(NetModule.CommandInbox, cmd) end
                
            elseif err == "closed" then
                NetModule.Connected = false
                peer = nil
                print("[NET-TCP] Peer disconnected.")
            end
        end
    end

    function NetModule.SendCmd(cmd_id)
        if peer then
            -- We MUST append "\n" to tell the other side the message is over!
            local payload = tostring(cmd_id) .. "\n"
            local success, err = peer:send(payload)
            
            if success then
                print(">>> [SENT PING]: " .. cmd_id)
            end
        end
    end

    return NetModule
end
