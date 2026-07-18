local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local settings = {
    aimbot = false, wallCheck = false, fov = 120, smoothness = 45,
    predict = true, predictStrength = 5,
    esp = true, espBoxes = true, espHealth = true, espDist = true, espNames = true,
    tracers = false, clickTp = false,
    vehicleEsp = false, submarineEsp = true, uavEsp = true, 
    ugvEsp = true,
    teamCheck = true, noclip = false, fly = false, flySpeed = 250,
    autoAirdrop = false, autoDrone = false,
    binds = { aimbot = nil, fly = nil, noclip = nil, clickTp = nil }
}

local uiUpdaters = {}
local scriptConnections = {}
local activeTweens = {}
local isScriptActive = true
local isLoaded = false
local isLoadingConfig = false
local baseSpawnCFrame = nil
local wasNoclip = false
local isMiscPageOpen = false
local devToolsUnlocked = false

local vehicles = {}
local vehicleDrawings = {}
local subDrawings = {}
local uavDrawings = {}
local ugvDrawings = {}

local espObjects = {}
local tracerObjects = {}
local favorites = {}
local droneInteractions = {}

local function captureSpawn(char)
    task.spawn(function()
        local hrp = char:WaitForChild("HumanoidRootPart", 10)
        if hrp then
            task.wait(1) 
            if isScriptActive then baseSpawnCFrame = hrp.CFrame end
        end
    end)
end
if LocalPlayer.Character then captureSpawn(LocalPlayer.Character) end
table.insert(scriptConnections, LocalPlayer.CharacterAdded:Connect(captureSpawn))

local function safeRemoveDrawing(obj)
    if not obj then return end
    pcall(function()
        obj.Visible = false
        if obj.Remove then obj:Remove() 
        elseif obj.Destroy then obj:Destroy() end
    end)
end

local function createDrawing(class, properties)
    local obj = Drawing.new(class)
    for prop, val in pairs(properties) do pcall(function() obj[prop] = val end) end
    return obj
end

local function findChildLower(parent, name)
    if not parent then return nil end
    local lowerName = string.lower(name)
    for _, child in ipairs(parent:GetChildren()) do
        if string.lower(child.Name) == lowerName then
            return child
        end
    end
    return nil
end

local FOVring = createDrawing("Circle", {
    Thickness = 1, Radius = settings.fov, Transparency = 1,
    Color = Color3.fromRGB(255, 255, 255), Filled = false, Visible = false,
    Position = UserInputService:GetMouseLocation()
})

task.spawn(function()
    while isScriptActive do
        if settings.vehicleEsp then
            local newVehicles = {}
            local gs = workspace:FindFirstChild("Game Systems")
            local objectsToScan = gs and gs:GetChildren() or {}
            
            local scanCount = 0
            while #objectsToScan > 0 and isScriptActive do
                local currentObj = table.remove(objectsToScan, #objectsToScan)
                if currentObj:IsA("VehicleSeat") then table.insert(newVehicles, currentObj) end
                for _, child in ipairs(currentObj:GetChildren()) do table.insert(objectsToScan, child) end
                
                scanCount = scanCount + 1
                if scanCount % 200 == 0 then RunService.Heartbeat:Wait() end
            end
            if isScriptActive then vehicles = newVehicles end
            task.wait(2)
        else
            task.wait(1)
        end
    end
end)

local targetParent = pcall(function() return gethui() end) and gethui() or game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CustomOverlayMenu"
ScreenGui.ResetOnSpawn = false
pcall(function() if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
ScreenGui.Parent = targetParent

local LoadingGui = Instance.new("ScreenGui")
LoadingGui.Name = "CustomLoadingOverlay"
LoadingGui.ResetOnSpawn = false
pcall(function() if syn and syn.protect_gui then syn.protect_gui(LoadingGui) end end)
LoadingGui.Parent = targetParent

local StatsGui = Instance.new("ScreenGui")
StatsGui.Name = "CustomStatsOverlay"
StatsGui.ResetOnSpawn = false
pcall(function() if syn and syn.protect_gui then syn.protect_gui(StatsGui) end end)
StatsGui.Parent = targetParent

local StatsContainer = Instance.new("Frame", StatsGui)
StatsContainer.BackgroundTransparency = 0.5
StatsContainer.BackgroundColor3 = Color3.new(0, 0, 0)
StatsContainer.Position = UDim2.new(0, 16, 0, 46)
StatsContainer.Size = UDim2.new(0, 130, 0, 24)
Instance.new("UICorner", StatsContainer).CornerRadius = UDim.new(0, 6)

local StatsLayout = Instance.new("UIListLayout", StatsContainer)
StatsLayout.FillDirection = Enum.FillDirection.Horizontal
StatsLayout.SortOrder = Enum.SortOrder.LayoutOrder
StatsLayout.Padding = UDim.new(0, 6)
StatsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
StatsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local FpsLabel = Instance.new("TextLabel", StatsContainer)
FpsLabel.BackgroundTransparency = 1
FpsLabel.Size = UDim2.new(0, 50, 1, 0)
FpsLabel.Font = Enum.Font.GothamBold
FpsLabel.TextSize = 12
FpsLabel.TextColor3 = Color3.new(1, 1, 1)
FpsLabel.Text = "FPS: 0"

local Separator = Instance.new("Frame", StatsContainer)
Separator.Size = UDim2.new(0, 1, 0, 12)
Separator.BackgroundColor3 = Color3.new(1, 1, 1)
Separator.BackgroundTransparency = 0.3
Separator.BorderSizePixel = 0

local PingLabel = Instance.new("TextLabel", StatsContainer)
PingLabel.BackgroundTransparency = 1
PingLabel.Size = UDim2.new(0, 55, 1, 0)
PingLabel.Font = Enum.Font.GothamBold
PingLabel.TextSize = 12
PingLabel.TextColor3 = Color3.new(1, 1, 1)
PingLabel.Text = "Ping: 0"

local lastStatsUpdate = tick()
local framesCount = 0
table.insert(scriptConnections, RunService.RenderStepped:Connect(function()
    framesCount = framesCount + 1
    local now = tick()
    if now - lastStatsUpdate >= 1 then
        FpsLabel.Text = "FPS: " .. framesCount
        local ping = 0
        pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
        if ping == 0 then pcall(function() ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end) end
        PingLabel.Text = "Ping: " .. ping
        
        framesCount = 0
        lastStatsUpdate = now
    end
end))

local Theme = {
    Background = Color3.fromRGB(0, 0, 0), BackgroundTrans = 0.5,
    PanelBG = Color3.fromRGB(15, 15, 15), PanelTrans = 0.4,
    Accent = Color3.fromRGB(220, 220, 220), TextMain = Color3.fromRGB(255, 255, 255),
    TextSub = Color3.fromRGB(170, 170, 170), Border = Color3.fromRGB(60, 60, 60), OffColor = Color3.fromRGB(30, 30, 30)
}

local LoadingFrame = Instance.new("Frame", LoadingGui)
LoadingFrame.Size = UDim2.new(0, 220, 0, 55)
LoadingFrame.AnchorPoint = Vector2.new(0.5, 0)
LoadingFrame.Position = UDim2.new(0.5, 0, 0, 20)
LoadingFrame.BackgroundColor3 = Theme.PanelBG
LoadingFrame.BackgroundTransparency = 0.2
Instance.new("UICorner", LoadingFrame).CornerRadius = UDim.new(0, 8)
local LStroke = Instance.new("UIStroke", LoadingFrame)
LStroke.Color = Theme.Border
LStroke.Thickness = 1.5

local LoadingText = Instance.new("TextLabel", LoadingFrame)
LoadingText.Size = UDim2.new(1, 0, 0, 20)
LoadingText.Position = UDim2.new(0, 0, 0, 8)
LoadingText.BackgroundTransparency = 1
LoadingText.Text = "Loading..."
LoadingText.TextColor3 = Theme.Accent
LoadingText.Font = Enum.Font.GothamBold
LoadingText.TextSize = 13

local LoadBarBG = Instance.new("Frame", LoadingFrame)
LoadBarBG.Size = UDim2.new(1, -30, 0, 6)
LoadBarBG.AnchorPoint = Vector2.new(0.5, 0)
LoadBarBG.Position = UDim2.new(0.5, 0, 0, 35)
LoadBarBG.BackgroundColor3 = Theme.OffColor
Instance.new("UICorner", LoadBarBG).CornerRadius = UDim.new(1, 0)

local LoadBarFill = Instance.new("Frame", LoadBarBG)
LoadBarFill.Size = UDim2.new(0, 0, 1, 0)
LoadBarFill.BackgroundColor3 = Theme.Accent
Instance.new("UICorner", LoadBarFill).CornerRadius = UDim.new(1, 0)

local TpWarningLabel = Instance.new("TextLabel", ScreenGui)
TpWarningLabel.Size = UDim2.new(0, 420, 0, 40)
TpWarningLabel.AnchorPoint = Vector2.new(0.5, 0)
TpWarningLabel.Position = UDim2.new(0.5, 0, 0, 50)
TpWarningLabel.BackgroundColor3 = Theme.Background
TpWarningLabel.BackgroundTransparency = 0.3
TpWarningLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TpWarningLabel.Font = Enum.Font.GothamBold
TpWarningLabel.TextSize = 14
TpWarningLabel.Text = "this tween tp is so slow so you don't get kicked"
TpWarningLabel.Visible = false
TpWarningLabel.ZIndex = 100
Instance.new("UICorner", TpWarningLabel).CornerRadius = UDim.new(0, 8)
local TpStroke = Instance.new("UIStroke", TpWarningLabel)
TpStroke.Color = Theme.Border
TpStroke.Thickness = 1.5

local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 520, 0, 560)
Frame.Position = UDim2.new(0, 50, 0, 150)
Frame.BackgroundColor3 = Theme.Background
Frame.BackgroundTransparency = Theme.BackgroundTrans
Frame.BorderSizePixel = 0
Frame.ClipsDescendants = true
Frame.Visible = false
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 14)
local MainStroke = Instance.new("UIStroke", Frame)
MainStroke.Thickness = 1.5
MainStroke.Color = Theme.Border
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local DevToolsBtn = Instance.new("TextButton", ScreenGui)
DevToolsBtn.Size = UDim2.new(0, 100, 0, 26)
DevToolsBtn.Position = UDim2.new(0, Frame.Position.X.Offset + 20, 0, Frame.Position.Y.Offset - 35)
DevToolsBtn.BackgroundColor3 = Theme.PanelBG
DevToolsBtn.Text = "Dev Tools"
DevToolsBtn.TextColor3 = Theme.Accent
DevToolsBtn.Font = Enum.Font.GothamBold
DevToolsBtn.TextSize = 12
DevToolsBtn.Visible = false
Instance.new("UICorner", DevToolsBtn).CornerRadius = UDim.new(0, 6)
local DTStroke = Instance.new("UIStroke", DevToolsBtn)
DTStroke.Color = Theme.Border
DTStroke.Thickness = 1

local loadTw = TweenService:Create(LoadBarFill, TweenInfo.new(12.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)})
table.insert(activeTweens, loadTw)
loadTw:Play()

loadTw.Completed:Connect(function()
    if not isScriptActive then return end
    LoadingText.Text = "Loaded!"
    task.wait(0.5)
    if not isScriptActive then return end
    
    local fadeOut1 = TweenService:Create(LoadingFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
    local fadeOut2 = TweenService:Create(LoadingText, TweenInfo.new(0.5), {TextTransparency = 1})
    local fadeOut3 = TweenService:Create(LStroke, TweenInfo.new(0.5), {Transparency = 1})
    local fadeOut4 = TweenService:Create(LoadBarBG, TweenInfo.new(0.5), {BackgroundTransparency = 1})
    local fadeOut5 = TweenService:Create(LoadBarFill, TweenInfo.new(0.5), {BackgroundTransparency = 1})
    
    table.insert(activeTweens, fadeOut1)
    table.insert(activeTweens, fadeOut2)
    table.insert(activeTweens, fadeOut3)
    table.insert(activeTweens, fadeOut4)
    table.insert(activeTweens, fadeOut5)
    
    fadeOut1:Play(); fadeOut2:Play(); fadeOut3:Play(); fadeOut4:Play(); fadeOut5:Play()
    fadeOut1.Completed:Wait()
    
    if not isScriptActive then return end
    LoadingGui.Enabled = false
    isLoaded = true
    
    Frame.Size = UDim2.new(0, 480, 0, 520)
    Frame.Position = UDim2.new(0, 70, 0, 170)
    Frame.Visible = true
    DevToolsBtn.Visible = true
    
    local menuTw = TweenService:Create(Frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 520, 0, 560), Position = UDim2.new(0, 50, 0, 150)})
    table.insert(activeTweens, menuTw)
    menuTw:Play()
end)

local DevPassModal = Instance.new("Frame", ScreenGui)
DevPassModal.Size = UDim2.new(1, 0, 1, 0)
DevPassModal.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
DevPassModal.BackgroundTransparency = 0.6
DevPassModal.ZIndex = 60
DevPassModal.Visible = false

local DevPassWindow = Instance.new("Frame", DevPassModal)
DevPassWindow.Size = UDim2.new(0, 220, 0, 110)
DevPassWindow.AnchorPoint = Vector2.new(0.5, 0.5)
DevPassWindow.Position = UDim2.new(0.5, 0, 0.5, 0)
DevPassWindow.BackgroundColor3 = Theme.PanelBG
DevPassWindow.ZIndex = 61
Instance.new("UICorner", DevPassWindow).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", DevPassWindow).Color = Theme.Border

local DPTitle = Instance.new("TextLabel", DevPassWindow)
DPTitle.Size = UDim2.new(1, 0, 0, 30)
DPTitle.Position = UDim2.new(0, 0, 0, 5)
DPTitle.BackgroundTransparency = 1
DPTitle.Text = "Enter Password"
DPTitle.TextColor3 = Theme.Accent
DPTitle.Font = Enum.Font.GothamBold
DPTitle.TextSize = 14
DPTitle.ZIndex = 62

local DPInput = Instance.new("TextBox", DevPassWindow)
DPInput.Size = UDim2.new(1, -30, 0, 30)
DPInput.Position = UDim2.new(0, 15, 0, 40)
DPInput.BackgroundColor3 = Theme.OffColor
DPInput.Text = ""
DPInput.PlaceholderText = "****"
DPInput.TextColor3 = Theme.TextMain
DPInput.Font = Enum.Font.GothamMedium
DPInput.TextSize = 12
DPInput.ZIndex = 62
Instance.new("UICorner", DPInput).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", DPInput).Color = Theme.Border

local DPClose = Instance.new("TextButton", DevPassWindow)
DPClose.Size = UDim2.new(0, 20, 0, 20)
DPClose.Position = UDim2.new(1, -25, 0, 5)
DPClose.BackgroundTransparency = 1
DPClose.Text = "X"
DPClose.TextColor3 = Color3.fromRGB(255, 80, 80)
DPClose.Font = Enum.Font.GothamBold
DPClose.TextSize = 14
DPClose.ZIndex = 62

local DevPanel = Instance.new("Frame", ScreenGui)
DevPanel.Size = UDim2.new(0, 200, 0, 100)
DevPanel.AnchorPoint = Vector2.new(0.5, 0.5)
DevPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
DevPanel.BackgroundColor3 = Theme.PanelBG
DevPanel.ZIndex = 70
DevPanel.Visible = false
Instance.new("UICorner", DevPanel).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", DevPanel).Color = Theme.Border

local DPanelTitle = Instance.new("TextLabel", DevPanel)
DPanelTitle.Size = UDim2.new(1, 0, 0, 30)
DPanelTitle.Position = UDim2.new(0, 0, 0, 5)
DPanelTitle.BackgroundTransparency = 1
DPanelTitle.Text = "Dev Tools Panel"
DPanelTitle.TextColor3 = Theme.Accent
DPanelTitle.Font = Enum.Font.GothamBold
DPanelTitle.TextSize = 14
DPanelTitle.ZIndex = 71

local DPanelClose = Instance.new("TextButton", DevPanel)
DPanelClose.Size = UDim2.new(0, 20, 0, 20)
DPanelClose.Position = UDim2.new(1, -25, 0, 5)
DPanelClose.BackgroundTransparency = 1
DPanelClose.Text = "X"
DPanelClose.TextColor3 = Color3.fromRGB(255, 80, 80)
DPanelClose.Font = Enum.Font.GothamBold
DPanelClose.TextSize = 14
DPanelClose.ZIndex = 71

local BtnXYZ = Instance.new("TextButton", DevPanel)
BtnXYZ.Size = UDim2.new(0.5, -15, 0, 30)
BtnXYZ.Position = UDim2.new(0, 10, 0, 45)
BtnXYZ.BackgroundColor3 = Theme.OffColor
BtnXYZ.Text = "XYZ"
BtnXYZ.TextColor3 = Theme.TextMain
BtnXYZ.Font = Enum.Font.GothamMedium
BtnXYZ.TextSize = 12
BtnXYZ.ZIndex = 71
Instance.new("UICorner", BtnXYZ).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", BtnXYZ).Color = Theme.Border

local BtnPath = Instance.new("TextButton", DevPanel)
BtnPath.Size = UDim2.new(0.5, -15, 0, 30)
BtnPath.Position = UDim2.new(0.5, 5, 0, 45)
BtnPath.BackgroundColor3 = Theme.OffColor
BtnPath.Text = "Пути"
BtnPath.TextColor3 = Theme.TextMain
BtnPath.Font = Enum.Font.GothamMedium
BtnPath.TextSize = 12
BtnPath.ZIndex = 71
Instance.new("UICorner", BtnPath).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", BtnPath).Color = Theme.Border

local XYZFrame = Instance.new("Frame", ScreenGui)
XYZFrame.Size = UDim2.new(0, 240, 0, 32)
XYZFrame.Position = UDim2.new(0.5, 0, 0, 10)
XYZFrame.AnchorPoint = Vector2.new(0.5, 0)
XYZFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
XYZFrame.BackgroundTransparency = 0.8
XYZFrame.BorderSizePixel = 0
XYZFrame.Visible = false
Instance.new("UICorner", XYZFrame).CornerRadius = UDim.new(0, 8)
local XYZStroke = Instance.new("UIStroke", XYZFrame)
XYZStroke.Thickness = 1
XYZStroke.Color = Color3.fromRGB(60, 60, 60)
XYZStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local XYZLabel = Instance.new("TextLabel", XYZFrame)
XYZLabel.Size = UDim2.new(1, 0, 1, 0)
XYZLabel.BackgroundTransparency = 1
XYZLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
XYZLabel.Font = Enum.Font.GothamBold
XYZLabel.TextSize = 13
XYZLabel.Text = "Загрузка..."

local xyzDragging, xyzDragInput, xyzDragStart, xyzStartPos
table.insert(scriptConnections, XYZFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        xyzDragging = true
        xyzDragStart = input.Position
        xyzStartPos = XYZFrame.Position
        table.insert(scriptConnections, input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                xyzDragging = false
            end
        end))
    end
end))
table.insert(scriptConnections, XYZFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        xyzDragInput = input
    end
end))
table.insert(scriptConnections, UserInputService.InputChanged:Connect(function(input)
    if input == xyzDragInput and xyzDragging then
        local delta = input.Position - xyzDragStart
        XYZFrame.Position = UDim2.new(xyzStartPos.X.Scale, xyzStartPos.X.Offset + delta.X, xyzStartPos.Y.Scale, xyzStartPos.Y.Offset + delta.Y)
    end
end))

local isXYZActive = false
BtnXYZ.MouseButton1Click:Connect(function()
    isXYZActive = not isXYZActive
    XYZFrame.Visible = isXYZActive
    BtnXYZ.BackgroundColor3 = isXYZActive and Theme.Accent or Theme.OffColor
    BtnXYZ.TextColor3 = isXYZActive and Color3.fromRGB(0,0,0) or Theme.TextMain
end)

local pathConnection
BtnPath.MouseButton1Click:Connect(function()
    if pathConnection then return end
    BtnPath.BackgroundColor3 = Theme.Accent
    BtnPath.TextColor3 = Color3.fromRGB(0,0,0)
    BtnPath.Text = "Waiting Click..."
    warn("скрипт запущен (Ожидание клика для Пути)")
    
    pathConnection = Mouse.Button1Down:Connect(function()
        local target = Mouse.Target
        if target then
            warn("--- ИНФОРМАЦИЯ ---")
            print("Название кликнутой детали:", target.Name)
            print("Полный путь:", target:GetFullName())
            
            local model = target:FindFirstAncestorOfClass("Model")
            if model then
                print("Название модели:", model.Name)
                if model.Parent then
                    print("Родительская папка:", model.Parent.Name)
                else
                    print("Родительская папка: (отсутствует)")
                end
            else
                print("Это не модель, просто отдельная деталь.")
            end
            warn("-------------------")
            
            if pathConnection then
                pathConnection:Disconnect()
                pathConnection = nil
            end
            BtnPath.BackgroundColor3 = Theme.OffColor
            BtnPath.TextColor3 = Theme.TextMain
            BtnPath.Text = "Пути"
        end
    end)
    table.insert(scriptConnections, pathConnection)
end)

table.insert(scriptConnections, RunService.RenderStepped:Connect(function()
    if not isXYZActive or not XYZFrame.Visible then return end
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local pos = hrp.Position
            XYZLabel.Text = string.format("X: %.1f  | Y: %.1f  |  Z: %.1f", pos.X, pos.Y, pos.Z)
        else
            XYZLabel.Text = "Ожидание RootPart..."
        end
    else
        XYZLabel.Text = "Персонаж не найден"
    end
end))

DevToolsBtn.MouseButton1Click:Connect(function()
    if devToolsUnlocked then
        DevPassModal.Visible = false
        DevPanel.Visible = true
    else
        DPInput.Text = ""
        DevPassModal.Visible = true
    end
end)

DPClose.MouseButton1Click:Connect(function()
    DevPassModal.Visible = false
end)

DPanelClose.MouseButton1Click:Connect(function()
    DevPanel.Visible = false
end)

DPInput:GetPropertyChangedSignal("Text"):Connect(function()
    if DPInput.Text == "2458" then
        devToolsUnlocked = true
        DevPassModal.Visible = false
        DevPanel.Visible = true
    end
end)

local HeaderTitle = Instance.new("TextLabel", Frame)
HeaderTitle.Size = UDim2.new(0.5, 0, 0, 40); HeaderTitle.Position = UDim2.new(0, 20, 0, 0)
HeaderTitle.BackgroundTransparency = 1; HeaderTitle.Text = "MENU"
HeaderTitle.TextColor3 = Theme.Accent
HeaderTitle.Font = Enum.Font.GothamBlack
HeaderTitle.TextSize = 20
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left

local HeaderSub = Instance.new("TextLabel", Frame)
HeaderSub.Size = UDim2.new(0.5, -20, 0, 40)
HeaderSub.Position = UDim2.new(0.5, 0, 0, 0)
HeaderSub.BackgroundTransparency = 1
HeaderSub.Text = "made by wihikk"
HeaderSub.TextColor3 = Theme.TextSub
HeaderSub.Font = Enum.Font.GothamMedium
HeaderSub.TextSize = 12
HeaderSub.TextXAlignment = Enum.TextXAlignment.Right

local TabContainer = Instance.new("Frame", Frame)
TabContainer.Size = UDim2.new(1, -40, 0, 30)
TabContainer.Position = UDim2.new(0, 20, 0, 40)
TabContainer.BackgroundTransparency = 1
local TabList = Instance.new("UIListLayout", TabContainer)
TabList.FillDirection = Enum.FillDirection.Horizontal
TabList.SortOrder = Enum.SortOrder.LayoutOrder
TabList.Padding = UDim.new(0, 20)

local Divider = Instance.new("Frame", Frame)
Divider.Size = UDim2.new(1, -40, 0, 1)
Divider.Position = UDim2.new(0, 20, 0, 75)
Divider.BackgroundColor3 = Theme.Border
Divider.BorderSizePixel = 0

local tabs = {}
local activePage = nil

local function createPage(name)
    local Page = Instance.new("Frame", Frame)
    Page.Name = name
    Page.Size = UDim2.new(1, 0, 1, -170)
    Page.Position = UDim2.new(0, 0, 0, 85)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    local Left = Instance.new("Frame", Page)
    Left.Size = UDim2.new(0.5, -25, 1, 0)
    Left.Position = UDim2.new(0, 20, 0, 0)
    Left.BackgroundTransparency = 1
    local LLayout = Instance.new("UIListLayout", Left)
    LLayout.SortOrder = Enum.SortOrder.LayoutOrder
    LLayout.Padding = UDim.new(0, 10)
    local Right = Instance.new("Frame", Page)
    Right.Size = UDim2.new(0.5, -25, 1, 0)
    Right.Position = UDim2.new(0.5, 5, 0, 0)
    Right.BackgroundTransparency = 1
    local RLayout = Instance.new("UIListLayout", Right)
    RLayout.SortOrder = Enum.SortOrder.LayoutOrder
    RLayout.Padding = UDim.new(0, 10)
    return Page, Left, Right
end

local function createTabButton(name, pageObject, isDefault)
    local Btn = Instance.new("TextButton", TabContainer)
    Btn.Size = UDim2.new(0, 70, 1, 0)
    Btn.BackgroundTransparency = 1
    Btn.Text = name
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 13
    Btn.TextColor3 = isDefault and Theme.Accent or Theme.TextSub
    local Indicator = Instance.new("Frame", Btn)
    Indicator.Size = UDim2.new(1, 0, 0, 2)
    Indicator.Position = UDim2.new(0, 0, 1, -2)
    Indicator.BackgroundColor3 = Theme.Accent
    Indicator.BorderSizePixel = 0
    Indicator.Visible = isDefault

    Btn.MouseButton1Click:Connect(function()
        if activePage == pageObject then return end
        isMiscPageOpen = (name == "Misc")
        local oldIdx, newIdx = 1, 1
        for i, tab in ipairs(tabs) do
            if tab.page == activePage then oldIdx = i end
            if tab.page == pageObject then newIdx = i end
        end
        local dir = (newIdx > oldIdx) and 1 or -1
        for _, tab in pairs(tabs) do tab.btn.TextColor3 = Theme.TextSub; tab.ind.Visible = false end
        Btn.TextColor3 = Theme.Accent
        Indicator.Visible = true
        local oldPage = activePage
        activePage = pageObject
        if oldPage then
            TweenService:Create(oldPage, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(-dir, 0, 0, 85)}):Play()
            task.delay(0.3, function() if activePage ~= oldPage then oldPage.Visible = false end end)
        end
        pageObject.Position = UDim2.new(dir, 0, 0, 85)
        pageObject.Visible = true
        TweenService:Create(pageObject, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 85)}):Play()
    end)
    table.insert(tabs, {btn = Btn, ind = Indicator, page = pageObject})
    if isDefault then 
        activePage = pageObject
        pageObject.Position = UDim2.new(0, 0, 0, 85)
        pageObject.Visible = true 
        isMiscPageOpen = (name == "Misc")
    end
end

local BottomPanel = Instance.new("Frame", Frame)
BottomPanel.Size = UDim2.new(1, -40, 0, 50)
BottomPanel.Position = UDim2.new(0, 20, 1, -85)
BottomPanel.BackgroundTransparency = 1
local BottomLayout = Instance.new("UIListLayout", BottomPanel)
BottomLayout.SortOrder = Enum.SortOrder.LayoutOrder
BottomLayout.Padding = UDim.new(0, 10)

local dragging, dragInput, dragStart, startPos
table.insert(scriptConnections, Frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = Frame.Position
        table.insert(scriptConnections, input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end))
    end
end))
table.insert(scriptConnections, Frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end))
table.insert(scriptConnections, UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        Frame.Position = newPos
        DevToolsBtn.Position = UDim2.new(0, newPos.X.Offset + 20, 0, newPos.Y.Offset - 35)
    end
end))

local devDragging, devDragInput, devDragStart, devStartPos
table.insert(scriptConnections, DevPanel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        devDragging = true
        devDragStart = input.Position
        devStartPos = DevPanel.Position
        table.insert(scriptConnections, input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then devDragging = false end end))
    end
end))
table.insert(scriptConnections, DevPanel.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then devDragInput = input end
end))
table.insert(scriptConnections, UserInputService.InputChanged:Connect(function(input)
    if input == devDragInput and devDragging then
        local delta = input.Position - devDragStart
        DevPanel.Position = UDim2.new(devStartPos.X.Scale, devStartPos.X.Offset + delta.X, devStartPos.Y.Scale, devStartPos.Y.Offset + delta.Y)
    end
end))

local function createGroup(parent)
    local Group = Instance.new("Frame", parent)
    Group.Size = UDim2.new(1, 0, 0, 0)
    Group.BackgroundColor3 = Theme.PanelBG; Group.BackgroundTransparency = Theme.PanelTrans
    Group.BorderSizePixel = 0
    Instance.new("UICorner", Group).CornerRadius = UDim.new(0, 10)
    local Stroke = Instance.new("UIStroke", Group)
    Stroke.Thickness = 1
    Stroke.Color = Theme.Border
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local Layout = Instance.new("UIListLayout", Group)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() Group.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y) end)
    task.defer(function() Group.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y) end)
    return Group
end

local function createToggle(name, parent, settingKey, callback)
    local Container = Instance.new("Frame", parent)
    Container.Size = UDim2.new(1, 0, 0, 38)
    Container.BackgroundTransparency = 1 
    local Label = Instance.new("TextLabel", Container)
    Label.Size = UDim2.new(0.65, 0, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Theme.TextMain
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local BtnBG = Instance.new("TextButton", Container)
    BtnBG.Size = UDim2.new(0, 42, 0, 22)
    BtnBG.AnchorPoint = Vector2.new(1, 0.5)
    BtnBG.Position = UDim2.new(1, -12, 0.5, 0)
    BtnBG.Text = ""
    BtnBG.AutoButtonColor = false
    BtnBG.BackgroundColor3 = settings[settingKey] and Theme.Accent or Theme.OffColor
    Instance.new("UICorner", BtnBG).CornerRadius = UDim.new(1, 0)
    
    local Indicator = Instance.new("Frame", BtnBG)
    Indicator.Size = UDim2.new(0, 16, 0, 16)
    Indicator.Position = settings[settingKey] and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    Indicator.BackgroundColor3 = settings[settingKey] and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(200, 200, 200)
    Instance.new("UICorner", Indicator).CornerRadius = UDim.new(1, 0)

    local function updateVisual(state)
        settings[settingKey] = state
        TweenService:Create(BtnBG, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = state and Theme.Accent or Theme.OffColor}):Play()
        TweenService:Create(Indicator, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = state and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(200, 200, 200)}):Play()
        if callback then callback(state) end
    end
    uiUpdaters[settingKey] = updateVisual
    BtnBG.MouseButton1Click:Connect(function() updateVisual(not settings[settingKey]) end)
    return Container
end

local function createSlider(name, parent, min, max, default, step, settingKey, callback)
    local Container = Instance.new("Frame", parent)
    Container.Size = UDim2.new(1, 0, 0, 52)
    Container.BackgroundTransparency = 1
    
    local Label = Instance.new("TextLabel", Container)
    Label.Size = UDim2.new(0.5, 0, 0, 20)
    Label.Position = UDim2.new(0, 12, 0, 6)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Theme.TextMain
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local ValueText = Instance.new("TextLabel", Container)
    ValueText.Size = UDim2.new(0.5, 0, 0, 20)
    ValueText.AnchorPoint = Vector2.new(1, 0)
    ValueText.Position = UDim2.new(1, -12, 0, 6)
    ValueText.BackgroundTransparency = 1
    ValueText.Text = tostring(default)
    ValueText.TextColor3 = Theme.Accent
    ValueText.Font = Enum.Font.GothamBold
    ValueText.TextSize = 13
    ValueText.TextXAlignment = Enum.TextXAlignment.Right
    
    local SliderBG = Instance.new("TextButton", Container)
    SliderBG.Size = UDim2.new(1, -24, 0, 6)
    SliderBG.AnchorPoint = Vector2.new(0.5, 0)
    SliderBG.Position = UDim2.new(0.5, 0, 0, 34)
    SliderBG.BackgroundColor3 = Theme.OffColor
    SliderBG.Text = ""
    SliderBG.AutoButtonColor = false
    Instance.new("UICorner", SliderBG).CornerRadius = UDim.new(1, 0)
    
    local SliderFill = Instance.new("Frame", SliderBG)
    SliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    SliderFill.BackgroundColor3 = Theme.Accent
    Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)
    
    local SliderThumb = Instance.new("Frame", SliderFill)
    SliderThumb.Size = UDim2.new(0, 12, 0, 12)
    SliderThumb.AnchorPoint = Vector2.new(0.5, 0.5)
    SliderThumb.Position = UDim2.new(1, 0, 0.5, 0)
    SliderThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", SliderThumb).CornerRadius = UDim.new(1, 0)

    local isDragging = false
    local function updateVisual(val)
        val = math.clamp(val, min, max)
        settings[settingKey] = val
        local snappedPos = (val - min) / (max - min)
        TweenService:Create(SliderFill, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(snappedPos, 0, 1, 0)}):Play()
        ValueText.Text = tostring(val)
        if callback then callback(val) end
    end
    uiUpdaters[settingKey] = updateVisual

    local function processInput(input)
        local rawPos = math.clamp((input.Position.X - SliderBG.AbsolutePosition.X) / SliderBG.AbsoluteSize.X, 0, 1)
        local rawVal = min + ((max - min) * rawPos)
        local val = math.floor(rawVal / step + 0.5) * step
        updateVisual(val)
    end
    
    table.insert(scriptConnections, SliderBG.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = true; processInput(input) end end))
    table.insert(scriptConnections, UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end end))
    table.insert(scriptConnections, UserInputService.InputChanged:Connect(function(input) if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then processInput(input) end end))
end

local function createActionButton(name, parent, callback)
    local Container = Instance.new("Frame", parent)
    Container.Size = UDim2.new(1, 0, 0, 38)
    Container.BackgroundTransparency = 1 
    local BtnBG = Instance.new("TextButton", Container)
    BtnBG.Size = UDim2.new(1, -24, 0, 26)
    BtnBG.AnchorPoint = Vector2.new(0.5, 0.5)
    BtnBG.Position = UDim2.new(0.5, 0, 0.5, 0)
    BtnBG.Text = name
    BtnBG.TextColor3 = Theme.TextMain
    BtnBG.Font = Enum.Font.GothamMedium
    BtnBG.TextSize = 13
    BtnBG.AutoButtonColor = false
    BtnBG.BackgroundColor3 = Theme.OffColor
    Instance.new("UICorner", BtnBG).CornerRadius = UDim.new(0, 6)
    local Stroke = Instance.new("UIStroke", BtnBG)
    Stroke.Color = Theme.Border
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    
    BtnBG.MouseButton1Click:Connect(function()
        TweenService:Create(BtnBG, TweenInfo.new(0.1), {BackgroundColor3 = Theme.Accent}):Play()
        task.delay(0.1, function() TweenService:Create(BtnBG, TweenInfo.new(0.2), {BackgroundColor3 = Theme.OffColor}):Play() end)
        callback()
    end)
end

local function createDualActionButtons(name1, name2, parent, cb1, cb2)
    local Container = Instance.new("Frame", parent)
    Container.Size = UDim2.new(1, 0, 0, 38)
    Container.BackgroundTransparency = 1 
    local function createBtn(name, xAnch, xPos, cb)
        local Btn = Instance.new("TextButton", Container)
        Btn.Size = UDim2.new(0.5, -16, 0, 26)
        Btn.AnchorPoint = Vector2.new(xAnch, 0.5)
        Btn.Position = UDim2.new(xAnch, xPos, 0.5, 0)
        Btn.Text = name
        Btn.TextColor3 = Theme.TextMain
        Btn.Font = Enum.Font.GothamMedium; Btn.TextSize = 12
        Btn.AutoButtonColor = false
        Btn.BackgroundColor3 = Theme.OffColor
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
        local Stroke = Instance.new("UIStroke", Btn)
        Stroke.Color = Theme.Border
        Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        Btn.MouseButton1Click:Connect(function()
            TweenService:Create(Btn, TweenInfo.new(0.1), {BackgroundColor3 = Theme.Accent}):Play()
            task.delay(0.1, function() TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.OffColor}):Play() end)
            cb()
        end)
    end
    createBtn(name1, 0, 12, cb1)
    createBtn(name2, 1, -12, cb2)
end

local function createSubGrid(parent)
    local Wrapper = Instance.new("Frame", parent)
    Wrapper.Size = UDim2.new(1, 0, 0, 60)
    Wrapper.BackgroundTransparency = 1
    local Padding = Instance.new("UIPadding", Wrapper)
    Padding.PaddingLeft = UDim.new(0, 10)
    Padding.PaddingRight = UDim.new(0, 10)
    Padding.PaddingBottom = UDim.new(0, 10)
    local UIGrid = Instance.new("UIGridLayout", Wrapper)
    UIGrid.CellSize = UDim2.new(0.48, 0, 0, 22)
    UIGrid.CellPadding = UDim2.new(0.04, 0, 0, 6)
    UIGrid.SortOrder = Enum.SortOrder.LayoutOrder
    return Wrapper
end

local function createSubButton(name, parent, settingKey, callback)
    local Btn = Instance.new("TextButton", parent)
    Btn.BackgroundColor3 = settings[settingKey] and Theme.Accent or Theme.OffColor
    Btn.TextColor3 = settings[settingKey] and Color3.fromRGB(0, 0, 0) or Theme.TextSub
    Btn.Font = Enum.Font.GothamMedium
    Btn.TextSize = 11
    Btn.Text = name
    Btn.AutoButtonColor = false
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
    
    local function updateVisual(state)
        settings[settingKey] = state
        TweenService:Create(Btn, TweenInfo.new(0.2), {BackgroundColor3 = state and Theme.Accent or Theme.OffColor, TextColor3 = state and Color3.fromRGB(0, 0, 0) or Theme.TextSub}):Play()
        if callback then callback(state) end
    end
    uiUpdaters[settingKey] = updateVisual
    Btn.MouseButton1Click:Connect(function() updateVisual(not settings[settingKey]) end)
end

local activeBindBtn = nil
local function createKeybind(name, parent, bindKey)
    local Container = Instance.new("Frame", parent)
    Container.Size = UDim2.new(1, 0, 0, 38)
    Container.BackgroundTransparency = 1 
    local Label = Instance.new("TextLabel", Container)
    Label.Size = UDim2.new(0.65, 0, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = name
    Label.TextColor3 = Theme.TextMain
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local BtnBG = Instance.new("TextButton", Container)
    BtnBG.Size = UDim2.new(0, 60, 0, 22)
    BtnBG.AnchorPoint = Vector2.new(1, 0.5)
    BtnBG.Position = UDim2.new(1, -12, 0.5, 0)
    BtnBG.Text = settings.binds[bindKey] and settings.binds[bindKey].Name or "None"
    BtnBG.TextColor3 = Theme.TextSub
    BtnBG.Font = Enum.Font.GothamBold
    BtnBG.TextSize = 11
    BtnBG.AutoButtonColor = false
    BtnBG.BackgroundColor3 = Theme.OffColor
    Instance.new("UICorner", BtnBG).CornerRadius = UDim.new(0, 6)
    local Stroke = Instance.new("UIStroke", BtnBG)
    Stroke.Color = Theme.Border
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local function updateVisual() BtnBG.Text = settings.binds[bindKey] and settings.binds[bindKey].Name or "None" end
    uiUpdaters["bind_"..bindKey] = updateVisual
    BtnBG.MouseButton1Click:Connect(function() BtnBG.Text = "..."; activeBindBtn = {btn = BtnBG, key = bindKey} end)
end

local function createTextBox(placeholder, parent, callback)
    local Container = Instance.new("Frame", parent)
    Container.Size = UDim2.new(1, 0, 0, 38)
    Container.BackgroundTransparency = 1 
    local Box = Instance.new("TextBox", Container)
    Box.Size = UDim2.new(1, -24, 0, 26)
    Box.AnchorPoint = Vector2.new(0.5, 0.5)
    Box.Position = UDim2.new(0.5, 0, 0.5, 0)
    Box.PlaceholderText = placeholder
    Box.Text = ""
    Box.TextColor3 = Theme.TextMain
    Box.PlaceholderColor3 = Theme.TextSub
    Box.Font = Enum.Font.GothamMedium
    Box.TextSize = 12
    Box.BackgroundColor3 = Theme.OffColor
    Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 6)
    local Stroke = Instance.new("UIStroke", Box)
    Stroke.Color = Theme.Border
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Box.FocusLost:Connect(function() callback(Box.Text) end)
    return Box
end

local PageCombat, CombatLeft, CombatRight = createPage("Combat")
local PageVisuals, VisualsLeft, VisualsRight = createPage("Visuals")
local PageAuto, AutoLeft, AutoRight = createPage("Auto")
local PageMisc, MiscLeft, MiscRight = createPage("Misc")

createTabButton("Combat", PageCombat, true)
createTabButton("Visuals", PageVisuals, false)
createTabButton("Auto", PageAuto, false)
createTabButton("Misc", PageMisc, false)

local AimbotGroup = createGroup(CombatLeft)
createToggle("Aimbot (RMB)", AimbotGroup, "aimbot")
createToggle("Wall Check", AimbotGroup, "wallCheck")
createSlider("Aimbot FOV", AimbotGroup, 20, 400, settings.fov, 5, "fov")
createSlider("Smoothness", AimbotGroup, 0, 100, settings.smoothness, 5, "smoothness")
createToggle("Predict", AimbotGroup, "predict")
createSlider("Predict Strength", AimbotGroup, 1, 100, settings.predictStrength, 1, "predictStrength")

local MovementGroup = createGroup(CombatRight)
createToggle("Noclip", MovementGroup, "noclip")
createToggle("Fly", MovementGroup, "fly")
createSlider("Fly Speed", MovementGroup, 5, 2000, settings.flySpeed, 5, "flySpeed")

local MiscCombatGroup = createGroup(CombatRight)
createToggle("Click TP (LMB)", MiscCombatGroup, "clickTp")
createDualActionButtons("TP to Base", "TP to Capture", MiscCombatGroup, 
    function() if baseSpawnCFrame and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then LocalPlayer.Character.HumanoidRootPart.CFrame = baseSpawnCFrame end end,
    function() if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-503, 177, -1021) end end
)

local EspGroup = createGroup(VisualsLeft)
createToggle("Player ESP", EspGroup, "esp")
local EspGrid = createSubGrid(EspGroup)
createSubButton("Boxes", EspGrid, "espBoxes")
createSubButton("Health", EspGrid, "espHealth")
createSubButton("Distance", EspGrid, "espDist")
createSubButton("Names", EspGrid, "espNames")
createToggle("Tracers", EspGroup, "tracers")

local EnvGroup = createGroup(VisualsRight)
local vehicleToggle = createToggle("Vehicle ESP", EnvGroup, "vehicleEsp", function(v)
    if not v then
        for _, draw in pairs(vehicleDrawings) do
            safeRemoveDrawing(draw.box)
            safeRemoveDrawing(draw.text)
        end
        table.clear(vehicleDrawings)
        table.clear(vehicles)
    end
end)

local waitLabel = Instance.new("TextLabel", vehicleToggle)
waitLabel.Size = UDim2.new(0, 100, 1, 0)
waitLabel.AnchorPoint = Vector2.new(1, 0.5)
waitLabel.Position = UDim2.new(1, -62, 0.5, 0)
waitLabel.BackgroundTransparency = 1
waitLabel.Text = "wait ≈3 sec"
waitLabel.TextColor3 = Theme.TextSub
waitLabel.Font = Enum.Font.Gotham
waitLabel.TextSize = 10
waitLabel.TextXAlignment = Enum.TextXAlignment.Right

createToggle("Submarine ESP", EnvGroup, "submarineEsp", function(v)
    if not v then
        for _, draw in pairs(subDrawings) do safeRemoveDrawing(draw.box); safeRemoveDrawing(draw.text) end
    end
end)
createToggle("UAV ESP", EnvGroup, "uavEsp", function(v)
    if not v then
        for _, draw in pairs(uavDrawings) do safeRemoveDrawing(draw.box); safeRemoveDrawing(draw.text) end
    end
end)
createToggle("UGV ESP", EnvGroup, "ugvEsp", function(v)
    if not v then
        for _, draw in pairs(ugvDrawings) do safeRemoveDrawing(draw.box); safeRemoveDrawing(draw.text) end
    end
end)

local autoDroneOriginalPos = nil

local AutoFarmGroup = createGroup(AutoLeft)
createToggle("Auto Airdrop", AutoFarmGroup, "autoAirdrop")

local ADContainer = createToggle("Auto Drone", AutoFarmGroup, "autoDrone", function(state)
    if not state and autoDroneOriginalPos and not isLoadingConfig then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        
        if hrp and hum and hum.Health > 0 then
            local bestCollector = nil
            local bestDist = math.huge
            local baseCF = baseSpawnCFrame or CFrame.new(-503, 177, -1021)
            
            hrp.CFrame = baseCF
            task.wait(0.1)
            
            local tycoons = findChildLower(findChildLower(workspace, "tycoon"), "tycoons")
            if tycoons then
                for _, teamTycoon in ipairs(tycoons:GetChildren()) do
                    local po = findChildLower(teamTycoon, "purchasedobjects")
                    local lab = findChildLower(po, "lab terminal screen")
                    local research = findChildLower(lab, "research screen") or findChildLower(lab, "research")
                    local persistent = findChildLower(research, "persistent")
                    local collector = findChildLower(persistent, "collector")
                    
                    if collector and collector:IsA("BasePart") then
                        local dist = (collector.Position - baseCF.Position).Magnitude
                        if dist < bestDist then
                            bestDist = dist
                            bestCollector = collector
                        end
                    end
                end
            end
            
            if bestCollector then
                task.spawn(function()
                    hrp.Anchored = true
                    local targetColCF = bestCollector.CFrame + Vector3.new(0, 3, 0)
                    local flyTween = TweenService:Create(hrp, TweenInfo.new(20, Enum.EasingStyle.Linear), {CFrame = targetColCF})
                    table.insert(activeTweens, flyTween)
                    
                    task.spawn(function()
                        TpWarningLabel.Visible = true
                        task.wait(10)
                        if TpWarningLabel then TpWarningLabel.Visible = false end
                    end)
                    
                    flyTween:Play()
                    
                    while flyTween.PlaybackState == Enum.PlaybackState.Playing do
                        if not isScriptActive then break end
                        task.wait(0.1)
                    end
                    
                    if hrp and isScriptActive then
                        hrp.Anchored = false
                        task.wait(0.5) 
                        if hrp and isScriptActive then
                            local baseReturnCF = baseSpawnCFrame or CFrame.new(-503, 177, -1021)
                            hrp.CFrame = baseReturnCF
                            hrp.Velocity = Vector3.new(0, 0, 0)
                        end
                    end
                end)
            else
                hrp.CFrame = baseSpawnCFrame or CFrame.new(-503, 177, -1021)
                hrp.Velocity = Vector3.new(0, 0, 0)
            end
        end
        autoDroneOriginalPos = nil
    end
end)

local DroneModal = Instance.new("Frame", ScreenGui)
DroneModal.Size = UDim2.new(1, 0, 1, 0)
DroneModal.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
DroneModal.BackgroundTransparency = 0.6
DroneModal.ZIndex = 80
DroneModal.Visible = false

local DroneWindow = Instance.new("Frame", DroneModal)
DroneWindow.Size = UDim2.new(0, 0, 0, 0)
DroneWindow.AnchorPoint = Vector2.new(0.5, 0.5)
DroneWindow.Position = UDim2.new(0.5, 0, 0.5, 0)
DroneWindow.BackgroundColor3 = Theme.PanelBG
DroneWindow.ClipsDescendants = true
DroneWindow.ZIndex = 81
Instance.new("UICorner", DroneWindow).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", DroneWindow).Color = Theme.Border

local DroneText = Instance.new("TextLabel", DroneWindow)
DroneText.Size = UDim2.new(1, -20, 1, -50)
DroneText.Position = UDim2.new(0, 10, 0, 10)
DroneText.BackgroundTransparency = 1
DroneText.Text = "works only 1 time, next time u get kicked idk how to bypass it :c"
DroneText.TextColor3 = Theme.Accent
DroneText.TextWrapped = true
DroneText.Font = Enum.Font.GothamMedium
DroneText.TextSize = 13
DroneText.ZIndex = 82

local DroneIdcBtn = Instance.new("TextButton", DroneWindow)
DroneIdcBtn.Size = UDim2.new(0, 100, 0, 26)
DroneIdcBtn.AnchorPoint = Vector2.new(0.5, 1)
DroneIdcBtn.Position = UDim2.new(0.5, 0, 1, -10)
DroneIdcBtn.BackgroundColor3 = Theme.OffColor
DroneIdcBtn.Text = "idc"
DroneIdcBtn.TextColor3 = Theme.TextMain
DroneIdcBtn.Font = Enum.Font.GothamMedium
DroneIdcBtn.TextSize = 12
DroneIdcBtn.ZIndex = 82
Instance.new("UICorner", DroneIdcBtn).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", DroneIdcBtn).Color = Theme.Border

task.wait(10)

DroneIdcBtn.MouseButton1Click:Connect(function()
    local tw = TweenService:Create(DroneWindow, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
    table.insert(activeTweens, tw)
    tw:Play()
    tw.Completed:Wait()
    DroneModal.Visible = false
end)

local InfoBtn = Instance.new("TextButton", ADContainer)
InfoBtn.Size = UDim2.new(0, 20, 0, 20)
InfoBtn.AnchorPoint = Vector2.new(1, 0.5)
InfoBtn.Position = UDim2.new(1, -64, 0.5, 0)
InfoBtn.BackgroundColor3 = Theme.OffColor
InfoBtn.Text = "i"
InfoBtn.TextColor3 = Theme.Accent
InfoBtn.Font = Enum.Font.GothamBold
InfoBtn.TextSize = 12
Instance.new("UICorner", InfoBtn).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", InfoBtn).Color = Theme.Border

InfoBtn.MouseButton1Click:Connect(function()
    DroneModal.Visible = true
    DroneWindow.Size = UDim2.new(0, 0, 0, 0)
    local tw = TweenService:Create(DroneWindow, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 260, 0, 140)})
    table.insert(activeTweens, tw)
    tw:Play()
end)

local BindsGroup = createGroup(MiscLeft)
createKeybind("Aimbot Bind", BindsGroup, "aimbot")
createKeybind("Fly Bind", BindsGroup, "fly")
createKeybind("Noclip Bind", BindsGroup, "noclip")
createKeybind("Click TP Bind", BindsGroup, "clickTp")

local ConfigGroup = createGroup(MiscRight)
local currentConfigName = "default"

pcall(function()
    if readfile and isfile and isfile("Wihikk_Favorites.json") then
        favorites = HttpService:JSONDecode(readfile("Wihikk_Favorites.json")) or {}
    end
end)
local function saveFavorites()
    pcall(function() writefile("Wihikk_Favorites.json", HttpService:JSONEncode(favorites)) end)
end

local ConfigTextBox = createTextBox("Config Name...", ConfigGroup, function(txt) if txt ~= "" then currentConfigName = txt end end)

local targetRenameCfg = ""

local RenameModal = Instance.new("Frame", Frame)
RenameModal.Size = UDim2.new(1, 0, 1, 0)
RenameModal.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
RenameModal.BackgroundTransparency = 0.6
RenameModal.ZIndex = 50
RenameModal.Visible = false
RenameModal.Active = true

local RenameWindow = Instance.new("Frame", RenameModal)
RenameWindow.Size = UDim2.new(0, 260, 0, 130)
RenameWindow.AnchorPoint = Vector2.new(0.5, 0.5)
RenameWindow.Position = UDim2.new(0.5, 0, 0.5, 0)
RenameWindow.BackgroundColor3 = Theme.PanelBG
RenameWindow.ZIndex = 51
Instance.new("UICorner", RenameWindow).CornerRadius = UDim.new(0, 10)
local RStroke = Instance.new("UIStroke", RenameWindow)
RStroke.Color = Theme.Border
RStroke.Thickness = 1

local RTitle = Instance.new("TextLabel", RenameWindow)
RTitle.Size = UDim2.new(1, 0, 0, 30)
RTitle.Position = UDim2.new(0, 0, 0, 5)
RTitle.BackgroundTransparency = 1
RTitle.Text = "Rename Config"
RTitle.TextColor3 = Theme.Accent
RTitle.Font = Enum.Font.GothamBold; RTitle.TextSize = 14
RTitle.ZIndex = 52

local RInput = Instance.new("TextBox", RenameWindow)
RInput.Size = UDim2.new(1, -30, 0, 30)
RInput.Position = UDim2.new(0, 15, 0, 40)
RInput.BackgroundColor3 = Theme.OffColor
RInput.Text = ""
RInput.TextColor3 = Theme.TextMain
RInput.Font = Enum.Font.GothamMedium
RInput.TextSize = 12
RInput.ZIndex = 52
Instance.new("UICorner", RInput).CornerRadius = UDim.new(0, 6)
local RIStroke = Instance.new("UIStroke", RInput)
RIStroke.Color = Theme.Border
RIStroke.Thickness = 1

local RWarning = Instance.new("TextLabel", RenameWindow)
RWarning.Size = UDim2.new(1, 0, 0, 20)
RWarning.Position = UDim2.new(0, 0, 0, 70)
RWarning.BackgroundTransparency = 1
RWarning.Text = "названия одинаковые"
RWarning.TextColor3 = Color3.fromRGB(255, 80, 80)
RWarning.Font = Enum.Font.Gotham
RWarning.TextSize = 11
RWarning.ZIndex = 52
RWarning.Visible = false

local RCancelBtn = Instance.new("TextButton", RenameWindow)
RCancelBtn.Size = UDim2.new(0.5, -20, 0, 26)
RCancelBtn.Position = UDim2.new(0, 15, 1, -36)
RCancelBtn.BackgroundColor3 = Theme.OffColor
RCancelBtn.Text = "Cancel"
RCancelBtn.TextColor3 = Theme.TextMain
RCancelBtn.Font = Enum.Font.GothamMedium
RCancelBtn.TextSize = 12
RCancelBtn.ZIndex = 52
Instance.new("UICorner", RCancelBtn).CornerRadius = UDim.new(0, 6)
local RCStroke = Instance.new("UIStroke", RCancelBtn)
RCStroke.Color = Theme.Border
RCStroke.Thickness = 1

local RChangeBtn = Instance.new("TextButton", RenameWindow)
RChangeBtn.Size = UDim2.new(0.5, -20, 0, 26)
RChangeBtn.Position = UDim2.new(0.5, 5, 1, -36)
RChangeBtn.BackgroundColor3 = Theme.OffColor
RChangeBtn.Text = "Change"
RChangeBtn.TextColor3 = Theme.TextSub
RChangeBtn.Font = Enum.Font.GothamBold
RChangeBtn.TextSize = 12
RChangeBtn.ZIndex = 52
Instance.new("UICorner", RChangeBtn).CornerRadius = UDim.new(0, 6)

local function refreshConfigs(forceRefresh) end

RInput:GetPropertyChangedSignal("Text"):Connect(function()
    local txt = RInput.Text
    if txt == targetRenameCfg then
        RWarning.Text = "names are same"
        RWarning.Visible = true
        RChangeBtn.TextColor3 = Theme.TextSub
        RChangeBtn.BackgroundColor3 = Theme.OffColor
    elseif txt == "" then
        RWarning.Text = "it cant be empty"
        RWarning.Visible = true
        RChangeBtn.TextColor3 = Theme.TextSub
        RChangeBtn.BackgroundColor3 = Theme.OffColor
    else
        RWarning.Visible = false
        RChangeBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
        RChangeBtn.BackgroundColor3 = Theme.Accent
    end
end)

RChangeBtn.MouseButton1Click:Connect(function()
    local newName = RInput.Text
    if newName == "" or newName == targetRenameCfg then return end

    pcall(function()
        if readfile and writefile and delfile then
            local oldData = readfile("WihikkCfg_"..targetRenameCfg..".json")
            writefile("WihikkCfg_"..newName..".json", oldData)
            delfile("WihikkCfg_"..targetRenameCfg..".json")
            
            if favorites[targetRenameCfg] ~= nil then
                favorites[newName] = favorites[targetRenameCfg]
                favorites[targetRenameCfg] = nil
                saveFavorites()
            end
            
            if currentConfigName == targetRenameCfg then
                currentConfigName = newName
                if ConfigTextBox then ConfigTextBox.Text = newName end
            end
        end
    end)
    RenameModal.Visible = false
    refreshConfigs(true)
end)

RCancelBtn.MouseButton1Click:Connect(function()
    RenameModal.Visible = false
end)

createDualActionButtons("Save Config", "Load Config", ConfigGroup, 
    function()
        if writefile then
            local toSave = { __timestamp = os.time() }
            for k, v in pairs(settings) do
                if k == "binds" then
                    toSave.binds = {}
                    for bk, bv in pairs(v) do toSave.binds[bk] = bv and bv.Name or nil end
                else toSave[k] = v end
            end
            pcall(function() writefile("WihikkCfg_"..currentConfigName..".json", HttpService:JSONEncode(toSave)) end)
            refreshConfigs(true)
        end
    end,
    function()
        if readfile and isfile then
            pcall(function()
                if isfile("WihikkCfg_"..currentConfigName..".json") then
                    isLoadingConfig = true
                    local decoded = HttpService:JSONDecode(readfile("WihikkCfg_"..currentConfigName..".json"))
                    for k, v in pairs(decoded) do
                        if k == "binds" then
                            for bindK, bindV in pairs(v) do
                                settings.binds[bindK] = bindV and Enum.KeyCode[bindV] or nil
                                if uiUpdaters["bind_"..bindK] then uiUpdaters["bind_"..bindK]() end
                            end
                        elseif k ~= "__timestamp" then
                            if uiUpdaters[k] then uiUpdaters[k](v) else settings[k] = v end
                        end
                    end
                    isLoadingConfig = false
                end
            end)
            isLoadingConfig = false
        end
    end
)

local ConfigListWrapper = Instance.new("Frame", ConfigGroup)
ConfigListWrapper.Size = UDim2.new(1, 0, 0, 140)
ConfigListWrapper.BackgroundTransparency = 1

local ConfigList = Instance.new("ScrollingFrame", ConfigListWrapper)
ConfigList.Size = UDim2.new(1, -24, 1, -10)
ConfigList.Position = UDim2.new(0, 12, 0, 5)
ConfigList.BackgroundColor3 = Theme.OffColor
ConfigList.BorderSizePixel = 0
ConfigList.ScrollBarThickness = 4
Instance.new("UICorner", ConfigList).CornerRadius = UDim.new(0, 6)

local CListLayout = Instance.new("UIListLayout", ConfigList)
CListLayout.Padding = UDim.new(0, 4)
CListLayout.SortOrder = Enum.SortOrder.LayoutOrder
CListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() ConfigList.CanvasSize = UDim2.new(0, 0, 0, CListLayout.AbsoluteContentSize.Y + 10) end)

local lastConfigsHash = ""

refreshConfigs = function(forceRefresh)
    if not listfiles then return end
    pcall(function()
        local files = listfiles("")
        local cfgNames = {}
        local cfgDataCache = {}
        for _, file in ipairs(files) do
            local cfgName = file:match("WihikkCfg_(.*)%.json")
            if cfgName then 
                table.insert(cfgNames, cfgName) 
                pcall(function()
                    local decoded = HttpService:JSONDecode(readfile(file))
                    cfgDataCache[cfgName] = decoded.__timestamp or 0
                end)
            end
        end
        
        table.sort(cfgNames, function(a, b)
            local aFav = favorites[a] or false
            local bFav = favorites[b] or false
            if aFav == bFav then 
                return (cfgDataCache[a] or 0) > (cfgDataCache[b] or 0)
            end
            return aFav and not bFav
        end)
        
        local currentHash = table.concat(cfgNames, "|")
        if not forceRefresh and currentHash == lastConfigsHash then return end
        lastConfigsHash = currentHash
        
        for _, child in ipairs(ConfigList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
        
        for _, cfgName in ipairs(cfgNames) do
            local isFav = favorites[cfgName] or false
            local Item = Instance.new("Frame", ConfigList)
            Item.Size = UDim2.new(1, -8, 0, 26)
            Item.Position = UDim2.new(0, 4, 0, 0)
            Item.BackgroundColor3 = Theme.PanelBG
            Instance.new("UICorner", Item).CornerRadius = UDim.new(0, 4)
            
            local SelectBtn = Instance.new("TextButton", Item)
            SelectBtn.Size = UDim2.new(1, -90, 1, 0)
            SelectBtn.BackgroundTransparency = 1
            SelectBtn.Text = "  " .. cfgName
            SelectBtn.TextColor3 = Theme.TextMain
            SelectBtn.Font = Enum.Font.GothamMedium
            SelectBtn.TextSize = 11
            SelectBtn.TextXAlignment = Enum.TextXAlignment.Left
            
            local EditBtn = Instance.new("TextButton", Item)
            EditBtn.Size = UDim2.new(0, 26, 0, 26)
            EditBtn.Position = UDim2.new(1, -86, 0, 0)
            EditBtn.BackgroundTransparency = 1
            EditBtn.Text = "✏"
            EditBtn.Font = Enum.Font.GothamBold
            EditBtn.TextSize = 13
            EditBtn.TextColor3 = Theme.TextSub
            
            local FavBtn = Instance.new("TextButton", Item)
            FavBtn.Size = UDim2.new(0, 26, 0, 26)
            FavBtn.Position = UDim2.new(1, -56, 0, 0)
            FavBtn.BackgroundTransparency = 1
            FavBtn.Text = "★"
            FavBtn.Font = Enum.Font.GothamBold
            FavBtn.TextSize = 14
            FavBtn.TextColor3 = isFav and Color3.fromRGB(255, 215, 0) or Theme.TextSub
            
            local DelBtn = Instance.new("TextButton", Item)
            DelBtn.Size = UDim2.new(0, 26, 0, 26)
            DelBtn.Position = UDim2.new(1, -26, 0, 0)
            DelBtn.BackgroundTransparency = 1
            DelBtn.Text = "X"
            DelBtn.Font = Enum.Font.GothamBold
            DelBtn.TextSize = 12
            DelBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
            
            SelectBtn.MouseButton1Click:Connect(function()
                currentConfigName = cfgName
                if ConfigTextBox then ConfigTextBox.Text = cfgName end
            end)
            
            EditBtn.MouseButton1Click:Connect(function()
                targetRenameCfg = cfgName
                RInput.Text = cfgName
                RWarning.Visible = false
                RenameModal.Visible = true
            end)
            
            FavBtn.MouseButton1Click:Connect(function()
                favorites[cfgName] = not favorites[cfgName]
                saveFavorites()
                refreshConfigs(true)
            end)
            
            DelBtn.MouseButton1Click:Connect(function()
                if delfile and isfile and isfile("WihikkCfg_"..cfgName..".json") then
                    pcall(function() delfile("WihikkCfg_"..cfgName..".json") end)
                    favorites[cfgName] = nil
                    saveFavorites()
                    refreshConfigs(true)
                end
            end)
        end
    end)
end
createActionButton("Refresh Config List", ConfigGroup, function() refreshConfigs(true) end)

task.spawn(function()
    while isScriptActive do
        task.wait(2)
        if isMiscPageOpen then
            pcall(function() refreshConfigs(false) end)
        end
    end
end)

local ServerGroup = createGroup(BottomPanel)
local CenterContainer = Instance.new("Frame", ServerGroup)
CenterContainer.Size = UDim2.new(1, 0, 0, 38)
CenterContainer.BackgroundTransparency = 1

local BtnRejoin = Instance.new("TextButton", CenterContainer)
BtnRejoin.Size = UDim2.new(0.4, 0, 0, 26)
BtnRejoin.AnchorPoint = Vector2.new(1, 0.5)
BtnRejoin.Position = UDim2.new(0.5, -5, 0.5, 0)
BtnRejoin.Text = "Rejoin"
BtnRejoin.TextColor3 = Theme.TextMain
BtnRejoin.Font = Enum.Font.GothamMedium
BtnRejoin.TextSize = 12; BtnRejoin.AutoButtonColor = false
BtnRejoin.BackgroundColor3 = Theme.OffColor
Instance.new("UICorner", BtnRejoin).CornerRadius = UDim.new(0, 6)
local StrokeRejoin = Instance.new("UIStroke", BtnRejoin)
StrokeRejoin.Color = Theme.Border
StrokeRejoin.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

BtnRejoin.MouseButton1Click:Connect(function()
    TweenService:Create(BtnRejoin, TweenInfo.new(0.1), {BackgroundColor3 = Theme.Accent}):Play()
    task.delay(0.1, function() TweenService:Create(BtnRejoin, TweenInfo.new(0.2), {BackgroundColor3 = Theme.OffColor}):Play() end)
    if #Players:GetPlayers() <= 1 then TeleportService:Teleport(game.PlaceId, LocalPlayer) else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end
end)

local BtnHop = Instance.new("TextButton", CenterContainer)
BtnHop.Size = UDim2.new(0.4, 0, 0, 26)
BtnHop.AnchorPoint = Vector2.new(0, 0.5)
BtnHop.Position = UDim2.new(0.5, 5, 0.5, 0)
BtnHop.Text = "Server Hop"
BtnHop.TextColor3 = Theme.TextMain
BtnHop.Font = Enum.Font.GothamMedium
BtnHop.TextSize = 12; BtnHop.AutoButtonColor = false
BtnHop.BackgroundColor3 = Theme.OffColor
Instance.new("UICorner", BtnHop).CornerRadius = UDim.new(0, 6)
local StrokeHop = Instance.new("UIStroke", BtnHop)
StrokeHop.Color = Theme.Border
StrokeHop.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

BtnHop.MouseButton1Click:Connect(function()
    TweenService:Create(BtnHop, TweenInfo.new(0.1), {BackgroundColor3 = Theme.Accent}):Play()
    task.delay(0.1, function() TweenService:Create(BtnHop, TweenInfo.new(0.2), {BackgroundColor3 = Theme.OffColor}):Play() end)
    pcall(function()
        local response = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100")
        if response then
            local data = HttpService:JSONDecode(response)
            local validServers = {}
            if data and data.data then
                for _, server in ipairs(data.data) do if server.playing < server.maxPlayers and server.id ~= game.JobId then table.insert(validServers, server.id) end end
            end
            if #validServers > 0 then TeleportService:TeleportToPlaceInstance(game.PlaceId, validServers[math.random(1, #validServers)], LocalPlayer) return end
        end
    end)
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end)

local Footer = Instance.new("TextLabel", Frame)
Footer.Size = UDim2.new(0, 110, 0, 20)
Footer.Position = UDim2.new(0, 20, 1, -25)
Footer.BackgroundTransparency = 1
Footer.Text = "[K] - Hide Menu"
Footer.TextColor3 = Theme.TextSub
Footer.Font = Enum.Font.GothamMedium
Footer.TextSize = 11
Footer.TextXAlignment = Enum.TextXAlignment.Left

local BtnHide = Instance.new("TextButton", Frame)
BtnHide.Size = UDim2.new(0, 95, 0, 20)
BtnHide.AnchorPoint = Vector2.new(1, 0)
BtnHide.Position = UDim2.new(0.5, -5, 1, -25)
BtnHide.BackgroundColor3 = Theme.OffColor
BtnHide.Text = "Hide Menu"
BtnHide.TextColor3 = Theme.TextMain
BtnHide.Font = Enum.Font.GothamMedium
BtnHide.TextSize = 10
BtnHide.AutoButtonColor = false
Instance.new("UICorner", BtnHide).CornerRadius = UDim.new(0, 4)
local StrokeHide = Instance.new("UIStroke", BtnHide)
StrokeHide.Color = Theme.Border
StrokeHide.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

BtnHide.MouseButton1Click:Connect(function()
    guiVisible = false
    Frame.Visible = false
    DevToolsBtn.Visible = false
end)

local BtnUnload = Instance.new("TextButton", Frame)
BtnUnload.Size = UDim2.new(0, 95, 0, 20)
BtnUnload.AnchorPoint = Vector2.new(0, 0)
BtnUnload.Position = UDim2.new(0.5, 5, 1, -25)
BtnUnload.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
BtnUnload.Text = "Unload Script"
BtnUnload.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnUnload.Font = Enum.Font.GothamMedium
BtnUnload.TextSize = 10
BtnUnload.AutoButtonColor = false
Instance.new("UICorner", BtnUnload).CornerRadius = UDim.new(0, 4)
local StrokeUnload = Instance.new("UIStroke", BtnUnload)
StrokeUnload.Color = Theme.Border
StrokeUnload.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

BtnUnload.MouseButton1Click:Connect(function()
    UnloadScript()
end)

local FooterUnload = Instance.new("TextLabel", Frame)
FooterUnload.Size = UDim2.new(0, 130, 0, 20)
FooterUnload.AnchorPoint = Vector2.new(1, 0)
FooterUnload.Position = UDim2.new(1, -20, 1, -25)
FooterUnload.BackgroundTransparency = 1
FooterUnload.Text = "[Delete] - Unload Script"
FooterUnload.TextColor3 = Theme.TextSub
FooterUnload.Font = Enum.Font.GothamMedium
FooterUnload.TextSize = 11
FooterUnload.TextXAlignment = Enum.TextXAlignment.Right

local guiVisible = false

local sysCache = { subs = {}, uavs = {}, ugvs = {} }
local lastSysCheck = 0
local targetFps = 60
local frameDelay = 1 / targetFps
local lastFrameTime = 0

local function UnloadScript()
    isScriptActive = false 
    for _, connection in pairs(scriptConnections) do pcall(function() connection:Disconnect() end) end
    table.clear(scriptConnections)
    
    for _, tw in ipairs(activeTweens) do pcall(function() tw:Cancel() end) end
    table.clear(activeTweens)
    
    safeRemoveDrawing(FOVring)
    
    local function cleanDrawings(tbl)
        for k, v in pairs(tbl) do
            if type(v) == "table" then for _, d in pairs(v) do safeRemoveDrawing(d) end else safeRemoveDrawing(v) end
        end
        table.clear(tbl)
    end
    
    cleanDrawings(espObjects)
    cleanDrawings(tracerObjects)
    cleanDrawings(vehicleDrawings); cleanDrawings(subDrawings)
    cleanDrawings(uavDrawings); cleanDrawings(ugvDrawings)
    
    table.clear(droneInteractions)
    table.clear(vehicles)
    table.clear(uiUpdaters)
    table.clear(favorites)
    table.clear(sysCache.subs)
    table.clear(sysCache.uavs)
    table.clear(sysCache.ugvs)
    
    pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
    
    if LoadingGui then pcall(function() LoadingGui:Destroy() end) end
    if ScreenGui then pcall(function() ScreenGui:Destroy() end) end
    if StatsGui then pcall(function() StatsGui:Destroy() end) end
    
    if LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Anchored = false
            local f = {"FlyBV", "FlyBG"}
            for _, name in pairs(f) do if hrp:FindFirstChild(name) then hrp[name]:Destroy() end end
        end
        
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum and wasNoclip then hum:ChangeState(Enum.HumanoidStateType.Landed) end
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        end
    end
end

table.insert(scriptConnections, UserInputService.InputBegan:Connect(function(input, gpe)
    if activeBindBtn then
        if input.KeyCode == Enum.KeyCode.Escape then settings.binds[activeBindBtn.key] = nil
        elseif input.KeyCode ~= Enum.KeyCode.Unknown then settings.binds[activeBindBtn.key] = input.KeyCode end
        if uiUpdaters["bind_"..activeBindBtn.key] then uiUpdaters["bind_"..activeBindBtn.key]() end
        activeBindBtn = nil
        return
    end

    if not gpe then
        for key, bindCode in pairs(settings.binds) do
            if input.KeyCode == bindCode and uiUpdaters[key] then uiUpdaters[key](not settings[key]) end
        end
        if input.KeyCode == Enum.KeyCode.K and isLoaded then 
            guiVisible = not guiVisible
            Frame.Visible = guiVisible 
            DevToolsBtn.Visible = guiVisible
        end
        if input.KeyCode == Enum.KeyCode.Delete then UnloadScript() end
        if input.UserInputType == Enum.UserInputType.MouseButton1 and settings.clickTp then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0)) end
        end
    end
end))

local function checkVisibility(targetChar)
    local head = targetChar:FindFirstChild("Head")
    if not head then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, targetChar}
    params.IgnoreWater = true
    return not workspace:Raycast(Camera.CFrame.Position, head.Position - Camera.CFrame.Position, params)
end

table.insert(scriptConnections, RunService.Stepped:Connect(function()
    if not LocalPlayer.Character then return end
    local char = LocalPlayer.Character; local hum = char:FindFirstChild("Humanoid"); local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if settings.noclip then
        wasNoclip = true
        for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end end
    elseif wasNoclip then
        wasNoclip = false
        if hum then hum:ChangeState(Enum.HumanoidStateType.Landed) end
    end

    local doingFly = settings.fly and not (hum and hum.SeatPart)

    if hrp then
        if doingFly then
            if hum then
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
            end
            local bv = hrp:FindFirstChild("FlyBV") or Instance.new("BodyVelocity", hrp)
            bv.Name = "FlyBV"; bv.MaxForce = Vector3.new(100000, 100000, 100000)
            local bg = hrp:FindFirstChild("FlyBG") or Instance.new("BodyGyro", hrp)
            bg.Name = "FlyBG"; bg.MaxTorque = Vector3.new(100000, 100000, 100000); bg.P = 10000
            
            local moveDir = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
            bv.Velocity = moveDir.Magnitude > 0 and moveDir.Unit * settings.flySpeed or Vector3.new(0, 0, 0)
            bg.CFrame = Camera.CFrame
        else
            if hum then
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
            end
            if hrp:FindFirstChild("FlyBV") then hrp.FlyBV:Destroy() end
            if hrp:FindFirstChild("FlyBG") then hrp.FlyBG:Destroy() end
        end
    end
end))

table.insert(scriptConnections, RunService.RenderStepped:Connect(function()
    local targetLocked = false
    if settings.aimbot then
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            local mouseLoc = UserInputService:GetMouseLocation()
            local closest, bestDist = nil, settings.fov
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
                    if not settings.teamCheck or player.Team ~= LocalPlayer.Team then
                        local pos, onScreen = Camera:WorldToViewportPoint(player.Character.Head.Position)
                        if onScreen and pos.Z > 0 then
                            local dist = (mouseLoc - Vector2.new(pos.X, pos.Y)).Magnitude
                            if dist <= bestDist then
                                if not settings.wallCheck or checkVisibility(player.Character) then
                                    bestDist = dist
                                    closest = player
                                end
                            end
                        end
                    end
                end
            end
            if closest and closest.Character and closest.Character:FindFirstChild("Head") then
                targetLocked = true 
                local aimPos = closest.Character.Head.Position
                if settings.predict and closest.Character:FindFirstChild("HumanoidRootPart") then
                    aimPos = aimPos + (closest.Character.HumanoidRootPart.AssemblyLinearVelocity * (settings.predictStrength / 100))
                end
                local targetCFrame = CFrame.new(Camera.CFrame.Position, aimPos)
                Camera.CFrame = settings.smoothness > 0 and Camera.CFrame:Lerp(targetCFrame, math.clamp((100 - settings.smoothness) / 100, 0.02, 1)) or targetCFrame
            end
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not espObjects[player] then
            espObjects[player] = {
                box = createDrawing("Square", {Thickness = 1, Visible = false}),
                health = createDrawing("Text", {Center = true, Size = 13, Font = 2, Color = Color3.fromRGB(100, 255, 100), Outline = true, OutlineColor = Color3.new(0, 0, 0), Visible = false}),
                name = createDrawing("Text", {Center = true, Size = 13, Font = 2, Color = Color3.new(1,1,1), Outline = true, OutlineColor = Color3.new(0, 0, 0), Visible = false}),
                dist = createDrawing("Text", {Center = true, Size = 13, Font = 2, Color = Color3.new(1,1,1), Outline = true, OutlineColor = Color3.new(0, 0, 0), Visible = false})
            }
            tracerObjects[player] = createDrawing("Line", {Thickness = 1, Visible = false})
        end

        local esp = espObjects[player]
        local tracer = tracerObjects[player]
        local char = player.Character

        if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 and (not settings.teamCheck or player.Team ~= LocalPlayer.Team) then
            local rPos = char.HumanoidRootPart.Position
            local b2d, onB = Camera:WorldToViewportPoint(rPos - Vector3.new(0, 3, 0))
            local t2d, onT = Camera:WorldToViewportPoint(char.Head.Position + Vector3.new(0, 0.5, 0))
            local r2d, onR = Camera:WorldToViewportPoint(rPos)
            local tColor = player.Team and player.Team.TeamColor.Color or Color3.fromRGB(255, 60, 60)

            if settings.tracers and onR and r2d.Z > 0 then
                tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                tracer.To = Vector2.new(r2d.X, r2d.Y)
                tracer.Color = tColor
                tracer.Visible = true
            else tracer.Visible = false end

            if settings.esp and (onB or onT) and b2d.Z > 0 then
                local h = math.abs(b2d.Y - t2d.Y)
                local w = h / 1.5
                
                esp.box.Size = Vector2.new(w, h)
                esp.box.Position = Vector2.new(t2d.X - w/2, t2d.Y)
                esp.box.Color = tColor; esp.box.Visible = settings.espBoxes
                esp.health.Text = math.floor(char.Humanoid.Health).." HP"
                esp.health.Position = Vector2.new(t2d.X - w/2 - 25, t2d.Y + (h/2) - 6)
                esp.health.Visible = settings.espHealth
                esp.dist.Text = math.floor((Camera.CFrame.Position - rPos).Magnitude).."m"
                esp.dist.Position = Vector2.new(t2d.X, t2d.Y - 16)
                esp.dist.Visible = settings.espDist
                
                local tool = char:FindFirstChildOfClass("Tool")
                local nText = player.Name
                if tool then nText = nText .. "\n[" .. tool.Name .. "]" end
                
                esp.name.Text = nText
                esp.name.Position = Vector2.new(t2d.X, t2d.Y + h + 3)
                esp.name.Visible = settings.espNames
            else
                esp.box.Visible=false
                esp.health.Visible=false
                esp.name.Visible=false
                esp.dist.Visible=false
            end
        else
            esp.box.Visible=false
            esp.health.Visible=false
            esp.name.Visible=false
            esp.dist.Visible=false; tracer.Visible=false
        end
    end

    local nowTime = tick()
    if nowTime - lastFrameTime >= frameDelay then
        lastFrameTime = nowTime
        
        pcall(function()
            FOVring.Position = UserInputService:GetMouseLocation()
            FOVring.Radius = settings.fov
            FOVring.Visible = settings.aimbot
            FOVring.Color = targetLocked and Color3.fromRGB(235, 94, 85) or Color3.fromRGB(255, 255, 255)
        end)

        if settings.vehicleEsp then
            for i, seat in ipairs(vehicles) do
                if seat and seat.Parent then
                    if not vehicleDrawings[i] then 
                        vehicleDrawings[i] = { box = createDrawing("Square", {Thickness = 1, Color = Color3.fromRGB(150, 150, 255), Filled = false, Visible = false}), text = createDrawing("Text", {Center = true, Size = 13, Font = 2, Color = Color3.fromRGB(150, 150, 255), Outline = true, OutlineColor = Color3.new(0, 0, 0), Visible = false}) } end
                    pcall(function()
                        local model = seat:FindFirstAncestorOfClass("Model")
                        local cf, size = seat.CFrame, seat.Size
                        local name = "Vehicle"
                        if model then cf, size = model:GetBoundingBox()
                            name = model.Name end
                        if cf.Position.Y < 0 then vehicleDrawings[i].box.Visible = false
                            vehicleDrawings[i].text.Visible = false return end
                        local boxScale = 0.65
                        local sx, sy, sz = (size.X / 2) * boxScale, (size.Y / 2) * boxScale, (size.Z / 2) * boxScale
                        local corners = { (cf * CFrame.new(sx, sy, sz)).Position, (cf * CFrame.new(-sx, sy, sz)).Position, (cf * CFrame.new(sx, -sy, sz)).Position, (cf * CFrame.new(sx, sy, -sz)).Position, (cf * CFrame.new(-sx, -sy, sz)).Position, (cf * CFrame.new(sx, -sy, -sz)).Position, (cf * CFrame.new(-sx, sy, -sz)).Position, (cf * CFrame.new(-sx, -sy, -sz)).Position }
                        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                        local allInFront = true
                        for _, corner3D in ipairs(corners) do
                            local pos2D, onScreen = Camera:WorldToViewportPoint(corner3D)
                            if pos2D.Z <= 0 then allInFront = false break end
                            minX = math.min(minX, pos2D.X)
                            minY = math.min(minY, pos2D.Y)
                            maxX = math.max(maxX, pos2D.X)
                            maxY = math.max(maxY, pos2D.Y)
                        end
                        if allInFront then
                            vehicleDrawings[i].box.Size = Vector2.new(maxX - minX, maxY - minY)
                            vehicleDrawings[i].box.Position = Vector2.new(minX, minY)
                            vehicleDrawings[i].box.Visible = true
                            local dist = math.floor((Camera.CFrame.Position - cf.Position).Magnitude)
                            vehicleDrawings[i].text.Text = "[" .. name .. "] " .. dist .. "m"
                            vehicleDrawings[i].text.Position = Vector2.new(minX + (maxX - minX)/2, maxY + 5)
                            vehicleDrawings[i].text.Visible = true
                        else
                            local centerPos, centerOnScreen = Camera:WorldToViewportPoint(cf.Position)
                            if centerOnScreen and centerPos.Z > 0 then
                                vehicleDrawings[i].box.Visible = false
                                local dist = math.floor((Camera.CFrame.Position - cf.Position).Magnitude); vehicleDrawings[i].text.Text = "[" .. name .. "] " .. dist .. "m"
                                vehicleDrawings[i].text.Position = Vector2.new(centerPos.X, centerPos.Y)
                                vehicleDrawings[i].text.Visible = true
                            else vehicleDrawings[i].box.Visible = false
                                vehicleDrawings[i].text.Visible = false end
                        end
                    end)
                end
            end
            for i = #vehicles + 1, #vehicleDrawings do
                pcall(function() vehicleDrawings[i].box.Visible = false; vehicleDrawings[i].text.Visible = false end)
            end
        end

        if tick() - lastSysCheck > 1 then
            lastSysCheck = tick()
            local gs = workspace:FindFirstChild("Game Systems")
            if gs then
                local sw = gs:FindFirstChild("Submarine Workspace")
                sysCache.subs = sw and sw:GetChildren() or {}
                local pw = gs:FindFirstChild("Plane Workspace")
                sysCache.uavs = pw and pw:GetChildren() or {}
                local tw = gs:FindFirstChild("Tank Workspace")
                sysCache.ugvs = tw and tw:GetChildren() or {}
            else
                sysCache.subs = {}
                sysCache.uavs = {}
                sysCache.ugvs = {}
            end
        end

        if settings.submarineEsp then
            local currentSubs = {}
            for _, obj in ipairs(sysCache.subs) do if obj:IsA("Model") then table.insert(currentSubs, obj) end end
            for i, model in ipairs(currentSubs) do
                if not subDrawings[i] then subDrawings[i] = { box = createDrawing("Square", {Thickness = 1, Color = Color3.fromRGB(0, 255, 255), Filled = false, Visible = false}), text = createDrawing("Text", {Center = true, Size = 13, Font = 2, Color = Color3.fromRGB(0, 255, 255), Outline = true, OutlineColor = Color3.new(0, 0, 0), Visible = false}) } end
                pcall(function()
                    local cf, size = model:GetBoundingBox()
                    if cf.Position.Y < 0 then subDrawings[i].box.Visible = false
                        subDrawings[i].text.Visible = false return end
                    local sx, sy, sz = size.X / 2, size.Y / 2, size.Z / 2
                    local corners = { (cf * CFrame.new(sx, sy, sz)).Position, (cf * CFrame.new(-sx, sy, sz)).Position, (cf * CFrame.new(sx, -sy, sz)).Position, (cf * CFrame.new(sx, sy, -sz)).Position, (cf * CFrame.new(-sx, -sy, sz)).Position, (cf * CFrame.new(sx, -sy, -sz)).Position, (cf * CFrame.new(-sx, sy, -sz)).Position, (cf * CFrame.new(-sx, -sy, -sz)).Position }
                    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                    local allInFront = true
                    for _, corner3D in ipairs(corners) do
                        local pos2D, onScreen = Camera:WorldToViewportPoint(corner3D)
                        if pos2D.Z <= 0 then allInFront = false break end
                        minX = math.min(minX, pos2D.X)
                        minY = math.min(minY, pos2D.Y)
                        maxX = math.max(maxX, pos2D.X)
                        maxY = math.max(maxY, pos2D.Y)
                    end
                    if allInFront then
                        subDrawings[i].box.Size = Vector2.new(maxX - minX, maxY - minY)
                        subDrawings[i].box.Position = Vector2.new(minX, minY)
                        subDrawings[i].box.Visible = true; local dist = math.floor((Camera.CFrame.Position - cf.Position).Magnitude)
                        subDrawings[i].text.Text = "[" .. model.Name .. "] " .. dist .. "m"
                        subDrawings[i].text.Position = Vector2.new(minX + (maxX - minX)/2, maxY + 5)
                        subDrawings[i].text.Visible = true
                    else
                        local centerPos, centerOnScreen = Camera:WorldToViewportPoint(cf.Position)
                        if centerOnScreen and centerPos.Z > 0 then subDrawings[i].box.Visible = false
                            local dist = math.floor((Camera.CFrame.Position - cf.Position).Magnitude)
                            subDrawings[i].text.Text = "[" .. model.Name .. "] " .. dist .. "m"
                            subDrawings[i].text.Position = Vector2.new(centerPos.X, centerPos.Y)
                            subDrawings[i].text.Visible = true else subDrawings[i].box.Visible = false
                            subDrawings[i].text.Visible = false end
                    end
                end)
            end
            for i = #currentSubs + 1, #subDrawings do pcall(function() subDrawings[i].box.Visible = false
                subDrawings[i].text.Visible = false end) end
        end

        if settings.uavEsp then 
            local currentUavs = {}
            local allowed = { ["S-70 Okhotnik"] = true, ["MQ-1 Predator"] = true, ["TB2 Bayraktar"] = true, ["MQ-9 Reaper"] = true }
            for _, obj in ipairs(sysCache.uavs) do if obj:IsA("Model") and allowed[obj.Name] then table.insert(currentUavs, obj) end end
            for i, model in ipairs(currentUavs) do
                if not uavDrawings[i] then uavDrawings[i] = { box = createDrawing("Square", {Thickness = 1, Color = Color3.fromRGB(255, 140, 0), Filled = false, Visible = false}), text = createDrawing("Text", {Center = true, Size = 13, Font = 2, Color = Color3.fromRGB(255, 140, 0), Outline = true, OutlineColor = Color3.new(0, 0, 0), Visible = false}) } end
                pcall(function()
                    local cf, size = model:GetBoundingBox()
                    local boxScale = 0.5
                    local sx, sy, sz = (size.X / 2) * boxScale, (size.Y / 2) * boxScale, (size.Z / 2) * boxScale
                    local corners = { (cf * CFrame.new(sx, sy, sz)).Position, (cf * CFrame.new(-sx, sy, sz)).Position, (cf * CFrame.new(sx, -sy, sz)).Position, (cf * CFrame.new(sx, sy, -sz)).Position, (cf * CFrame.new(-sx, -sy, sz)).Position, (cf * CFrame.new(sx, -sy, -sz)).Position, (cf * CFrame.new(-sx, sy, -sz)).Position, (cf * CFrame.new(-sx, -sy, -sz)).Position }
                    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                    local allInFront = true
                    for _, corner3D in ipairs(corners) do
                        local pos2D, onScreen = Camera:WorldToViewportPoint(corner3D)
                        if pos2D.Z <= 0 then allInFront = false break end
                        minX = math.min(minX, pos2D.X)
                        minY = math.min(minY, pos2D.Y)
                        maxX = math.max(maxX, pos2D.X)
                        maxY = math.max(maxY, pos2D.Y)
                    end
                    if allInFront then
                        uavDrawings[i].box.Size = Vector2.new(maxX - minX, maxY - minY)
                        uavDrawings[i].box.Position = Vector2.new(minX, minY); uavDrawings[i].box.Visible = true
                        local dist = math.floor((Camera.CFrame.Position - cf.Position).Magnitude)
                        uavDrawings[i].text.Text = "[" .. model.Name .. "] " .. dist .. "m"
                        uavDrawings[i].text.Position = Vector2.new(minX + (maxX - minX)/2, maxY + 5)
                        uavDrawings[i].text.Visible = true
                    else
                        local centerPos, centerOnScreen = Camera:WorldToViewportPoint(cf.Position)
                        if centerOnScreen and centerPos.Z > 0 then uavDrawings[i].box.Visible = false
                            local dist = math.floor((Camera.CFrame.Position - cf.Position).Magnitude)
                            uavDrawings[i].text.Text = "[" .. model.Name .. "] " .. dist .. "m"
                            uavDrawings[i].text.Position = Vector2.new(centerPos.X, centerPos.Y)
                            uavDrawings[i].text.Visible = true else uavDrawings[i].box.Visible = false
                            uavDrawings[i].text.Visible = false end
                    end
                end)
            end
            for i = #currentUavs + 1, #uavDrawings do pcall(function() uavDrawings[i].box.Visible = false
                uavDrawings[i].text.Visible = false end) end
        end

        if settings.ugvEsp then
            local currentUgvs = {}
            local allowed = { ["Ripsaw M5"] = true, ["Aselsan Gurz"] = true }
            for _, obj in ipairs(sysCache.ugvs) do if obj:IsA("Model") and allowed[obj.Name] then table.insert(currentUgvs, obj) end end
            for i, model in ipairs(currentUgvs) do
                if not ugvDrawings[i] then ugvDrawings[i] = { box = createDrawing("Square", {Thickness = 1, Color = Color3.fromRGB(120, 255, 120), Filled = false, Visible = false}), text = createDrawing("Text", {Center = true, Size = 13, Font = 2, Color = Color3.fromRGB(120, 255, 120), Outline = true, OutlineColor = Color3.new(0, 0, 0), Visible = false}) } end
                pcall(function()
                    local cf, size = model:GetBoundingBox()
                    local scale = 0.65
                    local sx, sy, sz = (size.X / 2) * scale, (size.Y / 2) * scale, (size.Z / 2) * scale
                    local corners = { (cf * CFrame.new(sx, sy, sz)).Position, (cf * CFrame.new(-sx, sy, sz)).Position, (cf * CFrame.new(sx, -sy, sz)).Position, (cf * CFrame.new(sx, sy, -sz)).Position, (cf * CFrame.new(-sx, -sy, sz)).Position, (cf * CFrame.new(sx, -sy, -sz)).Position, (cf * CFrame.new(-sx, sy, -sz)).Position, (cf * CFrame.new(-sx, -sy, -sz)).Position }
                    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                    local allInFront = true
                    for _, corner3D in ipairs(corners) do
                        local pos2D, onScreen = Camera:WorldToViewportPoint(corner3D)
                        if pos2D.Z <= 0 then allInFront = false break end
                        minX = math.min(minX, pos2D.X)
                        minY = math.min(minY, pos2D.Y)
                        maxX = math.max(maxX, pos2D.X)
                        maxY = math.max(maxY, pos2D.Y)
                    end
                    if allInFront then
                        ugvDrawings[i].box.Size = Vector2.new(maxX - minX, maxY - minY)
                        ugvDrawings[i].box.Position = Vector2.new(minX, minY); ugvDrawings[i].box.Visible = true
                        local dist = math.floor((Camera.CFrame.Position - cf.Position).Magnitude)
                        ugvDrawings[i].text.Text = "[" .. model.Name .. "] " .. dist .. "m"
                        ugvDrawings[i].text.Position = Vector2.new(minX + (maxX - minX)/2, maxY + 5)
                        ugvDrawings[i].text.Visible = true
                    else
                        local centerPos, centerOnScreen = Camera:WorldToViewportPoint(cf.Position)
                        if centerOnScreen and centerPos.Z > 0 then ugvDrawings[i].box.Visible = false
                            local dist = math.floor((Camera.CFrame.Position - cf.Position).Magnitude)
                            ugvDrawings[i].text.Text = "[" .. model.Name .. "] " .. dist .. "m"
                            ugvDrawings[i].text.Position = Vector2.new(centerPos.X, centerPos.Y)
                            ugvDrawings[i].text.Visible = true else ugvDrawings[i].box.Visible = false
                            ugvDrawings[i].text.Visible = false end
                    end
                end)
            end
            for i = #currentUgvs + 1, #ugvDrawings do pcall(function() ugvDrawings[i].box.Visible = false
                ugvDrawings[i].text.Visible = false end) end
        end
    end
end))
