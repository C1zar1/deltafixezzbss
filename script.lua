local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "EzzBss",
    LoadingTitle = "EzzBss",
    LoadingSubtitle = "by Solvibe & Memzad Prime",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {Enabled = false}
})

local home = Window:CreateTab("Home", 127099021069839)
local alt = Window:CreateTab("Alt", 95949997618327)
local config = Window:CreateTab("Config", 102970103256222)

local Services = {
    Players = game:GetService("Players"),
    TeleportService = game:GetService("TeleportService"),
    HttpService = game:GetService("HttpService"),
    GuiService = game:GetService("GuiService"),
    RunService = game:GetService("RunService")
}

local player = Services.Players.LocalPlayer
local userId = player.UserId

local State = {
    targetPlayerName = "",
    isTargetEnabled = false,
    reconnectTime = 18000, -- 5h
    endTime = 0,
    timerRunning = false,
    selectedConfig = nil
}

local Elements = {}
local timerConnection = nil

local function rejoin()
    Services.TeleportService:Teleport(game.PlaceId, player)
end

local function startTimer()
    State.endTime = os.time() + State.reconnectTime
    State.timerRunning = true
    if timerConnection then timerConnection:Disconnect() end
    timerConnection = Services.RunService.Heartbeat:Connect(function()
        if os.time() >= State.endTime then
            rejoin()
        end
    end)
end

local function stopTimer()
    State.timerRunning = false
    if timerConnection then
        timerConnection:Disconnect()
        timerConnection = nil
    end
end

-- Error handler
Services.GuiService.ErrorMessageChanged:Connect(function(msg)
    if msg and msg ~= "" then
        task.wait(0.1)
        rejoin()
    end
end)

-- Slider (no Flag)
Elements.Slider = home:CreateSlider({
    Name = "Restart Time",
    Range = {1, 24},
    Increment = 1,
    Suffix = "Hours",
    CurrentValue = 5,
    Callback = function(Value)
        State.reconnectTime = Value * 3600
        if State.timerRunning then startTimer() end
        SaveConfig()
    end
})

-- Target dropdown (no Flag)
Elements.DropdownTarget = alt:CreateDropdown({
    Name = "Target Player",
    Options = {},
    CurrentOption = "---",
    Callback = function(Options)
        State.targetPlayerName = Options[1] or ""
        SaveConfig()
    end
})

Elements.ToggleTarget = alt:CreateToggle({
    Name = "Target Player",
    CurrentValue = false,
    Callback = function(Value)
        State.isTargetEnabled = Value
        SaveConfig()
    end
})

-- Player updates
local debounce = false
local function updatePlayers()
    if debounce then return end
    debounce = true
    task.wait(0.1)
    local names = {}
    for _, p in Services.Players:GetPlayers() do
        if p ~= player then
            table.insert(names, p.Name)
        end
    end
    Elements.DropdownTarget:Refresh(names, true)
    debounce = false
end

updatePlayers()
Services.Players.PlayerAdded:Connect(updatePlayers)
Services.Players.PlayerRemoving:Connect(function(removed)
    updatePlayers()
    if State.isTargetEnabled and removed.Name == State.targetPlayerName then
        task.wait(0.5)
        rejoin()
    end
end)

-- Config folder
local configFolder = "EzzBss"
if not isfolder(configFolder) then makefolder(configFolder) end

local lastUsedFile = configFolder .. "\\last_" .. userId .. ".txt"

local function listConfigs()
    local files = {}
    local listed = listfiles(configFolder)
    for _, path in listed do
        if path:match("%.rfld$") then
            local name = path:match("([^/\\]+)%.rfld$")
            if name then files[#files+1] = name end
        end
    end
    table.sort(files)
    return files
end

local function getNextPreset()
    local maxNum = 0
    for _, name in listConfigs() do
        local num = tonumber(name:match("^Preset (%d+)$"))
        if num and num > maxNum then maxNum = num end
    end
    return "Preset " .. (maxNum + 1)
end

local function saveLastUsed(name)
    pcall(writefile, lastUsedFile, name or "")
end

local function loadLastUsed()
    local content = pcall(readfile, lastUsedFile)
    return type(content) == "string" and content:match("^%s*(.-)%s*$") or nil
end

local function getConfigData()
    return {
        time = State.reconnectTime / 3600,
        target = State.targetPlayerName,
        targetEnabled = State.isTargetEnabled
    }
end

function SaveConfig()
    if not State.selectedConfig then return end
    local path = configFolder .. "\\" .. State.selectedConfig .. ".rfld"
    pcall(writefile, path, Services.HttpService:JSONEncode(getConfigData()))
end

-- Config dropdown (no Flag)
Elements.DropdownConfig = config:CreateDropdown({
    Name = "Preset",
    Options = listConfigs(),
    CurrentOption = "---",
    Callback = function(Options)
        State.selectedConfig = Options[1] or nil
        saveLastUsed(State.selectedConfig)
    end
})

config:CreateButton({
    Name = "New Preset",
    Callback = function()
        local name = getNextPreset()
        local path = configFolder .. "\\" .. name .. ".rfld"
        pcall(writefile, path, Services.HttpService:JSONEncode(getConfigData()))
        local files = listConfigs()
        Elements.DropdownConfig:Refresh(files, true)
        Elements.DropdownConfig:Set({name})
        State.selectedConfig = name
        saveLastUsed(name)
    end
})

config:CreateButton({
    Name = "Load Preset",
    Callback = function()
        LoadConfig(State.selectedConfig)
    end
})

function LoadConfig(name)
    if not name then return end
    local path = configFolder .. "\\" .. name .. ".rfld"
    if not isfile(path) then return end
    
    local success, json = pcall(readfile, path)
    if success then
        local ok, data = pcall(Services.HttpService.JSONDecode, Services.HttpService, json)
        if ok then
            State.selectedConfig = name
            Elements.DropdownConfig:Set({name})
            saveLastUsed(name)
            
            if data.time then
                Elements.Slider:Set(data.time)
                State.reconnectTime = data.time * 3600
            end
            if data.target then
                Elements.DropdownTarget:Set({data.target})
                State.targetPlayerName = data.target
            end
            if data.targetEnabled ~= nil then
                Elements.ToggleTarget:Set(data.targetEnabled)
                State.isTargetEnabled = data.targetEnabled
            end
            
            if State.timerRunning then startTimer() end
            return
        end
    end
    -- Fallback
    Rayfield:Notify({Title = "Error", Content = "Failed to load " .. name, Duration = 3})
end

-- Auto-init
local configs = listConfigs()
if #configs > 0 then
    Elements.DropdownConfig:Refresh(configs, true)
    local last = loadLastUsed()
    if last and table.find(configs, last) then
        LoadConfig(last)
    else
        Elements.DropdownConfig:Set({configs[1]})
        State.selectedConfig = configs[1]
    end
end

-- Start timer
startTimer()
