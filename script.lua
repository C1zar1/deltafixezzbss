local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "EzzBss",
    LoadingTitle = "EzzBss",
    LoadingSubtitle = "by Solvibe and Memzad Prime",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {Enabled = false},
    KeySystem = false
})

local home = Window:CreateTab("Home", 127099021069839)
local alt = Window:CreateTab("Alt", 95949997618327)
local config = Window:CreateTab("Config", 102970103256222)

local Services = {
    Players = game:GetService("Players"),
    TeleportService = game:GetService("TeleportService"),
    HttpService = game:GetService("HttpService"),
    GuiService = game:GetService("GuiService")
}

local player = Services.Players.LocalPlayer
local userId = player.UserId

local State = {
    targetPlayerName = nil,
    isTargetEnabled = false,
    reconnectTime = 5 * 3600,
    endTime = 0,
    timerRunning = false,
    selectedConfig = nil,
    lastSliderValue = 5
}

local Elements = {}

-- Timer task (optimized single spawn, referenceable)
local timerTask = nil
local function startTimer()
    State.endTime = os.time() + State.reconnectTime
    State.timerRunning = true
    if timerTask then timerTask:Disconnect() end
    timerTask = game:GetService("RunService").Heartbeat:Connect(function()
        if os.time() >= State.endTime then
            Services.TeleportService:Teleport(game.PlaceId, player)
        end
    end)
end

local function stopTimer()
    State.timerRunning = false
    if timerTask then
        timerTask:Disconnect()
        timerTask = nil
    end
end

-- Error rejoin
Services.GuiService.ErrorMessageChanged:Connect(function(errorMsg)
    if errorMsg and errorMsg ~= "" then
        task.wait(0.1)
        Services.TeleportService:Teleport(game.PlaceId, player)
    end
end)

-- UI Elements
Elements.Slider = home:CreateSlider({
    Name = "Restart Time",
    Range = {1, 24},
    Increment = 1,
    Suffix = "Hours",
    CurrentValue = 5,
    Flag = "RestartTimeSlider",
    Callback = function(Value)
        State.lastSliderValue = Value
        State.reconnectTime = Value * 3600
        if State.timerRunning then
            startTimer()
        end
        SaveConfig()
    end
})

Elements.DropdownTarget = alt:CreateDropdown({
    Name = "Target Player",
    Options = {},
    CurrentOption = {""},
    Flag = "PlayerInServer",
    Callback = function(Options)
        State.targetPlayerName = Options[1]
        SaveConfig()
    end
})

Elements.ToggleTarget = alt:CreateToggle({
    Name = "Target Player",
    CurrentValue = false,
    Flag = "ToggleRestartAlt",
    Callback = function(Value)
        State.isTargetEnabled = Value
        SaveConfig()
    end
})

-- Player list update (debounced)
local playerDebounce = false
local function updatePlayerList()
    if playerDebounce then return end
    playerDebounce = true
    task.wait(0.1)
    local names = {}
    for _, p in Services.Players:GetPlayers() do
        if p ~= player then
            table.insert(names, p.Name)
        end
    end
    Elements.DropdownTarget:Refresh(names, true)
    playerDebounce = false
end

updatePlayerList()
Services.Players.PlayerAdded:Connect(updatePlayerList)
Services.Players.PlayerRemoving:Connect(function(removed)
    updatePlayerList()
    if State.isTargetEnabled and removed.Name == State.targetPlayerName then
        task.wait(0.5)
        Services.TeleportService:Teleport(game.PlaceId, player)
    end
end)

-- Config system (optimized, single folder check)
local configFolder = "EzzBss"
if not isfolder(configFolder) then makefolder(configFolder) end

local lastUsedFile = configFolder .. "\\last_used_" .. userId .. ".txt"

local function getConfigFiles()
    local files = {}
    for _, path in listfiles(configFolder) do
        if path:match("%.rfld$") then
            local name = path:match("([^/\\]+)%.rfld$")
            if name then table.insert(files, name) end
        end
    end
    table.sort(files)
    return files
end

local function getNextPreset()
    local files = getConfigFiles()
    local maxIdx = 0
    for _, name in files do
        local idx = tonumber(name:match("^Preset (%d+)$"))
        if idx and idx > maxIdx then maxIdx = idx end
    end
    return "Preset " .. (maxIdx + 1)
end

local function saveLastUsed()
    if State.selectedConfig then
        writefile(lastUsedFile, State.selectedConfig)
    end
end

local function loadLastUsed()
    if isfile(lastUsedFile) then
        return readfile(lastUsedFile):match("^%s*(.-)%s*$")
    end
end

local function getCurrentConfig()
    return {
        RestartTimeSlider = State.lastSliderValue,
        PlayerInServer = {State.targetPlayerName or ""},
        ToggleRestartAlt = State.isTargetEnabled
    }
end

function SaveConfig()
    if not State.selectedConfig then return end
    local path = configFolder .. "\\" .. State.selectedConfig .. ".rfld"
    writefile(path, Services.HttpService:JSONEncode(getCurrentConfig()))
end

Elements.DropdownConfig = config:CreateDropdown({
    Name = "Select Config",
    Options = getConfigFiles(),
    CurrentOption = {""},
    Flag = "Config",
    Callback = function(Options)
        State.selectedConfig = Options[1]
        saveLastUsed()
    end
})

config:CreateButton({
    Name = "Create Config",
    Callback = function()
        local preset = getNextPreset()
        local path = configFolder .. "\\" .. preset .. ".rfld"
        writefile(path, Services.HttpService:JSONEncode({
            RestartTimeSlider = 5,
            PlayerInServer = {""},
            ToggleRestartAlt = false
        }))
        local files = getConfigFiles()
        Elements.DropdownConfig:Refresh(files, true)
        Elements.DropdownConfig:Set({preset})
        State.selectedConfig = preset
        saveLastUsed()
        LoadConfig(preset)
    end
})

config:CreateButton({
    Name = "Apply Config",
    Callback = function()
        if State.selectedConfig then LoadConfig(State.selectedConfig) end
    end
})

function LoadConfig(name)
    local path = configFolder .. "\\" .. name .. ".rfld"
    if not isfile(path) then return end
    State.selectedConfig = name
    Elements.DropdownConfig:Set({name})
    saveLastUsed()
    local success, data = pcall(Services.HttpService.JSONDecode, Services.HttpService, readfile(path))
    if success then
        if data.RestartTimeSlider then
            Elements.Slider:Set(data.RestartTimeSlider)
            State.lastSliderValue = data.RestartTimeSlider
            State.reconnectTime = data.RestartTimeSlider * 3600
        end
        if data.PlayerInServer and data.PlayerInServer[1] then
            Elements.DropdownTarget:Set(data.PlayerInServer)
            State.targetPlayerName = data.PlayerInServer[1]
        end
        if data.ToggleRestartAlt ~= nil then
            Elements.ToggleTarget:Set(data.ToggleRestartAlt)
            State.isTargetEnabled = data.ToggleRestartAlt
        end
        if State.timerRunning then startTimer() end
        SaveConfig()
    end
end

-- Init configs
local files = getConfigFiles()
if #files == 0 then
    local preset = "Preset 1"
    writefile(configFolder .. "\\" .. preset .. ".rfld", Services.HttpService:JSONEncode({
        RestartTimeSlider = 5, PlayerInServer = {""}, ToggleRestartAlt = false
    }))
    files = getConfigFiles()
end
Elements.DropdownConfig:Refresh(files, true)

local lastUsed = loadLastUsed()
local initConfig = lastUsed and table.find(files, lastUsed) and lastUsed or files[1] or "Preset 1"
LoadConfig(initConfig)

-- Initial timer setup
startTimer()
