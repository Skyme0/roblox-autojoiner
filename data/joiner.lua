-- Notasnek Joiner (Floating Button Only) — Simple auto-joiner
local PROVIDER = "Notasnek"
local SERVICE = "Notasnek Joiner"

-- Services
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")

-- ===== Simple logging =====
local function log(s) print("[Notasnek] " .. tostring(s)) end

-- ===== Queue =====
local queue, pumping = {}, false
local function pushMessage(item) table.insert(queue, item) end
local function pumpQueue(processJob)
    if pumping then return end
    pumping = true
    task.spawn(function()
        while #queue > 0 do
            local item = table.remove(queue, 1)
            if item.kind == "job" then
                processJob(item.id)
                RunService.Heartbeat:Wait()
                RunService.Heartbeat:Wait()
            elseif item.kind == "script" then
                item.func()
                RunService.Heartbeat:Wait()
            end
        end
        pumping = false
    end)
end

-- ===== Strict resolver for Chilli Hub Premium UI =====
local ROOT_NAME = "Steal a Brainot - Chilli Hub Premium"
local _RESOLVED_LOCK = false
local _JOB_TB, _JOIN_BTN, _SERVER = nil, nil, nil

local function isAlive(inst)
    return typeof(inst) == "Instance" and inst.Parent ~= nil and inst:IsDescendantOf(game)
end

local function resolveOnce()
    if _RESOLVED_LOCK then
        if _JOB_TB and _JOIN_BTN and isAlive(_JOB_TB) and isAlive(_JOIN_BTN) then
            return true
        else
            log("locked bindings destroyed - not rescanning")
            return false
        end
    end

    local root = CoreGui:FindFirstChild(ROOT_NAME)
    if not root then
        _RESOLVED_LOCK = true
        log("root ScreenGui not found: " .. ROOT_NAME)
        return false
    end

    -- TextBox path
    local okTB, tb = pcall(function()
        return root.MainFrame.ContentContainer.TabContent_Server.Input.TextBox
    end)
    -- Join button path
    local okJB, jb = pcall(function()
        local container = root.MainFrame.ContentContainer.TabContent_Server
        local fifth = container:GetChildren()[5]
        if not fifth then return nil end
        return fifth:FindFirstChild("ImageButton")
            or fifth:FindFirstChildOfClass("ImageButton")
            or (fifth.ClassName == "ImageButton" and fifth or nil)
    end)

    if not okTB or not tb or not tb:IsA("TextBox") then
        _RESOLVED_LOCK = true
        log("no textbox at fixed path")
        return false
    end
    if not okJB or not jb or (jb.ClassName ~= "ImageButton" and not jb:IsA("TextButton")) then
        _RESOLVED_LOCK = true
        log("no join button at fixed path")
        return false
    end

    _JOB_TB = tb
    _JOIN_BTN = jb
    _SERVER = root.MainFrame.ContentContainer.TabContent_Server
    _RESOLVED_LOCK = true

    log("UI elements bound successfully")
    return true
end

local function getUI()
    if resolveOnce() then return _JOB_TB, _JOIN_BTN, _SERVER end
    return nil
end

-- ===== Actions: type + click =====
local function pressEnter()
    pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game) end)
    pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game) end)
    pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.KeypadEnter, false, game) end)
    pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.KeypadEnter, false, game) end)
end

local function setJobIDText(jobId)
    local tb, _, server = getUI()
    if not tb then
        log("Job-ID textbox not found!")
        return nil
    end

    pcall(function()
        tb.ClearTextOnFocus = false
        tb.TextEditable = true
        tb:CaptureFocus()
    end)
    tb.Text = tostring(jobId)
    pressEnter()
    pcall(function() tb:ReleaseFocus() end)

    if server then
        local val = server:FindFirstChild("Value")
        if val and (val:IsA("StringValue") or val:IsA("ObjectValue") or val:IsA("NumberValue")) then
            pcall(function() val.Value = tostring(jobId) end)
        end
    end

    return tb
end

local function clickJoin()
    local _, btn = getUI()
    if not btn then
        log("Join button not found!")
        return false
    end

    local fired = false
    pcall(function() if btn.Activate then btn:Activate() fired = true end end)

    if typeof(getconnections) == "function" then
        local ok1, ups = pcall(getconnections, btn.MouseButton1Up)
        if ok1 and ups then
            for _, c in ipairs(ups) do pcall(function() c:Fire() end); fired = true end
        end
        local ok2, clicks = pcall(getconnections, btn.MouseButton1Click)
        if ok2 and clicks then
            for _, c in ipairs(clicks) do pcall(function() c:Fire() end); fired = true end
        end
    end

    if not fired then
        pcall(function() btn.MouseButton1Click:Fire() end)
        pcall(function() btn.MouseButton1Up:Fire() end)
        pcall(function() btn:Activate() end)
    end

    return true
end

-- ===== Message handling =====
local function bypassJob(jobId)
    local tb = setJobIDText(jobId)
    if not tb then return end
    RunService.Heartbeat:Wait()
    local success = pcall(clickJoin)
    if not success then
        log("Server full or failed to join")
    end
end

local function justJoin(script)
    local func, err = loadstring(script)
    if func then
        local ok, result = pcall(func)
        if not ok then
            log("Error while executing script: " .. result)
        end
    else
        log("Some unexpected error: " .. err)
    end
end

local function handleIncomingMessage(msg)
    if type(msg) ~= "string" then return end
    
    -- New message handling like the second script
    if not string.find(msg, "TeleportService") then
        log("Bypassing 10m server: " .. msg)
        pushMessage({kind = "job", id = msg})
    else
        log("Running the script: " .. msg)
        pushMessage({kind = "script", func = function() justJoin(msg) end})
    end
end

-- ===== Floating Button =====
local function createFloatingButton()
    local Gui = Instance.new("ScreenGui")
    Gui.Name = "NotasnekJoiner"
    Gui.ResetOnSpawn = false
    Gui.Parent = CoreGui

    -- Start Button
    local StartBtn = Instance.new("TextButton")
    StartBtn.Name = "StartButton"
    StartBtn.Size = UDim2.new(0, 200, 0, 40)
    StartBtn.AnchorPoint = Vector2.new(0.5, 0)
    StartBtn.Position = UDim2.new(0.5, 0, 0.07, 0)
    StartBtn.BackgroundColor3 = Color3.fromRGB(44, 42, 54)
    StartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    StartBtn.Text = "Notasnek (OFF)"
    StartBtn.TextSize = 18
    StartBtn.AutoButtonColor = true
    StartBtn.Parent = Gui
    Instance.new("UICorner", StartBtn).CornerRadius = UDim.new(0, 10)

    -- UI Status Label
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "UIStatus"
    StatusLabel.Size = UDim2.new(0, 200, 0, 25)
    StatusLabel.AnchorPoint = Vector2.new(0.5, 0)
    StatusLabel.Position = UDim2.new(0.5, 0, 0.12, 0)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    StatusLabel.TextSize = 14
    StatusLabel.Text = "Checking UI..."
    StatusLabel.Parent = Gui

    -- Function to update UI status
    local function updateUIStatus()
        local tb, btn = getUI()
        if tb and btn then
            StatusLabel.Text = "UI Status: Found ✓"
            StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        else
            StatusLabel.Text = "UI Status: Not Found ✗"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        end
    end

    -- Update UI status periodically
    local statusCheckThread
    local function startStatusChecking()
        if statusCheckThread then return end
        statusCheckThread = task.spawn(function()
            while Gui.Parent do
                updateUIStatus()
                task.wait(2) -- Check every 2 seconds
            end
        end)
    end

    -- Runtime + websocket
    local running, connectThread = false, nil
    local function getWebSocketConnect()
        if rawget(getfenv() or {}, "WebSocket") and WebSocket.connect then return WebSocket.connect end
        if rawget(getfenv() or {}, "WebSocket") and WebSocket.Connect then return WebSocket.Connect end
        if typeof(syn) == "table" and syn.websocket and syn.websocket.connect then return syn.websocket.connect end
        if typeof(WebSocket) == "table" and WebSocket.connect then return WebSocket.connect end
        return nil
    end

    local function startAutoJoiner()
        if running then return end
        running = true
        StartBtn.Text = "Start Notasnek (ON)"
        connectThread = task.spawn(function()
            repeat RunService.Heartbeat:Wait() until game:IsLoaded()
            local URL = "ws://127.0.0.1:51948"
            local connect = getWebSocketConnect()
            if not connect then
                log("No WebSocket support")
                return
            end
            local backoff = 1
            while running do
                local ok, socket = pcall(connect, URL)
                if ok and socket then
                    socket.OnMessage:Connect(function(m)
                        handleIncomingMessage(m)
                        pumpQueue(function(jobId) bypassJob(jobId) end)
                    end)
                    local closed = false
                    socket.OnClose:Connect(function() closed = true end)
                    while socket and not closed and running do
                        RunService.Heartbeat:Wait()
                    end
                    backoff = 1
                else
                    for _ = 1, math.max(1, math.floor((backoff or 1) * 60)) do
                        RunService.Heartbeat:Wait()
                    end
                    backoff = math.clamp((backoff or 1) * 2, 1, 10)
                end
            end
        end)
    end

    local function stopAutoJoiner()
        if not running then return end
        running = false
        StartBtn.Text = "Start Notasnek (OFF)"
        if connectThread then
            task.cancel(connectThread)
            connectThread = nil
        end
    end

    StartBtn.MouseButton1Click:Connect(function()
        if StartBtn.Text:find("(OFF)", 1, true) then
            startAutoJoiner()
        else
            stopAutoJoiner()
        end
    end)

    -- Start status checking
    startStatusChecking()

    -- Close with Delete key
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.Delete then
            stopAutoJoiner()
            if statusCheckThread then
                task.cancel(statusCheckThread)
            end
            Gui:Destroy()
        end
    end)
end

-- ===== Launch =====
local function beginApp()
    createFloatingButton()
end

if game:IsLoaded() then
    beginApp()
else
    game.Loaded:Once(beginApp)
end
