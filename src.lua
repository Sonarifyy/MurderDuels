local repo    = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting        = game:GetService("Lighting")
local Camera          = workspace.CurrentCamera
local LocalPlayer     = Players.LocalPlayer
local Mouse           = LocalPlayer:GetMouse()

local Window = Library:CreateWindow({
    Title            = "Fatal Hub",
    Footer           = "Fatal Hub - Murder Duels",
    Size             = UDim2.fromOffset(680, 540),
    Icon             = "rbxassetid://75467423522724",
    IconSize         = UDim2.fromOffset(36, 36),
    Center           = true,
    Resizable        = true,
    ToggleKeybind    = Enum.KeyCode.RightShift,
    NotifySide       = "Right",
    ShowCustomCursor = true,
    Font             = Enum.Font.Code,
    AutoShow         = true,
    GlobalSearch     = true,
    EnableSidebarResize = true,
    EnableCompacting    = true,
    SidebarCompacted    = true,
})

Window:SetCornerRadius(20)

local Tabs = {
    Main             = Window:AddTab({ Name = "Skin Changer", Icon = "103518456673098", Description = "Skin Changer" }),
    Combat           = Window:AddTab({ Name = "Combat", Icon = "sword", Description = "Combat" }),
    ["UI Settings"]  = Window:AddTab({ Name = "UI Settings",  Icon = "settings" }),
}

local CombatConfig = {
    TargetRadius = 500,
    OriginOffset = Vector3.new(0, 2.5, 0),
    TargetOffset = Vector3.new(0, 3, 0),
    DefaultEffects = {
        Frost = 0,
        Ricochet = 0,
        Barrage = 0
    },
    ESP = {
        Enabled = true,
        Box = true,
        Name = true,
        Distance = true,
        Color = Color3.fromRGB(255, 50, 50),
        Thickness = 1
    },
    AimAssist = {
        Enabled = false,
        FOV = 120,
        Smoothness = 0.4,
        TeamCheck = true,
        ShowFOV = true
    },
    Triggerbot = {
        Enabled = false,
        Delay = 0.05
    },
    Chams = {
        Enabled = false,
        FillColor = Color3.fromRGB(255, 40, 40),
        OutlineColor = Color3.fromRGB(255, 255, 255),
        FillTransparency = 0.6,
        OutlineTransparency = 0
    },
    FOV = 70,
    Time = 14
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShootRemote = Remotes:WaitForChild("ShootReplicate")

local isGunActive = false
local gunConnection = nil
local ESPObjects = {}
local ChamsObjects = {}

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 64
FOVCircle.Radius = CombatConfig.AimAssist.FOV
FOVCircle.Filled = false
FOVCircle.Color = Color3.fromRGB(255, 40, 40)
FOVCircle.Visible = false
FOVCircle.ZIndex = 10

local math_random = math.random
local Vector3_new = Vector3.new
local table_insert = table.insert
local tick = tick

local function isEnemy(player)
    if not CombatConfig.AimAssist.TeamCheck then return true end
    if not player.Team or not LocalPlayer.Team then return true end
    return player.Team ~= LocalPlayer.Team
end

local function getTargets()
    local targets = {}
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return targets end

    local originPosition = rootPart.Position
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not isEnemy(player) then continue end

        local targetChar = player.Character
        local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local distance = (originPosition - targetRoot.Position).Magnitude
            if distance <= CombatConfig.TargetRadius then
                table_insert(targets, player)
            end
        end
    end
    return targets
end

local function replicateGunShot(target)
    local character = LocalPlayer.Character
    local targetChar = target.Character
    if not character or not targetChar then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not rootPart or not targetRoot then return end

    local origin = rootPart.Position + CombatConfig.OriginOffset
    local hitPos = targetRoot.Position + CombatConfig.TargetOffset
    local actionId = math_random(1, 999999)

    ShootRemote:FireServer({
        hitPos = hitPos,
        to = hitPos,
        hitInstance = targetRoot,
        id = actionId,
        hitNormal = Vector3_new(0, 1, 0),
        firedAt = tick(),
        origin = origin,
        isCharacterHit = true,
        kind = "bullet",
        ownerUserId = LocalPlayer.UserId,
        mode = "single",
        effects = CombatConfig.DefaultEffects,
        isADS = false
    })
end

local function startGun()
    if gunConnection then return end
    gunConnection = RunService.Heartbeat:Connect(function()
        if not isGunActive then return end
        local targets = getTargets()
        for i = 1, #targets do
            task.spawn(replicateGunShot, targets[i])
        end
    end)
end

local function stopGun()
    if gunConnection then
        gunConnection:Disconnect()
        gunConnection = nil
    end
end

local function toggleGun()
    if isGunActive then return end
    isGunActive = true
    startGun()

    for i = 1, 5 do
        local targets = getTargets()
        for _, player in ipairs(targets) do
            task.spawn(replicateGunShot, player)
        end
        task.wait(0.035)
    end

    isGunActive = false
    stopGun()
end

local function getClosestEnemy()
    local closest = nil
    local closestDist = CombatConfig.AimAssist.FOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer or not isEnemy(player) then continue end
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 1.5, 0))
        if not onScreen or screenPos.Z < 0 then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = root
        end
    end
    return closest
end

local function aimAssist()
    if not CombatConfig.AimAssist.Enabled then return end
    local target = getClosestEnemy()
    if not target then return end

    local screenPos = Camera:WorldToViewportPoint(target.Position + Vector3.new(0, 1.5, 0))
    local mousePos = UserInputService:GetMouseLocation()

    local deltaX = (screenPos.X - mousePos.X) * CombatConfig.AimAssist.Smoothness
    local deltaY = (screenPos.Y - mousePos.Y) * CombatConfig.AimAssist.Smoothness

    if math.abs(deltaX) > 0.5 or math.abs(deltaY) > 0.5 then
        mousemoverel(deltaX, deltaY)
    end
end

local lastTrigger = 0
local function triggerbot()
    if not CombatConfig.Triggerbot.Enabled then return end
    if tick() - lastTrigger < CombatConfig.Triggerbot.Delay then return end

    local target = Mouse.Target
    if not target then return end

    local character = target:FindFirstAncestorOfClass("Model")
    if not character then return end

    local player = Players:GetPlayerFromCharacter(character)
    if player and player ~= LocalPlayer and isEnemy(player) then
        mouse1click()
        lastTrigger = tick()
    end
end

local function createESP(player)
    if ESPObjects[player] then return end
    local drawings = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text")
    }
    drawings.Box.Thickness = CombatConfig.ESP.Thickness
    drawings.Box.Filled = false
    drawings.Box.Color = CombatConfig.ESP.Color
    drawings.Box.Visible = false
    drawings.Box.ZIndex = 2
    drawings.Name.Size = 14
    drawings.Name.Center = true
    drawings.Name.Outline = true
    drawings.Name.Color = CombatConfig.ESP.Color
    drawings.Name.Visible = false
    drawings.Name.ZIndex = 3
    drawings.Distance.Size = 13
    drawings.Distance.Center = true
    drawings.Distance.Outline = true
    drawings.Distance.Color = Color3.fromRGB(200, 200, 200)
    drawings.Distance.Visible = false
    drawings.Distance.ZIndex = 3
    ESPObjects[player] = drawings
end

local function removeESP(player)
    local drawings = ESPObjects[player]
    if not drawings then return end
    for _, drawing in pairs(drawings) do
        drawing:Remove()
    end
    ESPObjects[player] = nil
end

local function updateESP()
    if not CombatConfig.ESP.Enabled then
        for _, drawings in pairs(ESPObjects) do
            drawings.Box.Visible = false
            drawings.Name.Visible = false
            drawings.Distance.Visible = false
        end
        return
    end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer or not isEnemy(player) then
            removeESP(player)
            continue
        end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 then
            removeESP(player)
            continue
        end

        createESP(player)
        local drawings = ESPObjects[player]
        local pos, onScreen = Camera:WorldToViewportPoint(root.Position)

        if onScreen then
            local size = 2000 / pos.Z
            if CombatConfig.ESP.Box then
                drawings.Box.Size = Vector2.new(size * 0.6, size)
                drawings.Box.Position = Vector2.new(pos.X - drawings.Box.Size.X / 2, pos.Y - drawings.Box.Size.Y / 2)
                drawings.Box.Visible = true
            else
                drawings.Box.Visible = false
            end
            if CombatConfig.ESP.Name then
                drawings.Name.Text = player.Name
                drawings.Name.Position = Vector2.new(pos.X, pos.Y - size / 2 - 18)
                drawings.Name.Visible = true
            else
                drawings.Name.Visible = false
            end
            if CombatConfig.ESP.Distance and myRoot then
                local dist = math.floor((myRoot.Position - root.Position).Magnitude)
                drawings.Distance.Text = dist .. "m"
                drawings.Distance.Position = Vector2.new(pos.X, pos.Y + size / 2 + 4)
                drawings.Distance.Visible = true
            else
                drawings.Distance.Visible = false
            end
        else
            drawings.Box.Visible = false
            drawings.Name.Visible = false
            drawings.Distance.Visible = false
        end
    end
end

local function applyChams(player)
    if ChamsObjects[player] then return end
    local char = player.Character
    if not char then return end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = char
    highlight.FillColor = CombatConfig.Chams.FillColor
    highlight.OutlineColor = CombatConfig.Chams.OutlineColor
    highlight.FillTransparency = CombatConfig.Chams.FillTransparency
    highlight.OutlineTransparency = CombatConfig.Chams.OutlineTransparency
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = char
    ChamsObjects[player] = highlight
end

local function removeChams(player)
    local hl = ChamsObjects[player]
    if hl then
        hl:Destroy()
        ChamsObjects[player] = nil
    end
end

local function updateChams()
    if not CombatConfig.Chams.Enabled then
        for player, _ in pairs(ChamsObjects) do
            removeChams(player)
        end
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer or not isEnemy(player) then
            removeChams(player)
            continue
        end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health <= 0 then
            removeChams(player)
            continue
        end
        if not ChamsObjects[player] then
            applyChams(player)
        end
    end
end

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
    removeChams(player)
end)

RunService.RenderStepped:Connect(function()
    updateESP()
    updateChams()
    aimAssist()
    triggerbot()

    local mousePos = UserInputService:GetMouseLocation()
    FOVCircle.Position = mousePos
    FOVCircle.Radius = CombatConfig.AimAssist.FOV
    FOVCircle.Visible = CombatConfig.AimAssist.Enabled and CombatConfig.AimAssist.ShowFOV
end)

local TargetingGroup = Tabs.Combat:AddLeftGroupbox("Targeting", "crosshair")
local AimGroup       = Tabs.Combat:AddLeftGroupbox("Aim", "target")
local VisualsGroup   = Tabs.Combat:AddRightGroupbox("Visuals", "eye")
local WorldGroup     = Tabs.Combat:AddRightGroupbox("World", "sun")

TargetingGroup:AddButton({
    Text = "Kill All",
    Func = function()
        toggleGun()
        Library:Notify({ Title = "Combat", Description = "killed all players thx np", Time = 2 })
    end,
})

TargetingGroup:AddDivider()
TargetingGroup:AddLabel("Keybind")
    :AddKeyPicker("GunTargetKeybind", {
        Default = "T",
        Text = "Kill All Keybind",
        Mode = "Toggle",
        Callback = function()
            toggleGun()
        end,
    })

AimGroup:AddToggle("AimAssistEnabled", {
    Text = "Aim Assist",
    Default = false,
    Callback = function(v) CombatConfig.AimAssist.Enabled = v end,
})

AimGroup:AddToggle("ShowFOV", {
    Text = "Show FOV Circle",
    Default = true,
    Callback = function(v) CombatConfig.AimAssist.ShowFOV = v end,
})

AimGroup:AddSlider("AimFOV", {
    Text = "Aim FOV",
    Default = 120,
    Min = 20,
    Max = 400,
    Rounding = 0,
    Callback = function(v) CombatConfig.AimAssist.FOV = v end,
})

AimGroup:AddSlider("AimSmooth", {
    Text = "Smoothness",
    Default = 0.4,
    Min = 0.05,
    Max = 1,
    Rounding = 2,
    Callback = function(v) CombatConfig.AimAssist.Smoothness = v end,
})

AimGroup:AddToggle("TriggerbotEnabled", {
    Text = "Triggerbot",
    Default = false,
    Callback = function(v) CombatConfig.Triggerbot.Enabled = v end,
})

VisualsGroup:AddToggle("ESPEnabled", {
    Text = "ESP",
    Default = true,
    Callback = function(v) CombatConfig.ESP.Enabled = v end,
})

VisualsGroup:AddToggle("ESPBox", {
    Text = "Box",
    Default = true,
    Callback = function(v) CombatConfig.ESP.Box = v end,
})

VisualsGroup:AddToggle("ESPName", {
    Text = "Name",
    Default = true,
    Callback = function(v) CombatConfig.ESP.Name = v end,
})

VisualsGroup:AddToggle("ESPDistance", {
    Text = "Distance",
    Default = true,
    Callback = function(v) CombatConfig.ESP.Distance = v end,
})

VisualsGroup:AddToggle("ChamsEnabled", {
    Text = "Chams (Highlight)",
    Default = false,
    Callback = function(v) CombatConfig.Chams.Enabled = v end,
})

WorldGroup:AddSlider("CameraFOV", {
    Text = "Camera FOV",
    Default = 70,
    Min = 30,
    Max = 120,
    Rounding = 0,
    Callback = function(v)
        CombatConfig.FOV = v
        Camera.FieldOfView = v
    end,
})

WorldGroup:AddSlider("TimeChanger", {
    Text = "Time of Day",
    Default = 14,
    Min = 0,
    Max = 24,
    Rounding = 1,
    Callback = function(v)
        CombatConfig.Time = v
        Lighting.ClockTime = v
    end,
})

local FALLBACK_ICON = "rbxassetid://120165849310361"

local function getModels(folderName)
    local folder = ReplicatedStorage:FindFirstChild(folderName)
    local list = {}
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Model") then
                table.insert(list, { Name = child.Name })
            end
        end
    end
    table.sort(list, function(a, b) return a.Name < b.Name end)
    return list
end

local Knives = getModels("Knives")
local Revolvers = getModels("Revolvers")

local KnifeNames, KnifeMap, KnifeImages = {}, {}, {}
for _, v in ipairs(Knives) do
    table.insert(KnifeNames, v.Name)
    KnifeMap[v.Name] = v
    KnifeImages[v.Name] = FALLBACK_ICON
end

local RevolverNames, RevolverMap, RevolverImages = {}, {}, {}
for _, v in ipairs(Revolvers) do
    table.insert(RevolverNames, v.Name)
    RevolverMap[v.Name] = v
    RevolverImages[v.Name] = FALLBACK_ICON
end

local function getAttr(k, default)
    local v = LocalPlayer:GetAttribute(k)
    return (v ~= nil) and v or default
end

local State = {
    KnifeSkin   = getAttr("KnifeSkin", KnifeNames[1] or "Default"),
    KnifeRarity = getAttr("KnifeRarity", "Common"),
    RevolverSkin = getAttr("RevolverSkin", RevolverNames[1] or "Default"),
    RevolverRarity = getAttr("RevolverRarity", "Common"),
}

if not KnifeMap[State.KnifeSkin] then State.KnifeSkin = KnifeNames[1] or "Default" end
if not RevolverMap[State.RevolverSkin] then State.RevolverSkin = RevolverNames[1] or "Default" end

local function ApplyKnife()
    LocalPlayer:SetAttribute("KnifeSkin", State.KnifeSkin)
    LocalPlayer:SetAttribute("KnifeIcon", FALLBACK_ICON)
    LocalPlayer:SetAttribute("KnifeRarity", State.KnifeRarity)
end

local function ApplyRevolver()
    LocalPlayer:SetAttribute("RevolverSkin", State.RevolverSkin)
    LocalPlayer:SetAttribute("RevolverIcon", FALLBACK_ICON)
    LocalPlayer:SetAttribute("RevolverRarity", State.RevolverRarity)
end

local LeftGroup = Tabs.Main:AddLeftGroupbox("Knives", "knife")
local RightGroup = Tabs.Main:AddRightGroupbox("Revolvers", "gun")

LeftGroup:AddDropdown("KnifeDropdown", {
    Text = "Knife Skin",
    Values = KnifeNames,
    Default = State.KnifeSkin,
    Searchable = true,
    ValueImages = KnifeImages,
    Callback = function(opt)
        if KnifeMap[opt] then
            State.KnifeSkin = opt
            ApplyKnife()
        end
    end,
})

LeftGroup:AddDropdown("KnifeRarityDropdown", {
    Text = "Rarity",
    Values = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Secret" },
    Default = State.KnifeRarity,
    Callback = function(opt)
        State.KnifeRarity = opt
        ApplyKnife()
    end,
})

LeftGroup:AddButton({
    Text = "Force Apply Knife",
    Func = function()
        ApplyKnife()
        Library:Notify({ Title = "Skin Applied", Description = State.KnifeSkin .. " · " .. State.KnifeRarity, Time = 2 })
    end,
})

RightGroup:AddDropdown("RevolverDropdown", {
    Text = "Revolver Skin",
    Values = RevolverNames,
    Default = State.RevolverSkin,
    Searchable = true,
    ValueImages = RevolverImages,
    Callback = function(opt)
        if RevolverMap[opt] then
            State.RevolverSkin = opt
            ApplyRevolver()
        end
    end,
})

RightGroup:AddDropdown("RevolverRarityDropdown", {
    Text = "Rarity",
    Values = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Secret" },
    Default = State.RevolverRarity,
    Callback = function(opt)
        State.RevolverRarity = opt
        ApplyRevolver()
    end,
})

RightGroup:AddButton({
    Text = "Force Apply Revolver",
    Func = function()
        ApplyRevolver()
        Library:Notify({ Title = "Skin Applied", Description = State.RevolverSkin .. " · " .. State.RevolverRarity, Time = 2 })
    end,
})

task.spawn(function()
    task.wait(0.8)
    ApplyKnife()
    ApplyRevolver()
end)

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = Library.KeybindFrame.Visible,
    Text = "Open Keybind Menu",
    Callback = function(value) Library.KeybindFrame.Visible = value end,
})

MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom Cursor",
    Default = true,
    Callback = function(value) Library.ShowCustomCursor = value end,
})

MenuGroup:AddDropdown("NotificationSide", {
    Values = { "Left", "Right" },
    Default = "Right",
    Text = "Notification Side",
    Callback = function(value) Library:SetNotifySide(value) end,
})

MenuGroup:AddDropdown("DPIDropdown", {
    Values = { "50", "75", "100", "125", "150", "175", "200" },
    Default = "100",
    Text = "DPI Scale",
    Callback = function(value)
        local num = tonumber(value)
        if num then
            Library:SetDPIScale(num)
        end
    end,
})

MenuGroup:AddSlider("UICornerSlider", {
    Text = "Corner Radius",
    Default = 20,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(value) Window:SetCornerRadius(value) end,
})

MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind")
    :AddKeyPicker("MenuKeybind", {
        Default = "RightControl",
        NoUI = true,
        Text = "Menu keybind",
    })

MenuGroup:AddButton({
    Text = "Unload",
    Func = function() Library:Unload() end,
    Risky = true,
})

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

ThemeManager:SetFolder("FatalHub")
SaveManager:SetFolder("FatalHub/Main")

ThemeManager:SetDefaultTheme({
    MainColor = "191919",
    FontFace = "Code",
    FontColor = "ffffff",
    OutlineColor = "282828",
    BackgroundColor = "0f0f0f",
    BackgroundImage = "",
    AccentColor = "ff0000"
})

ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:BuildConfigSection(Tabs["UI Settings"])

SaveManager:LoadAutoloadConfig()
