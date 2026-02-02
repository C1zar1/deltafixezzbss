-- // СЕРВИСЫ
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer

-- // ПАПКА/ФАЙЛЫ
local CONFIG_FOLDER = "EzzBss"
local accountId = tostring(LocalPlayer and LocalPlayer.UserId or 0)
local LAST_USED_FILE = CONFIG_FOLDER .. "\\last_used_" .. accountId .. ".txt"

-- Пытаемся создать папку, если есть makefolder
pcall(function()
    if makefolder then
        makefolder(CONFIG_FOLDER)
    end
end)

local function getPresetPath(name)
    return CONFIG_FOLDER .. "\\" .. name .. ".rfld"
end

-- // RAYFIELD
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "EzzBss",
    Icon = 0,
    LoadingTitle = "EzzBss",
    LoadingSubtitle = "by Solvibe and Memzad Prime",
    ShowText = "EzzBss",
    Theme = "Default",
    ToggleUIKeybind = "K",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = false,
        FolderName = "EzzBss",
        FileName = "Rayfield_Stub",
    },
    KeySystem = false,
})

-- // СОСТОЯНИЕ
local selectedConfig = nil
local lastSliderValue = 1
local targetPlayerName = ""
local isTargetEnabled = false

local Slider
local DropdownTargetPlayer
local ToggleTargetPlayer
local DropdownConfig

---------------------------------------------------------------------
-- РАБОТА С ОДНИМ ПРЕСЕТОМ (БЕЗ listfiles)
---------------------------------------------------------------------
local function makeDefaultConfig()
    return {
        RestartTimeSlider = 1,
        PlayerInServer = {""},
        ToggleRestartAlt = false,
    }
end

local function savePreset(name, data)
    local path = getPresetPath(name)
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if ok then
        pcall(function()
            writefile(path, encoded)
        end)
    end
end

local function loadPreset(name)
    local path = getPresetPath(name)
    local ok, data = pcall(function()
        return readfile(path)
    end)
    if not ok or not data or data == "" then
        return nil
    end
    local okDecode, decoded = pcall(function()
        return HttpService:JSONDecode(data)
    end)
    if okDecode and type(decoded) == "table" then
        return decoded
    end
    return nil
end

local function saveLastUsedPresetName()
    if not selectedConfig then return end
    pcall(function()
        writefile(LAST_USED_FILE, selectedConfig)
    end)
end

local function loadLastUsedPresetName()
    local ok, data = pcall(function()
        return readfile(LAST_USED_FILE)
    end)
    if ok and data and data ~= "" then
        return data
    end
    return nil
end

-- Без listfiles: просто считаем, что пресеты называются "Preset N"
local function getNextPresetName()
    local i = 1
    while true do
        local name = "Preset " .. i
        local ok = pcall(function()
            return readfile(getPresetPath(name))
        end)
        if not ok then
            return name
        end
        i += 1
    end
end

---------------------------------------------------------------------
-- ТАЙМЕР РЕСТАРТА
---------------------------------------------------------------------
local reconnectTime = 0
local timerStart = 0
local timerRunning = false

local function startTimer(hours)
    reconnectTime = hours * 3600
    timerStart = tick()
    timerRunning = true
end

local function onErrorMessageChanged()
    local errorMessage = GuiService:GetErrorMessage()
    if errorMessage and errorMessage ~= "" then
        local player = LocalPlayer
        if player then
            task.wait()
            TeleportService:Teleport(game.PlaceId, player)
        end
    end
end

GuiService.ErrorMessageChanged:Connect(onErrorMessageChanged)

---------------------------------------------------------------------
-- ТАБЫ
---------------------------------------------------------------------
local HomeTab = Window:CreateTab("Home", 4483362458)
local ConfigTab = Window:CreateTab("Configs", 4483362458)
local AltTab = Window:CreateTab("Alt", 4483362458)

HomeTab:CreateSection("Main")
ConfigTab:CreateSection("Presets")
AltTab:CreateSection("Alt settings")

---------------------------------------------------------------------
-- UI ЭЛЕМЕНТЫ
---------------------------------------------------------------------
Slider = HomeTab:CreateSlider({
    Name = "Restart time (hours)",
    Range = {1, 24},
    Increment = 1,
    Suffix = "h",
    CurrentValue = 1,
    Flag = "RestartTimeSlider",
    Callback = function(Value)
        lastSliderValue = Value
        startTimer(Value)
        if selectedConfig then
            local data = loadPreset(selectedConfig) or makeDefaultConfig()
            data.RestartTimeSlider = Value
            data.PlayerInServer = {targetPlayerName ~= "" and targetPlayerName or ""}
            data.ToggleRestartAlt = isTargetEnabled
            savePreset(selectedConfig, data)
            saveLastUsedPresetName()
        end
    end,
})

DropdownTargetPlayer = AltTab:CreateDropdown({
    Name = "Target player",
    Options = {""},
    CurrentOption = {""},
    Flag = "TargetPlayerDropdown",
    Callback = function(Option)
        targetPlayerName = Option[1] or ""
        if selectedConfig then
            local data = loadPreset(selectedConfig) or makeDefaultConfig()
            data.RestartTimeSlider = lastSliderValue
            data.PlayerInServer = {targetPlayerName ~= "" and targetPlayerName or ""}
            data.ToggleRestartAlt = isTargetEnabled
            savePreset(selectedConfig, data)
            saveLastUsedPresetName()
        end
    end,
})

ToggleTargetPlayer = AltTab:CreateToggle({
    Name = "Enable target reconnect",
    CurrentValue = false,
    Flag = "TargetToggle",
    Callback = function(Value)
        isTargetEnabled = Value
        if selectedConfig then
            local data = loadPreset(selectedConfig) or makeDefaultConfig()
            data.RestartTimeSlider = lastSliderValue
            data.PlayerInServer = {targetPlayerName ~= "" and targetPlayerName or ""}
            data.ToggleRestartAlt = isTargetEnabled
            savePreset(selectedConfig, data)
            saveLastUsedPresetName()
        end
    end,
})

DropdownConfig = ConfigTab:CreateDropdown({
    Name = "Presets",
    Options = {},
    CurrentOption = {""},
    Flag = "PresetDropdown",
    Callback = function(Option)
        local name = Option[1]
        if not name or name == "" then return end
        local data = loadPreset(name)
        if not data then return end

        selectedConfig = name
        saveLastUsedPresetName()

        if Slider and Slider.Set and data.RestartTimeSlider ~= nil then
            Slider:Set(data.RestartTimeSlider)
            lastSliderValue = data.RestartTimeSlider
        end

        if DropdownTargetPlayer and DropdownTargetPlayer.Set and data.PlayerInServer then
            DropdownTargetPlayer:Set(data.PlayerInServer)
            targetPlayerName = data.PlayerInServer[1] or ""
        end

        if ToggleTargetPlayer and ToggleTargetPlayer.Set and data.ToggleRestartAlt ~= nil then
            ToggleTargetPlayer:Set(data.ToggleRestartAlt)
            isTargetEnabled = data.ToggleRestartAlt
        end
    end,
})

ConfigTab:CreateButton({
    Name = "Create Config",
    Callback = function()
        local name = getNextPresetName()
        local data = makeDefaultConfig()
        savePreset(name, data)
        selectedConfig = name
        saveLastUsedPresetName()

        -- вручную обновляем список опций
        local options = {}
        for i = 1, 50 do
            local presetName = "Preset " .. i
            local ok = pcall(function()
                return readfile(getPresetPath(presetName))
            end)
            if ok then
                table.insert(options, presetName)
            end
        end
        DropdownConfig:Refresh(options, true)
        DropdownConfig:Set({name})

        -- применяем
        Slider:Set(data.RestartTimeSlider)
        lastSliderValue = data.RestartTimeSlider
        DropdownTargetPlayer:Set(data.PlayerInServer)
        targetPlayerName = data.PlayerInServer[1] or ""
        ToggleTargetPlayer:Set(data.ToggleRestartAlt)
        isTargetEnabled = data.ToggleRestartAlt
    end,
})

---------------------------------------------------------------------
-- АВТОЗАГРУЗКА ПОСЛЕДНЕГО ПРЕСЕТА
---------------------------------------------------------------------
local function initLastPreset()
    local last = loadLastUsedPresetName()
    local options = {}

    for i = 1, 50 do
        local presetName = "Preset " .. i
        local ok = pcall(function()
            return readfile(getPresetPath(presetName))
        end)
        if ok then
            table.insert(options, presetName)
        end
    end

    DropdownConfig:Refresh(options, true)

    if last then
        local data = loadPreset(last)
        if data then
            selectedConfig = last
            DropdownConfig:Set({last})

            Slider:Set(data.RestartTimeSlider or 1)
            lastSliderValue = data.RestartTimeSlider or 1

            if data.PlayerInServer then
                DropdownTargetPlayer:Set(data.PlayerInServer)
                targetPlayerName = data.PlayerInServer[1] or ""
            end

            if data.ToggleRestartAlt ~= nil then
                ToggleTargetPlayer:Set(data.ToggleRestartAlt)
                isTargetEnabled = data.ToggleRestartAlt
            end

            return
        end
    end

    -- если нет last или файл битый — ничего не делаем
end

initLastPreset()
