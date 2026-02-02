local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "EzzBss",
    Icon = 0,
    LoadingTitle = "EzzBss",
    LoadingSubtitle = "by Solvibe and Memzad Prime",
    ShowText = "EzzBss",
    Theme = "Default",
    ToggleUIKeybind = "K",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = false,
        FolderName = "EzzBss",
        FileName = "Preset 1"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false,
    KeySettings = {
        Title = "Untitled",
        Subtitle = "Key System",
        Note = "No method of obtaining the key is provided",
        FileName = "Key",
        SaveKey = true,
        GrabKeyFromSite = false,
        Key = {"Hello"}
    }
})

local home   = Window:CreateTab("Home", 127099021069839)
local alt    = Window:CreateTab("Alt", 95949997618327)
local config = Window:CreateTab("Config", 102970103256222)

local Players         = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService     = game:GetService("HttpService")
local GuiService      = game:GetService("GuiService")

local player = Players.LocalPlayer
local userId = tostring(player.UserId)

local targetPlayerName = nil
local isTargetEnabled  = false

local function rejoinSelf()
    TeleportService:Teleport(game.PlaceId, player)
end

local Slider
local DropdownTargetPlayer
local ToggleTargetPlayer

Slider = home:CreateSlider({
    Name = "Restart Time",
    Range = {1, 24},
    Increment = 1,
    Suffix = "Hours",
    CurrentValue = 5,
    Flag = "RestartTimeSlider",
    Callback = function(Value) end,
})

local reconnectTime = 0
local endTime = 0
local timerRunning = false

local function restartTimerFromNow()
    if reconnectTime > 0 then
        endTime = os.time() + reconnectTime
        timerRunning = true
    else
        timerRunning = false
    end
end

task.spawn(function()
    while true do
        task.wait(1)
        if timerRunning and reconnectTime > 0 then
            local now = os.time()
            if now >= endTime then
                TeleportService:Teleport(game.PlaceId, player)
                break
            end
        end
    end
end)

local function onErrorMessageChanged(errorMessage)
    if errorMessage and errorMessage ~= "" then
        if player then
            task.wait()
            TeleportService:Teleport(game.PlaceId, player)
        end
    end
end

GuiService.ErrorMessageChanged:Connect(onErrorMessageChanged)

DropdownTargetPlayer = alt:CreateDropdown({
    Name = "TargetPlayer",
    Options = {},
    CurrentOption = {""},
    MultipleOptions = false,
    Flag = "PlayerInServer",
    Callback = function(Options) end,
})

ToggleTargetPlayer = alt:CreateToggle({
    Name = "Target Player",
    CurrentValue = false,
    Flag = "ToggleRestartAlt",
    Callback = function(Value) end,
})

local function updatePlayers()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            table.insert(names, p.Name)
        end
    end
    DropdownTargetPlayer:Refresh(names, true)
end

updatePlayers()
Players.PlayerAdded:Connect(updatePlayers)
Players.PlayerRemoving:Connect(function(removedPlayer)
    updatePlayers()
    if isTargetEnabled and removedPlayer.Name == targetPlayerName then
        task.spawn(function()
            rejoinSelf()
        end)
    end
end)

local configFolder = "EzzBss"
if not isfolder(configFolder) then
    makefolder(configFolder)
end

local function getConfigFiles()
    local files = {}
    if isfolder(configFolder) then
        for _, path in ipairs(listfiles(configFolder)) do
            if path:sub(-5) == ".rfld" then
                local name = path:match("([^/\\]+)%.rfld$") or path
                table.insert(files, name)
            end
        end
    end
    table.sort(files)
    return files
end

local function getNextPresetName()
    local maxIndex = 0
    local files = getConfigFiles()
    for _, name in ipairs(files) do
        local n = tonumber(name:match("^Preset (%d+)$"))
        if n and n > maxIndex then
            maxIndex = n
        end
    end
    return "Preset " .. (maxIndex + 1)
end

local selectedConfig = nil
local DropdownConfig

local lastSliderValue = Slider.CurrentValue or 5

local lastUsedFile = configFolder .. "\\last_used_" .. userId .. ".txt"

local function saveLastUsedPresetName()
    if selectedConfig then
        writefile(lastUsedFile, selectedConfig)
    end
end

local function loadLastUsedPresetName()
    if isfile(lastUsedFile) then
        local name = readfile(lastUsedFile)
        if name ~= "" then
            return name
        end
    end
    return nil
end

local function getCurrentConfigTable()
    return {
        RestartTimeSlider = lastSliderValue,
        PlayerInServer    = {targetPlayerName or ""},
        ToggleRestartAlt  = isTargetEnabled,
    }
end

function SaveCurrentConfig()
    if not selectedConfig then return end
    local filePath = configFolder .. "\\" .. selectedConfig .. ".rfld"
    local data = getCurrentConfigTable()
    writefile(filePath, HttpService:JSONEncode(data))
end

Slider.Callback = function(Value)
    lastSliderValue = Value
    reconnectTime = Value * 3600
    restartTimerFromNow()
    SaveCurrentConfig()
end

DropdownTargetPlayer.Callback = function(Options)
    targetPlayerName = Options[1]
    SaveCurrentConfig()
end

ToggleTargetPlayer.Callback = function(Value)
    isTargetEnabled = Value
    SaveCurrentConfig()
end

DropdownConfig = config:CreateDropdown({
    Name = "Select Config",
    Options = getConfigFiles(),
    CurrentOption = {""},
    MultipleOptions = false,
    Flag = "Config",
    Callback = function(Options)
        selectedConfig = Options[1]
        saveLastUsedPresetName()
    end,
})

local function makeDefaultConfig()
    return {
        RestartTimeSlider = 5,
        PlayerInServer    = {""},
        ToggleRestartAlt  = false,
    }
end

local ButtonConfigCreate = config:CreateButton({
    Name = "Create Config",
    Callback = function()
        local presetName = getNextPresetName()
        local filePath = configFolder .. "\\" .. presetName .. ".rfld"

        local data = makeDefaultConfig()
        writefile(filePath, HttpService:JSONEncode(data))

        local opts = getConfigFiles()
        DropdownConfig:Refresh(opts, true)
        DropdownConfig:Set({presetName})
        selectedConfig = presetName
        saveLastUsedPresetName()

        if Slider and Slider.Set then
            Slider:Set(data.RestartTimeSlider)
            lastSliderValue = data.RestartTimeSlider
        end
        if DropdownTargetPlayer and DropdownTargetPlayer.Set then
            DropdownTargetPlayer:Set(data.PlayerInServer)
            targetPlayerName = data.PlayerInServer[1] or ""
        end
        if ToggleTargetPlayer and ToggleTargetPlayer.Set then
            ToggleTargetPlayer:Set(data.ToggleRestartAlt)
            isTargetEnabled = data.ToggleRestartAlt
        end

        SaveCurrentConfig()
    end,
})

local ButtonConfig = config:CreateButton({
    Name = "Apply Config",
    Callback = function()
        if not selectedConfig then return end

        local filePath = configFolder .. "\\" .. selectedConfig .. ".rfld"
        if not isfile(filePath) then return end

        local content = readfile(filePath)
        local data = HttpService:JSONDecode(content)

        if data.RestartTimeSlider and Slider and Slider.Set then
            Slider:Set(data.RestartTimeSlider)
            lastSliderValue = data.RestartTimeSlider
        end

        if data.PlayerInServer and data.PlayerInServer[1] and DropdownTargetPlayer and DropdownTargetPlayer.Set then
            DropdownTargetPlayer:Set(data.PlayerInServer)
            targetPlayerName = data.PlayerInServer[1]
        end

        if data.ToggleRestartAlt ~= nil and ToggleTargetPlayer and ToggleTargetPlayer.Set then
            ToggleTargetPlayer:Set(data.ToggleRestartAlt)
            isTargetEnabled = data.ToggleRestartAlt
        end

        SaveCurrentConfig()
    end,
})

local function applyConfigByName(name)
    local filePath = configFolder .. "\\" .. name .. ".rfld"
    if not isfile(filePath) then return end

    selectedConfig = name
    if DropdownConfig and DropdownConfig.Set then
        DropdownConfig:Set({name})
    end
    saveLastUsedPresetName()

    local content = readfile(filePath)
    local data = HttpService:JSONDecode(content)

    if data.RestartTimeSlider and Slider and Slider.Set then
        Slider:Set(data.RestartTimeSlider)
        lastSliderValue = data.RestartTimeSlider
    end

    if data.PlayerInServer and data.PlayerInServer[1] and DropdownTargetPlayer and DropdownTargetPlayer.Set then
        DropdownTargetPlayer:Set(data.PlayerInServer)
        targetPlayerName = data.PlayerInServer[1]
    end

    if data.ToggleRestartAlt ~= nil and ToggleTargetPlayer and ToggleTargetPlayer.Set then
        ToggleTargetPlayer:Set(data.ToggleRestartAlt)
        isTargetEnabled = data.ToggleRestartAlt
    end
end

local function ensureDefaultConfig()
    local files = getConfigFiles()
    if #files == 0 then
        local presetName = "Preset 1"
        local filePath = configFolder .. "\\" .. presetName .. ".rfld"
        local data = makeDefaultConfig()
        writefile(filePath, HttpService:JSONEncode(data))

        local opts = getConfigFiles()
        DropdownConfig:Refresh(opts, true)
        DropdownConfig:Set({presetName})
        selectedConfig = presetName
        saveLastUsedPresetName()
        applyConfigByName(presetName)
    else
        DropdownConfig:Refresh(files, true)
    end
end

ensureDefaultConfig()

local filesNow = getConfigFiles()
local lastName = loadLastUsedPresetName()

if lastName then
    local exists = false
    for _, name in ipairs(filesNow) do
        if name == lastName then
            exists = true
            break
        end
    end
    if exists then
        applyConfigByName(lastName)
    else
        applyConfigByName("Preset 1")
    end
else
    applyConfigByName("Preset 1")
end
