-- ============================================================
--  LoScript For MM2 (v11 PRO FIXED)
--  Полный рабочий скрипт: красивый дизайн, плавающая иконка,
--  исправление всех функций (Role check, Kill Aura, Fling, GunDrop, AimBot)
-- ============================================================

if not game:IsLoaded() then
    pcall(function() game.Loaded:Wait() end)
end

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    camera = workspace.CurrentCamera
end)

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled

-- === БЕЗОПАСНЫЙ GUI CONTAINER (ДЛЯ ВСЕХ ЭКСЕКЬЮТОРОВ) ===
local parentGui = nil
pcall(function() parentGui = gethui and gethui() end)
if not parentGui then
    pcall(function() parentGui = game:GetService("CoreGui") end)
end
if not parentGui then
    parentGui = Player:FindFirstChildOfClass("PlayerGui") or Player:WaitForChild("PlayerGui", 5)
end

-- Удаляем старую версию, если была запущена
pcall(function()
    if parentGui:FindFirstChild("LoScriptMM2") then
        parentGui.LoScriptMM2:Destroy()
    end
    if parentGui:FindFirstChild("LoScriptMM2_Ultra") then
        parentGui.LoScriptMM2_Ultra:Destroy()
    end
    if parentGui:FindFirstChild("LoScriptMM2_Pro") then
        parentGui.LoScriptMM2_Pro:Destroy()
    end
end)

-- === НАСТРОЙКИ ===
local Settings = {
    FlingEnabled = false,
    Power = 500,
    Radius = 15,
    HighlightEnabled = true,
    AimEnabled = false,
    AimFOV = 35,
    AimTarget = "Murderer",       -- Murderer, Sheriff, Nearest, All
    AimPrediction = true,
    AutoPickupEnabled = false,
    KillEnabled = false,
    KillDistance = 15,
    TeleportEnabled = false,
    TeleportTarget = "Murderer",   -- Murderer, Sheriff, GunDrop, Nearest
    NoclipEnabled = false,
    HideEnabled = false,
}

local CONFIG_FILE = "loscript_mm2_v11.txt"

local function LoadSettings()
    if isfile and isfile(CONFIG_FILE) then
        local ok, data = pcall(readfile, CONFIG_FILE)
        if ok and data then
            local decoded = nil
            pcall(function() decoded = HttpService:JSONDecode(data) end)
            if type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    if Settings[k] ~= nil then
                        Settings[k] = v
                    end
                end
            end
        end
    end
end
LoadSettings()

local function SaveSettings()
    if writefile then
        pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(Settings))
        end)
    end
end

-- === ПЕРЕМЕННЫЕ ПЕРСОНАЖА ===
local character = Player.Character
local rootPart = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")

local function UpdateCharacter(newChar)
    character = newChar
    if character then
        rootPart = character:FindFirstChild("HumanoidRootPart")
        humanoid = character:FindFirstChildOfClass("Humanoid")
    else
        rootPart = nil
        humanoid = nil
    end
end

UpdateCharacter(Player.Character)
Player.CharacterAdded:Connect(function(newChar)
    UpdateCharacter(newChar)
    -- Восстановление Noclip при респавне
    if Settings.NoclipEnabled then
        task.wait(0.2)
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
    -- Восстановление Hide при респавне
    if Settings.HideEnabled then
        task.wait(0.3)
        if character then
            for _, inst in ipairs(character:GetDescendants()) do
                if inst:IsA("BasePart") or inst:IsA("Decal") then
                    inst.Transparency = 1
                end
            end
        end
    end
end)

-- ============================================================
--  НАДЕЖНОЕ ОПРЕДЕЛЕНИЕ ОРУЖИЯ И РОЛЕЙ MM2
-- ============================================================
local function isKnifeTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    if tool:FindFirstChild("KnifeServer") or tool:FindFirstChild("KnifeClient") or tool:FindFirstChild("KnifeLocal") or tool:FindFirstChild("Stab") or tool:FindFirstChild("Slash") then
        return true
    end
    local name = tool.Name:lower()
    if name:find("knife") or name:find("dagger") or name:find("blade") or name:find("sword") 
       or name:find("scythe") or name:find("axe") or name:find("katana") or name:find("batwing") 
       or name:find("harvester") or name:find("corrupt") or name:find("icebreaker") or name:find("fang")
       or name:find("heat") or name:find("saw") or name:find("slasher") or name:find("tides") then
        return true
    end
    return false
end

local function isGunTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    if tool:FindFirstChild("GunServer") or tool:FindFirstChild("GunClient") or tool:FindFirstChild("GunLocal") or tool:FindFirstChild("Shoot") or tool:FindFirstChild("Reload") then
        return true
    end
    local name = tool.Name:lower()
    if name:find("gun") or name:find("revolver") or name:find("pistol") or name:find("luger") 
       or name:find("blaster") or name:find("sheriff") or name:find("laser") or name:find("darkbringer") 
       or name:find("lightbringer") or name:find("shark") or name:find("crossbow") then
        return true
    end
    return false
end

local function getPlayerRole(plr)
    if not plr then return "Innocent" end
    local backpack = plr:FindFirstChild("Backpack")
    local char = plr.Character

    local function checkContainer(cont)
        if not cont then return nil end
        for _, item in ipairs(cont:GetChildren()) do
            if isKnifeTool(item) then
                return "Murderer"
            elseif isGunTool(item) then
                return "Sheriff"
            end
        end
        return nil
    end

    local role = checkContainer(char) or checkContainer(backpack)
    return role or "Innocent"
end

local function findKnife(targetPlayer)
    targetPlayer = targetPlayer or Player
    local char = targetPlayer.Character
    local backpack = targetPlayer:FindFirstChild("Backpack")

    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if isKnifeTool(tool) then return tool end
        end
    end
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if isKnifeTool(tool) then return tool end
        end
    end
    return nil
end

local function findGun(targetPlayer)
    targetPlayer = targetPlayer or Player
    local char = targetPlayer.Character
    local backpack = targetPlayer:FindFirstChild("Backpack")

    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if isGunTool(tool) then return tool end
        end
    end
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if isGunTool(tool) then return tool end
        end
    end
    return nil
end

local function equipTool(tool)
    if not tool or not tool.Parent then return end
    local myChar = Player.Character
    if tool.Parent == Player:FindFirstChild("Backpack") and myChar then
        local hum = myChar:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:EquipTool(tool)
            task.wait(0.08)
        end
    end
end

local function getGunDrop()
    local drop = workspace:FindFirstChild("GunDrop", true)
    if drop then
        local part = nil
        if drop:IsA("BasePart") then
            part = drop
        elseif drop:IsA("Model") then
            part = drop.PrimaryPart or drop:FindFirstChildWhichIsA("BasePart")
        end
        if part then
            return drop, part
        end
    end
    return nil, nil
end

-- ============================================================
--  СТИЛИ И ТЕМА
-- ============================================================
local Theme = {
    Background = Color3.fromRGB(12, 13, 20),
    Header = Color3.fromRGB(18, 20, 32),
    Card = Color3.fromRGB(24, 26, 40),
    CardActive = Color3.fromRGB(32, 35, 54),
    Border = Color3.fromRGB(46, 50, 76),
    Accent = Color3.fromRGB(168, 85, 247),       -- Неоновый фиолетовый
    AccentGlow = Color3.fromRGB(192, 132, 252),
    AccentSecondary = Color3.fromRGB(6, 182, 212),-- Неоновый бирюзовый
    Success = Color3.fromRGB(34, 197, 94),      -- Зелёный
    Danger = Color3.fromRGB(239, 68, 68),       -- Красный (Murderer)
    Text = Color3.fromRGB(245, 247, 255),
    TextMuted = Color3.fromRGB(150, 155, 180),
}

local FontFace = Font.fromEnum(Enum.Font.GothamBold)

local function Create(className, properties)
    local inst = Instance.new(className)
    for k, v in pairs(properties) do
        if k ~= "Parent" then
            pcall(function() inst[k] = v end)
        end
    end
    if properties.Parent then
        pcall(function() inst.Parent = properties.Parent end)
    end
    return inst
end

local function Corner(parent, radius)
    return Create("UICorner", {
        Parent = parent,
        CornerRadius = UDim.new(0, radius or 8),
    })
end

local function Stroke(parent, color, thickness)
    return Create("UIStroke", {
        Parent = parent,
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function Tween(inst, info, goal)
    local tw = TweenService:Create(inst, info or TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
    tw:Play()
    return tw
end

-- ============================================================
--  GUI ИНТЕРФЕЙС
-- ============================================================
local ScreenGui = Create("ScreenGui", {
    Parent = parentGui,
    Name = "LoScriptMM2_Pro",
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 999,
    ResetOnSpawn = false,
})

local UIScale = Create("UIScale", {
    Parent = ScreenGui,
    Scale = IsMobile and 0.88 or 1,
})

-- ============================================================
--  КРАСИВАЯ ПЛАВАЮЩАЯ ИКОНКА (FLOATING TOGGLE BUTTON)
-- ============================================================
local FloatIcon = Create("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(0, 54, 0, 54),
    Position = UDim2.new(0, 20, 0.45, 0),
    BackgroundColor3 = Theme.Header,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 20,
})
Corner(FloatIcon, 16)
local FloatStroke = Stroke(FloatIcon, Theme.Accent, 2)

local IconLabel = Create("TextLabel", {
    Parent = FloatIcon,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "⚡",
    TextColor3 = Theme.AccentGlow,
    TextSize = 26,
    FontFace = FontFace,
    ZIndex = 21,
})

local IconBadge = Create("Frame", {
    Parent = FloatIcon,
    Size = UDim2.new(0, 12, 0, 12),
    Position = UDim2.new(1, -6, 0, -2),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Theme.Success,
    BorderSizePixel = 0,
    ZIndex = 22,
})
Corner(IconBadge, 6)
Stroke(IconBadge, Theme.Background, 1)

local FloatButton = Create("TextButton", {
    Parent = FloatIcon,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "",
    ZIndex = 23,
})

-- Перемещение плавающей иконки
local floatDragging = false
local floatDragStart = nil
local floatStartPos = nil

FloatButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        floatDragging = true
        floatDragStart = input.Position
        floatStartPos = FloatIcon.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not floatDragging or not floatDragStart or not floatStartPos then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local delta = (input.Position - floatDragStart) / UIScale.Scale
        FloatIcon.Position = UDim2.new(
            floatStartPos.X.Scale,
            floatStartPos.X.Offset + delta.X,
            floatStartPos.Y.Scale,
            floatStartPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        floatDragging = false
    end
end)

-- ============================================================
--  ГЛАВНОЕ ОКНО
-- ============================================================
local win_w = IsMobile and 380 or 420
local win_h = IsMobile and 520 or 560

local Main = Create("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(0, win_w, 0, win_h),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = true,
    ZIndex = 2,
})
Corner(Main, 14)
local MainStroke = Stroke(Main, Theme.Border, 1.5)

-- Шапка
local header_h = 50
local Header = Create("Frame", {
    Parent = Main,
    Size = UDim2.new(1, 0, 0, header_h),
    BackgroundColor3 = Theme.Header,
    BorderSizePixel = 0,
    ZIndex = 3,
})
Corner(Header, 14)

local HeaderCover = Create("Frame", {
    Parent = Header,
    Size = UDim2.new(1, 0, 0, 14),
    Position = UDim2.new(0, 0, 1, -14),
    BackgroundColor3 = Theme.Header,
    BorderSizePixel = 0,
    ZIndex = 3,
})

local HeaderLine = Create("Frame", {
    Parent = Header,
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = Theme.Border,
    BorderSizePixel = 0,
    ZIndex = 4,
})

local DragArea = Create("Frame", {
    Parent = Header,
    Size = UDim2.new(1, -90, 1, 0),
    BackgroundTransparency = 1,
    ZIndex = 4,
})

local TitleIcon = Create("TextLabel", {
    Parent = Header,
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(0, 12, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Theme.Card,
    Text = "⚡",
    TextColor3 = Theme.Accent,
    TextSize = 17,
    FontFace = FontFace,
    ZIndex = 5,
})
Corner(TitleIcon, 8)
Stroke(TitleIcon, Theme.Accent, 1)

local TitleLabel = Create("TextLabel", {
    Parent = Header,
    Size = UDim2.new(0, 130, 1, 0),
    Position = UDim2.new(0, 50, 0, 0),
    BackgroundTransparency = 1,
    Text = "LoScript MM2",
    TextColor3 = Theme.Text,
    TextSize = 16,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 5,
})

local Badge = Create("TextLabel", {
    Parent = Header,
    Size = UDim2.new(0, 70, 0, 20),
    Position = UDim2.new(0, 170, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Theme.Card,
    Text = "v11 PRO",
    TextColor3 = Theme.AccentSecondary,
    TextSize = 11,
    FontFace = FontFace,
    ZIndex = 5,
})
Corner(Badge, 10)
Stroke(Badge, Theme.AccentSecondary, 1)

local MinBtn = Create("TextButton", {
    Parent = Header,
    Size = UDim2.new(0, 28, 0, 28),
    Position = UDim2.new(1, -74, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Theme.Card,
    Text = "−",
    TextColor3 = Theme.TextMuted,
    TextSize = 18,
    FontFace = FontFace,
    AutoButtonColor = false,
    ZIndex = 6,
})
Corner(MinBtn, 8)
Stroke(MinBtn, Theme.Border, 1)

local CloseBtn = Create("TextButton", {
    Parent = Header,
    Size = UDim2.new(0, 28, 0, 28),
    Position = UDim2.new(1, -38, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Theme.Card,
    Text = "✕",
    TextColor3 = Theme.TextMuted,
    TextSize = 13,
    FontFace = FontFace,
    AutoButtonColor = false,
    ZIndex = 6,
})
Corner(CloseBtn, 8)
Stroke(CloseBtn, Theme.Border, 1)

-- ============================================================
--  ТАБЫ (ВКЛАДКИ)
-- ============================================================
local tab_h = 38
local TabBar = Create("Frame", {
    Parent = Main,
    Size = UDim2.new(1, -20, 0, tab_h),
    Position = UDim2.new(0, 10, 0, header_h + 8),
    BackgroundColor3 = Theme.Header,
    BorderSizePixel = 0,
    ZIndex = 3,
})
Corner(TabBar, 10)
Stroke(TabBar, Theme.Border, 1)

Create("UIListLayout", {
    Parent = TabBar,
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 6),
})

-- Нижняя плашка со статусом
local footer_h = 34
local Footer = Create("Frame", {
    Parent = Main,
    Size = UDim2.new(1, 0, 0, footer_h),
    Position = UDim2.new(0, 0, 1, -footer_h),
    BackgroundColor3 = Theme.Header,
    BorderSizePixel = 0,
    ZIndex = 3,
})
Create("Frame", {
    Parent = Footer,
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = Theme.Border,
    BorderSizePixel = 0,
    ZIndex = 4,
})

local StatusDot = Create("Frame", {
    Parent = Footer,
    Size = UDim2.new(0, 8, 0, 8),
    Position = UDim2.new(0, 12, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Theme.Success,
    BorderSizePixel = 0,
    ZIndex = 5,
})
Corner(StatusDot, 4)

local StatusLabel = Create("TextLabel", {
    Parent = Footer,
    Size = UDim2.new(1, -130, 1, 0),
    Position = UDim2.new(0, 26, 0, 0),
    BackgroundTransparency = 1,
    Text = "Готов | Флингов: 0",
    TextColor3 = Theme.TextMuted,
    TextSize = 12,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 5,
})

local RoleBadge = Create("TextLabel", {
    Parent = Footer,
    Size = UDim2.new(0, 90, 0, 20),
    Position = UDim2.new(1, -10, 0.5, 0),
    AnchorPoint = Vector2.new(1, 0.5),
    BackgroundColor3 = Theme.Card,
    Text = "Innocent",
    TextColor3 = Theme.Success,
    TextSize = 11,
    FontFace = FontFace,
    ZIndex = 5,
})
Corner(RoleBadge, 6)
Stroke(RoleBadge, Theme.Border, 1)

-- Контейнер для страниц
local content_top = header_h + tab_h + 16
local content_h = win_h - content_top - footer_h - 4
local PagesContainer = Create("Frame", {
    Parent = Main,
    Size = UDim2.new(1, 0, 0, content_h),
    Position = UDim2.new(0, 0, 0, content_top),
    BackgroundTransparency = 1,
    ZIndex = 3,
})

local Tabs = {}
local TabButtons = {}
local currentTab = "Combat"

local function CreatePage(name)
    local scroll = Create("ScrollingFrame", {
        Parent = PagesContainer,
        Name = name .. "Page",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
        ZIndex = 4,
    })
    Create("UIListLayout", {
        Parent = scroll,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    })
    Create("UIPadding", {
        Parent = scroll,
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    })
    Tabs[name] = scroll
    return scroll
end

local function SwitchTab(tabName)
    currentTab = tabName
    for name, page in pairs(Tabs) do
        page.Visible = (name == tabName)
    end
    for name, btn in pairs(TabButtons) do
        local isActive = (name == tabName)
        btn.BackgroundColor3 = isActive and Theme.Accent or Theme.Card
        btn.TextColor3 = isActive and Theme.Text or Theme.TextMuted
    end
end

local function AddTabButton(tabName, icon, label)
    local btn = Create("TextButton", {
        Parent = TabBar,
        Size = UDim2.new(0.31, 0, 0, 28),
        BackgroundColor3 = (tabName == currentTab) and Theme.Accent or Theme.Card,
        Text = icon .. " " .. label,
        TextColor3 = (tabName == currentTab) and Theme.Text or Theme.TextMuted,
        TextSize = 12,
        FontFace = FontFace,
        AutoButtonColor = false,
        ZIndex = 4,
    })
    Corner(btn, 8)
    Stroke(btn, Theme.Border, 1)
    TabButtons[tabName] = btn

    btn.MouseButton1Click:Connect(function()
        SwitchTab(tabName)
    end)
end

local CombatPage = CreatePage("Combat")
local VisualPage = CreatePage("Visual")
local MiscPage = CreatePage("Misc")

AddTabButton("Combat", "⚔", "Бой")
AddTabButton("Visual", "◎", "Аим/ESP")
AddTabButton("Misc", "✦", "Разное")

SwitchTab("Combat")

-- ============================================================
--  КОМПОНЕНТЫ УПРАВЛЕНИЯ (ИСПРАВЛЕННАЯ СТРОЧНАЯ ВЕРСТКА)
-- ============================================================

-- 1. СТИЛЬНЫЙ ТОГГЛ (SWITCH ROW)
local function AddToggle(parent, title, desc, defaultState, callback)
    local row = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    Corner(row, 8)
    local rowStroke = Stroke(row, Theme.Border, 1)

    Create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, -70, 0, 20),
        Position = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = FontFace,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    Create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, -70, 0, 18),
        Position = UDim2.new(0, 12, 0, 26),
        BackgroundTransparency = 1,
        Text = desc or "",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        FontFace = FontFace,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    local switchBtn = Create("TextButton", {
        Parent = row,
        Size = UDim2.new(0, 48, 0, 26),
        Position = UDim2.new(1, -10, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = defaultState and Theme.Accent or Color3.fromRGB(36, 38, 56),
        Text = defaultState and "ON" or "OFF",
        TextColor3 = Theme.Text,
        TextSize = 11,
        FontFace = FontFace,
        AutoButtonColor = false,
        ZIndex = 7,
    })
    Corner(switchBtn, 6)
    Stroke(switchBtn, Theme.Border, 1)

    local state = defaultState

    local function SetState(val)
        state = val
        switchBtn.BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(36, 38, 56)
        switchBtn.Text = state and "ON" or "OFF"
        rowStroke.Color = state and Theme.Accent or Theme.Border
        if callback then callback(state) end
    end

    switchBtn.MouseButton1Click:Connect(function()
        SetState(not state)
    end)

    return {
        Get = function() return state end,
        Set = SetState,
    }
end

-- 2. СТЕППЕР В ОДНУ СТРОКУ
local function AddStepper(parent, title, desc, defaultValue, minVal, maxVal, step, unit, callback)
    local row = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    Corner(row, 8)
    Stroke(row, Theme.Border, 1)

    Create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, -145, 0, 20),
        Position = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = FontFace,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    Create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, -145, 0, 18),
        Position = UDim2.new(0, 12, 0, 26),
        BackgroundTransparency = 1,
        Text = desc or "",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        FontFace = FontFace,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    local ctrl = Create("Frame", {
        Parent = row,
        Size = UDim2.new(0, 125, 0, 30),
        Position = UDim2.new(1, -10, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Theme.Header,
        BorderSizePixel = 0,
        ZIndex = 6,
    })
    Corner(ctrl, 6)
    Stroke(ctrl, Theme.Border, 1)

    local dec = Create("TextButton", {
        Parent = ctrl,
        Size = UDim2.new(0, 30, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Theme.Card,
        Text = "−",
        TextColor3 = Theme.Text,
        TextSize = 16,
        FontFace = FontFace,
        AutoButtonColor = false,
        ZIndex = 7,
    })
    Corner(dec, 5)

    local valLbl = Create("TextLabel", {
        Parent = ctrl,
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 30, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(defaultValue) .. (unit or ""),
        TextColor3 = Theme.AccentGlow,
        TextSize = 12,
        FontFace = FontFace,
        ZIndex = 7,
    })

    local inc = Create("TextButton", {
        Parent = ctrl,
        Size = UDim2.new(0, 30, 1, 0),
        Position = UDim2.new(1, -30, 0, 0),
        BackgroundColor3 = Theme.Card,
        Text = "+",
        TextColor3 = Theme.Text,
        TextSize = 16,
        FontFace = FontFace,
        AutoButtonColor = false,
        ZIndex = 7,
    })
    Corner(inc, 5)

    local cur = defaultValue

    local function UpdateVal(newVal)
        cur = math.clamp(newVal, minVal, maxVal)
        valLbl.Text = tostring(cur) .. (unit or "")
        if callback then callback(cur) end
    end

    dec.MouseButton1Click:Connect(function() UpdateVal(cur - step) end)
    inc.MouseButton1Click:Connect(function() UpdateVal(cur + step) end)

    return {
        Get = function() return cur end,
        Set = UpdateVal,
    }
end

-- 3. СЕЛЕКТОР (ВЫБОР ОПЦИЙ)
local function AddSelector(parent, title, desc, options, defaultOption, callback)
    local row = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    Corner(row, 8)
    Stroke(row, Theme.Border, 1)

    Create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, -135, 0, 20),
        Position = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = FontFace,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    Create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, -135, 0, 18),
        Position = UDim2.new(0, 12, 0, 26),
        BackgroundTransparency = 1,
        Text = desc or "",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        FontFace = FontFace,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    local selBtn = Create("TextButton", {
        Parent = row,
        Size = UDim2.new(0, 115, 0, 30),
        Position = UDim2.new(1, -10, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Theme.Header,
        Text = defaultOption,
        TextColor3 = Theme.AccentSecondary,
        TextSize = 12,
        FontFace = FontFace,
        AutoButtonColor = false,
        ZIndex = 7,
    })
    Corner(selBtn, 6)
    Stroke(selBtn, Theme.Border, 1)

    local curIdx = 1
    for i, v in ipairs(options) do
        if v == defaultOption then curIdx = i break end
    end

    selBtn.MouseButton1Click:Connect(function()
        curIdx = (curIdx % #options) + 1
        local newOpt = options[curIdx]
        selBtn.Text = newOpt
        if callback then callback(newOpt) end
    end)

    return {
        Get = function() return options[curIdx] end,
        Set = function(val)
            for i, v in ipairs(options) do
                if v == val then
                    curIdx = i
                    selBtn.Text = val
                    if callback then callback(val) end
                    break
                end
            end
        end,
    }
end

-- 4. КНОПКА ДЕЙСТВИЯ (ACTION BUTTON)
local function AddActionButton(parent, title, desc, btnText, btnColor, callback)
    local row = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    Corner(row, 8)
    Stroke(row, Theme.Border, 1)

    Create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, -135, 0, 20),
        Position = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 13,
        FontFace = FontFace,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    Create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, -135, 0, 18),
        Position = UDim2.new(0, 12, 0, 26),
        BackgroundTransparency = 1,
        Text = desc or "",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        FontFace = FontFace,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    local actBtn = Create("TextButton", {
        Parent = row,
        Size = UDim2.new(0, 115, 0, 30),
        Position = UDim2.new(1, -10, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = btnColor or Theme.Accent,
        Text = btnText or "Выполнить",
        TextColor3 = Theme.Text,
        TextSize = 12,
        FontFace = FontFace,
        AutoButtonColor = false,
        ZIndex = 7,
    })
    Corner(actBtn, 6)
    Stroke(actBtn, Theme.Border, 1)

    actBtn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
end

-- ============================================================
--  ЛОГИКА ФУНКЦИЙ (БЕЗ ОШИБОК И ВЫЛЕТОВ)
-- ============================================================
local flingActive = false
local flingLoopRunning = false
local flingCount = 0

local highlightLoopRunning = false
local highlightCache = {}

local aimLoopRunning = false
local aimConnection = nil

local autoPickupLoopRunning = false
local autoPickupCooldown = false

local killLoopRunning = false
local killAllActive = false

local teleportLoopRunning = false

local noclipRunning = false
local noclipConnection = nil

local hideRunning = false
local hiddenParts = {}

-- 1. ФЛИНГ
local function flingTarget(targetChar)
    if not targetChar or flingActive then return false end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    local myChar = Player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not targetRoot or not myRoot or not myHum then return false end

    flingActive = true
    local oldCFrame = myRoot.CFrame
    myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    myHum.Sit = false

    -- Коллизия
    for _, part in ipairs(myChar:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end

    local bav = Instance.new("BodyAngularVelocity")
    bav.AngularVelocity = Vector3.new(0, Settings.Power * 80, 0)
    bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bav.P = math.huge
    bav.Parent = myRoot

    local startTime = tick()
    while tick() - startTime < 0.35 do
        if not targetRoot or not targetRoot.Parent then break end
        myRoot.CFrame = targetRoot.CFrame
        pcall(function()
            myRoot.AssemblyAngularVelocity = Vector3.new(0, Settings.Power * 80, 0)
            myRoot.AssemblyLinearVelocity = Vector3.new(60000, 60000, 60000)
        end)
        RunService.Heartbeat:Wait()
    end

    bav:Destroy()
    pcall(function()
        myRoot.AssemblyAngularVelocity = Vector3.zero
        myRoot.AssemblyLinearVelocity = Vector3.zero
        myRoot.Velocity = Vector3.zero
        myRoot.RotVelocity = Vector3.zero
    end)

    myRoot.CFrame = oldCFrame
    myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)

    flingActive = false
    flingCount = flingCount + 1
    StatusLabel.Text = "● Флингов: " .. flingCount
    return true
end

local function startFlingLoop()
    if flingLoopRunning then return end
    flingLoopRunning = true
    task.spawn(function()
        while flingLoopRunning and Settings.FlingEnabled do
            local myChar = Player.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myRoot and not flingActive then
                local closest = nil
                local minDist = Settings.Radius
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= Player and other.Character then
                        local tRoot = other.Character:FindFirstChild("HumanoidRootPart")
                        local tHum = other.Character:FindFirstChildOfClass("Humanoid")
                        if tRoot and tHum and tHum.Health > 0 then
                            local d = (tRoot.Position - myRoot.Position).Magnitude
                            if d <= minDist then
                                minDist = d
                                closest = other.Character
                            end
                        end
                    end
                end
                if closest then
                    flingTarget(closest)
                    task.wait(0.8)
                end
            end
            task.wait(0.2)
        end
        flingLoopRunning = false
    end)
end

local function stopFlingLoop()
    flingLoopRunning = false
end

-- 2. ПОДСВЕТКА ESP
local function roleColor(role)
    if role == "Murderer" then
        return Theme.Danger
    elseif role == "Sheriff" then
        return Theme.AccentSecondary
    else
        return Theme.Success
    end
end

local function startHighlightLoop()
    if highlightLoopRunning then return end
    highlightLoopRunning = true
    task.spawn(function()
        while highlightLoopRunning and Settings.HighlightEnabled do
            for plr, hl in pairs(highlightCache) do
                if not plr.Parent or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then
                    if hl and hl.Parent then hl:Destroy() end
                    highlightCache[plr] = nil
                end
            end

            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= Player and plr.Character then
                    local char = plr.Character
                    local role = getPlayerRole(plr)
                    local color = roleColor(role)
                    local hl = highlightCache[plr]

                    if not hl or not hl.Parent then
                        hl = Instance.new("Highlight")
                        hl.Adornee = char
                        hl.FillColor = color
                        hl.FillTransparency = 0.5
                        hl.OutlineColor = color
                        hl.OutlineTransparency = 0.1
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        pcall(function() hl.Parent = char end)
                        highlightCache[plr] = hl
                    else
                        hl.FillColor = color
                        hl.OutlineColor = color
                    end
                end
            end
            task.wait(0.6)
        end

        for _, hl in pairs(highlightCache) do
            if hl and hl.Parent then hl:Destroy() end
        end
        highlightCache = {}
        highlightLoopRunning = false
    end)
end

local function stopHighlightLoop()
    highlightLoopRunning = false
    for _, hl in pairs(highlightCache) do
        if hl and hl.Parent then hl:Destroy() end
    end
    highlightCache = {}
end

-- 3. AIMBOT
local function getAimTargets()
    local targets = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
            if tHum and tHum.Health > 0 then
                local role = getPlayerRole(plr)
                if Settings.AimTarget == "Murderer" and role == "Murderer" then
                    table.insert(targets, plr)
                elseif Settings.AimTarget == "Sheriff" and role == "Sheriff" then
                    table.insert(targets, plr)
                elseif Settings.AimTarget == "Nearest" or Settings.AimTarget == "All" then
                    table.insert(targets, plr)
                end
            end
        end
    end
    return targets
end

local function getAngleToTarget(pos)
    if not camera then return 999 end
    local camPos = camera.CFrame.Position
    local lookVec = camera.CFrame.LookVector
    local dir = (pos - camPos).Unit
    local dot = math.clamp(lookVec:Dot(dir), -1, 1)
    return math.deg(math.acos(dot))
end

local function getBestAimTarget()
    local targets = getAimTargets()
    if #targets == 0 then return nil end

    local bestPlr = nil
    local bestDist = math.huge

    for _, plr in ipairs(targets) do
        local tRoot = plr.Character.HumanoidRootPart
        local angle = getAngleToTarget(tRoot.Position)
        if angle <= Settings.AimFOV then
            local dist = (tRoot.Position - camera.CFrame.Position).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestPlr = plr
            end
        end
    end
    return bestPlr
end

local function startAimLoop()
    if aimLoopRunning then return end
    aimLoopRunning = true

    aimConnection = RunService.RenderStepped:Connect(function()
        if not Settings.AimEnabled then return end

        local gun = findGun(Player)
        if not gun then
            StatusLabel.Text = "⚡ Возьми пистолет для Аима"
            return
        end

        local target = getBestAimTarget()
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local tRoot = target.Character.HumanoidRootPart
            local aimPos = tRoot.Position + Vector3.new(0, 0.4, 0)

            if Settings.AimPrediction then
                local dist = (aimPos - camera.CFrame.Position).Magnitude
                local bulletSpeed = 250
                local leadTime = dist / bulletSpeed
                aimPos = aimPos + (tRoot.Velocity * leadTime)
            end

            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, aimPos)
            StatusLabel.Text = "◎ Аим: " .. target.DisplayName
        end
    end)
end

local function stopAimLoop()
    aimLoopRunning = false
    if aimConnection then
        aimConnection:Disconnect()
        aimConnection = nil
    end
end

-- 4. АВТОПОДБОР ПИСТОЛЕТА
local function triggerGunPickup()
    if autoPickupCooldown then return end
    local myChar = Player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local drop, part = getGunDrop()
    if not part then return end

    autoPickupCooldown = true
    local oldPos = myRoot.CFrame
    StatusLabel.Text = "⚡ Подбираю пистолет..."

    myRoot.CFrame = part.CFrame * CFrame.new(0, 1, 0)
    pcall(function()
        firetouchinterest(myRoot, part, 0)
        task.wait(0.04)
        firetouchinterest(myRoot, part, 1)
    end)

    task.wait(0.15)
    if myRoot and myRoot.Parent then
        myRoot.CFrame = oldPos
    end
    StatusLabel.Text = "⚡ Пистолет подобран!"
    task.wait(0.4)
    autoPickupCooldown = false
end

local function startAutoPickupLoop()
    if autoPickupLoopRunning then return end
    autoPickupLoopRunning = true
    task.spawn(function()
        while autoPickupLoopRunning and Settings.AutoPickupEnabled do
            local drop, part = getGunDrop()
            if part and not findGun(Player) then
                triggerGunPickup()
            end
            task.wait(0.6)
        end
        autoPickupLoopRunning = false
    end)
end

local function stopAutoPickupLoop()
    autoPickupLoopRunning = false
end

-- 5. KILL AURA И KILL ALL
local function slashTarget(knife, targetChar)
    if not knife or not targetChar then return end
    local blade = knife:FindFirstChild("Handle") or knife:FindFirstChildWhichIsA("BasePart")
    if not blade then return end

    pcall(function() knife:Activate() end)

    for _, partName in ipairs({"HumanoidRootPart", "UpperTorso", "Torso", "Head"}) do
        local targetPart = targetChar:FindFirstChild(partName)
        if targetPart then
            pcall(function()
                firetouchinterest(blade, targetPart, 0)
                firetouchinterest(blade, targetPart, 1)
            end)
        end
    end
end

local function killTargetAura(targetChar)
    if not targetChar then return end
    local knife = findKnife(Player)
    if not knife then
        StatusLabel.Text = "✕ Нет ножа в инвентаре!"
        return
    end

    equipTool(knife)

    local myChar = Player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local tRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not tRoot then return end

    local oldPos = myRoot.CFrame
    myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 1.2)
    task.wait(0.04)

    slashTarget(knife, targetChar)

    task.wait(0.06)
    myRoot.CFrame = oldPos
    StatusLabel.Text = "⚔ Удар по: " .. targetChar.Name
end

local function startKillLoop()
    if killLoopRunning then return end
    killLoopRunning = true
    task.spawn(function()
        while killLoopRunning and Settings.KillEnabled do
            local knife = findKnife(Player)
            if not knife then
                StatusLabel.Text = "✕ Вы не Murderer (нет ножа)"
                task.wait(1)
            else
                local myChar = Player.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    local closest = nil
                    local minDist = Settings.KillDistance
                    for _, other in ipairs(Players:GetPlayers()) do
                        if other ~= Player and other.Character then
                            local tRoot = other.Character:FindFirstChild("HumanoidRootPart")
                            local tHum = other.Character:FindFirstChildOfClass("Humanoid")
                            if tRoot and tHum and tHum.Health > 0 and getPlayerRole(other) ~= "Murderer" then
                                local d = (tRoot.Position - myRoot.Position).Magnitude
                                if d <= minDist then
                                    minDist = d
                                    closest = other.Character
                                end
                            end
                        end
                    end
                    if closest then
                        killTargetAura(closest)
                        task.wait(0.3)
                    end
                end
            end
            task.wait(0.2)
        end
        killLoopRunning = false
    end)
end

local function stopKillLoop()
    killLoopRunning = false
end

local function performKillAll()
    if killAllActive then return end
    killAllActive = true

    local knife = findKnife(Player)
    if not knife then
        StatusLabel.Text = "✕ Нет ножа для Kill All!"
        killAllActive = false
        return
    end

    equipTool(knife)

    local myChar = Player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then killAllActive = false return end

    local originalPos = myRoot.CFrame
    StatusLabel.Text = "☠ Выполняется Kill All..."

    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= Player and target.Character then
            local tChar = target.Character
            local tRoot = tChar:FindFirstChild("HumanoidRootPart")
            local tHum = tChar:FindFirstChildOfClass("Humanoid")
            if tRoot and tHum and tHum.Health > 0 and getPlayerRole(target) ~= "Murderer" then
                myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 1.2)
                task.wait(0.08)
                slashTarget(knife, tChar)
                task.wait(0.12)
            end
        end
    end

    if myRoot and myRoot.Parent then
        myRoot.CFrame = originalPos
    end

    killAllActive = false
    StatusLabel.Text = "☠ Kill All завершен!"
end

-- 6. ТЕЛЕПОРТ
local function findTeleportTarget()
    if Settings.TeleportTarget == "GunDrop" then
        local drop, part = getGunDrop()
        return part
    end

    local targets = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local role = getPlayerRole(plr)
            if Settings.TeleportTarget == "Murderer" and role == "Murderer" then
                table.insert(targets, plr.Character.HumanoidRootPart)
            elseif Settings.TeleportTarget == "Sheriff" and role == "Sheriff" then
                table.insert(targets, plr.Character.HumanoidRootPart)
            elseif Settings.TeleportTarget == "Nearest" then
                table.insert(targets, plr.Character.HumanoidRootPart)
            end
        end
    end

    if #targets == 0 then return nil end

    local myChar = Player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return targets end

    local closest = nil
    local minDist = math.huge
    for _, r in ipairs(targets) do
        local d = (r.Position - myRoot.Position).Magnitude
        if d < minDist then
            minDist = d
            closest = r
        end
    end
    return closest
end

local function startTeleportLoop()
    if teleportLoopRunning then return end
    teleportLoopRunning = true
    task.spawn(function()
        while teleportLoopRunning and Settings.TeleportEnabled do
            local myChar = Player.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local targetRoot = findTeleportTarget()
                if targetRoot and targetRoot.Parent then
                    myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
                    StatusLabel.Text = "✦ ТП к цели (" .. Settings.TeleportTarget .. ")"
                else
                    StatusLabel.Text = "✕ Цель для ТП не найдена"
                end
            end
            task.wait(1)
        end
        teleportLoopRunning = false
    end)
end

local function stopTeleportLoop()
    teleportLoopRunning = false
end

-- 7. NOCLIP
local function startNoclip()
    if noclipRunning then return end
    noclipRunning = true
    noclipConnection = RunService.Stepped:Connect(function()
        if not Settings.NoclipEnabled then return end
        local myChar = Player.Character
        if myChar then
            for _, part in ipairs(myChar:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function stopNoclip()
    noclipRunning = false
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    local myChar = Player.Character
    if myChar and myChar:FindFirstChild("HumanoidRootPart") then
        myChar.HumanoidRootPart.CanCollide = true
    end
end

-- 8. НЕВИДИМОСТЬ (HIDE)
local function startHide()
    if hideRunning then return end
    hideRunning = true
    local myChar = Player.Character
    if myChar then
        for _, inst in ipairs(myChar:GetDescendants()) do
            if inst:IsA("BasePart") or inst:IsA("Decal") then
                hiddenParts[inst] = inst.Transparency
                inst.Transparency = 1
            end
        end
    end
end

local function stopHide()
    hideRunning = false
    for inst, oldTrans in pairs(hiddenParts) do
        if inst and inst.Parent then
            inst.Transparency = oldTrans
        end
    end
    hiddenParts = {}
end

-- ============================================================
--  НАПОЛНЕНИЕ СТРАНИЦ
-- ============================================================

-- Вкладка 1: Бой
AddToggle(CombatPage, "Флинг врагов", "Отбрасывает ближайших игроков", Settings.FlingEnabled, function(val)
    Settings.FlingEnabled = val
    SaveSettings()
    if val then startFlingLoop() else stopFlingLoop() end
end)

AddStepper(CombatPage, "Сила флинга", "Мощность вращения и удара", Settings.Power, 100, 5000, 100, "", function(val)
    Settings.Power = val
    SaveSettings()
end)

AddStepper(CombatPage, "Радиус флинга", "Дистанция поиска целей в студах", Settings.Radius, 5, 50, 5, " ст", function(val)
    Settings.Radius = val
    SaveSettings()
end)

AddToggle(CombatPage, "Kill Aura (Автоубийство)", "Атакует врагов ножом на дистанции", Settings.KillEnabled, function(val)
    Settings.KillEnabled = val
    SaveSettings()
    if val then startKillLoop() else stopKillLoop() end
end)

AddStepper(CombatPage, "Дистанция килла", "Радиус действия Kill Aura", Settings.KillDistance, 5, 50, 2, " ст", function(val)
    Settings.KillDistance = val
    SaveSettings()
end)

AddActionButton(CombatPage, "Kill All (Убить всех)", "Однократно убивает всех игроков на сервере", "Казнить всех", Theme.Danger, function()
    performKillAll()
end)

-- Вкладка 2: Аим & Визуал
AddToggle(VisualPage, "AimBot (Автоприцел)", "Наводит револьвер на выбранную цель", Settings.AimEnabled, function(val)
    Settings.AimEnabled = val
    SaveSettings()
    if val then startAimLoop() else stopAimLoop() end
end)

AddSelector(VisualPage, "Цель аимбота", "Кого брать в прицел в первую очередь", {"Murderer", "Sheriff", "Nearest", "All"}, Settings.AimTarget, function(val)
    Settings.AimTarget = val
    SaveSettings()
end)

AddStepper(VisualPage, "Радиус FOV", "Угол захвата цели для аимбота", Settings.AimFOV, 10, 90, 5, "°", function(val)
    Settings.AimFOV = val
    SaveSettings()
end)

AddToggle(VisualPage, "Упреждение движения", "Компенсация скорости движения пули", Settings.AimPrediction, function(val)
    Settings.AimPrediction = val
    SaveSettings()
end)

AddToggle(VisualPage, "Подсветка игроков (ESP)", "Красный - Murderer, Синий - Sheriff, Зеленый - Innocent", Settings.HighlightEnabled, function(val)
    Settings.HighlightEnabled = val
    SaveSettings()
    if val then startHighlightLoop() else stopHighlightLoop() end
end)

-- Вкладка 3: Разное
AddToggle(MiscPage, "Автоподбор пистолета", "Моментально подбирает выпавший револьвер", Settings.AutoPickupEnabled, function(val)
    Settings.AutoPickupEnabled = val
    SaveSettings()
    if val then startAutoPickupLoop() else stopAutoPickupLoop() end
end)

AddActionButton(MiscPage, "Взять пистолет сейчас", "Разовый подбор выпавшего оружия", "Подобрать", Theme.AccentSecondary, function()
    triggerGunPickup()
end)

AddToggle(MiscPage, "Noclip (Сквозь стены)", "Хождение сквозь любые препятствия", Settings.NoclipEnabled, function(val)
    Settings.NoclipEnabled = val
    SaveSettings()
    if val then startNoclip() else stopNoclip() end
end)

AddToggle(Settings()
    if val then startNoclip() else stopNoclip() end
end)

AddToggle(MiscPage, "Невидимость (Hide)", "Скрывает скин, лицо и аксессуары", Settings.HideEnabled, function(val)
    Settings.HideEnabled = val
    SaveSettings()
    if val then startHide() else stopHide() end
end)

AddToggle(MiscPage, "Авто-телепорт (Цикл)", "Постоянно следует за выбранной целью", Settings.TeleportEnabled, function(val)
    Settings.TeleportEnabled = val
    SaveSettings()
    if val then startTeleportLoop() else stopTeleportLoop() end
end)

AddSelector(MiscPage, "Цель телепорта", "Куда телепортироваться", {"Murderer", "Sheriff", "GunDrop", "Nearest"}, Settings.TeleportTarget, function(val)
    Settings.TeleportTarget = val
    SaveSettings()
end)

-- ============================================================
--  ОТКРЫТИЕ / ЗАКРЫТИЕ МЕНЮ (TOGGLE GUI)
-- ============================================================
local menuOpen = true

local function ToggleMenu()
    menuOpen = not menuOpen
    Main.Visible = menuOpen
    if menuOpen then
        Main.Size = UDim2.new(0, win_w, 0, win_h)
    end
end

-- Клик по плавающей иконке
FloatButton.MouseButton1Click:Connect(ToggleMenu)

-- Кнопка свернуть и закрыть в шапке
MinBtn.MouseButton1Click:Connect(ToggleMenu)
CloseBtn.MouseButton1Click:Connect(ToggleMenu)

-- Горячая клавиша для ПК (RightControl или V)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.V then
        ToggleMenu()
    end
end)

-- ============================================================
--  ПЕРЕМЕЩЕНИЕ ГЛАВНОГО ОКНА (DRAG)
-- ============================================================
local dragging = false
local dragStart = nil
local startPos = nil

DragArea.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging or not dragStart or not startPos then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local delta = (input.Position - dragStart) / UIScale.Scale
        Main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ============================================================
--  ФОНОВОЕ ОБНОВЛЕНИЕ РОЛИ И СТАТУСА
-- ============================================================
task.spawn(function()
    while ScreenGui.Parent do
        local role = getPlayerRole(Player)
        RoleBadge.Text = role
        if role == "Murderer" then
            RoleBadge.TextColor3 = Theme.Danger
            RoleBadge.BackgroundColor3 = Color3.fromRGB(45, 18, 22)
        elseif role == "Sheriff" then
            RoleBadge.TextColor3 = Theme.AccentSecondary
            RoleBadge.BackgroundColor3 = Color3.fromRGB(15, 35, 45)
        else
            RoleBadge.TextColor3 = Theme.Success
            RoleBadge.BackgroundColor3 = Color3.fromRGB(18, 38, 24)
        end

        local activeCount = 0
        if Settings.FlingEnabled then activeCount = activeCount + 1 end
        if Settings.KillEnabled then activeCount = activeCount + 1 end
        if Settings.AimEnabled then activeCount = activeCount + 1 end
        if Settings.HighlightEnabled then activeCount = activeCount + 1 end
        if Settings.AutoPickupEnabled then activeCount = activeCount + 1 end
        if Settings.NoclipEnabled then activeCount = activeCount + 1 end

        IconBadge.BackgroundColor3 = (activeCount > 0) and Theme.Success or Theme.TextMuted

        task.wait(1)
    end
end)

-- ============================================================
--  ЗАПУСК АКТИВНЫХ СИСТЕМ
-- ============================================================
if Settings.FlingEnabled then startFlingLoop() end
if Settings.HighlightEnabled then startHighlightLoop() end
if Settings.AimEnabled then startAimLoop() end
if Settings.AutoPickupEnabled then startAutoPickupLoop() end
if Settings.KillEnabled then startKillLoop() end
if Settings.TeleportEnabled then startTeleportLoop() end
if Settings.NoclipEnabled then startNoclip() end
if Settings.HideEnabled then startHide() end

print("⚡ LoScript MM2 (v11 PRO) успешно запущен!")
