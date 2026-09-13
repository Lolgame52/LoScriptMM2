-- ============================================================
--  LoScript For MM2 (v11 ULTRA FIXED)
--  Полный редизайн интерфейса | Неоновая плавающая иконка
--  Исправление всех функций: Role Check, Fling, Kill Aura,
--  Kill All, GunDrop Auto-Pickup, AimBot с упреждением, ESP
-- ============================================================

repeat task.wait() until game:IsLoaded()

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

-- ============================================================
--  НАСТРОЙКИ (АВТОСОХРАНЕНИЕ В JSON)
-- ============================================================
local Settings = {
    FlingEnabled = false,
    Power = 500,                  -- Сила флинга (вращение + импульс)
    Radius = 15,                  -- Радиус поиска целей для флинга
    HighlightEnabled = true,      -- Подсветка игроков (ESP)
    EspNamesEnabled = true,       -- Таблички с именами и дистанцией
    AimEnabled = false,           -- AimBot
    AimFOV = 35,                  -- Радиус FOV
    AimTarget = "Murderer",       -- Murderer, Sheriff, Nearest, All
    AimPrediction = true,         -- Упреждение движения пули
    AimSmoothness = 0.85,         -- Плавность (1 = моментально)
    AutoPickupEnabled = false,    -- Автоподбор пистолета
    KillEnabled = false,          -- Kill Aura (Автоубийство)
    KillDistance = 15,            -- Дистанция для Kill Aura
    TeleportEnabled = false,      -- Авто-телепорт (цикл)
    TeleportTarget = "Murderer",   -- Murderer, Sheriff, GunDrop, Nearest
    NoclipEnabled = false,        -- Noclip (хождение сквозь стены)
    HideEnabled = false,          -- Невидимость (Hide)
}

local CONFIG_FILE = "loscript_mm2_v11.json"

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

-- ============================================================
--  ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ И СОСТОЯНИЯ
-- ============================================================
local character = Player.Character
local rootPart = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")

local flingActive = false
local flingLoopRunning = false
local flingCount = 0

local highlightLoopRunning = false
local highlightCache = {}
local espBillboardCache = {}

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

-- Авто-обновление персонажа при смерти / спавне
local function OnCharacterAdded(newChar)
    character = newChar
    rootPart = character:WaitForChild("HumanoidRootPart", 5)
    humanoid = character:WaitForChild("Humanoid", 5)

    -- Сохраняем Noclip при респавне
    if Settings.NoclipEnabled and noclipRunning then
        task.wait(0.1)
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end

    -- Сохраняем Hide при респавне
    if Settings.HideEnabled and hideRunning then
        task.wait(0.2)
        for _, inst in ipairs(character:GetDescendants()) do
            if inst:IsA("BasePart") or inst:IsA("Decal") then
                hiddenParts[inst] = inst.Transparency
                inst.Transparency = 1
            end
        end
    end
end

if character then
    OnCharacterAdded(character)
end
Player.CharacterAdded:Connect(OnCharacterAdded)

-- ============================================================
--  НАДЕЖНОЕ ОПРЕДЕЛЕНИЕ РОЛЕЙ И ОРУЖИЯ MM2
--  (Поддержка всех годли, древних и кастомных скинов)
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

    local function checkFolder(folder)
        if not folder then return nil end
        for _, item in ipairs(folder:GetChildren()) do
            if isKnifeTool(item) then
                return "Murderer"
            elseif isGunTool(item) then
                return "Sheriff"
            end
        end
        return nil
    end

    local role = checkFolder(char) or checkFolder(backpack)
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
    if tool.Parent == Player:FindFirstChild("Backpack") and character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:EquipTool(tool)
            task.wait(0.08)
        end
    end
end

-- Поиск выпавшего пистолета на карте
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
--  ЦВЕТОВАЯ ПАЛИТРА И ТЕМА (CYBERPUNK NEON)
-- ============================================================
local Theme = {
    Background = Color3.fromRGB(13, 14, 22),
    Panel = Color3.fromRGB(20, 22, 34),
    Card = Color3.fromRGB(26, 29, 44),
    CardHover = Color3.fromRGB(34, 38, 58),
    Border = Color3.fromRGB(45, 49, 75),
    BorderActive = Color3.fromRGB(168, 85, 247),
    Accent = Color3.fromRGB(168, 85, 247),        -- Неоновый фиолетовый
    AccentGlow = Color3.fromRGB(192, 132, 252),
    AccentSecondary = Color3.fromRGB(6, 182, 212), -- Неоновый бирюзовый
    Success = Color3.fromRGB(34, 197, 94),       -- Неоновый зеленый
    Danger = Color3.fromRGB(239, 68, 68),        -- Красный (Murderer)
    Warning = Color3.fromRGB(245, 158, 11),      -- Желтый
    Text = Color3.fromRGB(245, 247, 255),
    TextMuted = Color3.fromRGB(148, 155, 180),
    TextDark = Color3.fromRGB(90, 96, 120),
}

local FontBold = Font.fromEnum(Enum.Font.GothamBold)
local FontMedium = Font.fromEnum(Enum.Font.GothamMedium)

local function Create(className, properties)
    local inst = Instance.new(className)
    for k, v in pairs(properties) do
        if k ~= "Parent" then
            pcall(function() inst[k] = v end)
        end
    end
    if properties.Parent then inst.Parent = properties.Parent end
    return inst
end

local function Corner(parent, radius)
    return Create("UICorner", {
        Parent = parent,
        CornerRadius = UDim.new(0, radius or 8),
    })
end

local function Stroke(parent, color, thickness, transparency)
    return Create("UIStroke", {
        Parent = parent,
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function Tween(inst, info, goal)
    local tw = TweenService:Create(inst, info or TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
    tw:Play()
    return tw
end

-- ============================================================
--  ЭКРАН И GUI
-- ============================================================
local ScreenGui = Create("ScreenGui", {
    Parent = game:GetService("CoreGui"),
    Name = "LoScriptMM2_Ultra",
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 1000,
    ResetOnSpawn = false,
})

local UIScale = Create("UIScale", {
    Parent = ScreenGui,
    Scale = IsMobile and 0.88 or 1,
})

-- ============================================================
--  КРАСИВАЯ ПЛАВАЮЩАЯ НЕОНОВАЯ ИКОНКА (TOGGLE BUTTON)
-- ============================================================
local FloatIcon = Create("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(0, 56, 0, 56),
    Position = UDim2.new(0, 24, 0.45, 0),
    BackgroundColor3 = Theme.Panel,
    BackgroundTransparency = 0.05,
    ZIndex = 10,
    Active = true,
})
Corner(FloatIcon, 16)
local FloatStroke = Stroke(FloatIcon, Theme.Accent, 2, 0.1)

local FloatGradient = Create("UIGradient", {
    Parent = FloatStroke,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Accent),
        ColorSequenceKeypoint.new(0.5, Theme.AccentSecondary),
        ColorSequenceKeypoint.new(1, Theme.Accent),
    }),
    Rotation = 45,
})

task.spawn(function()
    while FloatIcon.Parent do
        FloatGradient.Rotation = (FloatGradient.Rotation + 2) % 360
        task.wait(0.04)
    end
end)

local IconGraphic = Create("TextLabel", {
    Parent = FloatIcon,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "⚡",
    TextColor3 = Theme.Text,
    TextSize = 26,
    FontFace = FontBold,
    ZIndex = 11,
})

local IconBadge = Create("Frame", {
    Parent = FloatIcon,
    Size = UDim2.new(0, 12, 0, 12),
    Position = UDim2.new(1, -5, 0, -3),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Theme.Success,
    ZIndex = 12,
})
Corner(IconBadge, 6)
Stroke(IconBadge, Theme.Background, 1.5)

-- Кнопка для взаимодействия и перетаскивания иконки
local FloatClickArea = Create("TextButton", {
    Parent = FloatIcon,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "",
    ZIndex = 13,
})

-- Forward declaration для функции переключения меню
local ToggleMenu

local floatDragging = false
local floatDragStart = nil
local floatStartPos = nil
local floatStartTime = 0

FloatClickArea.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        floatDragging = true
        floatDragStart = input.Position
        floatStartPos = FloatIcon.Position
        floatStartTime = tick()
        Tween(FloatIcon, TweenInfo.new(0.15), { Size = UDim2.new(0, 52, 0, 52) })
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not floatDragging then return end
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

FloatClickArea.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        floatDragging = false
        Tween(FloatIcon, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, 56, 0, 56) })

        -- Если перемещение было меньше 8 пикселей - это клик!
        local distMoved = (input.Position - floatDragStart).Magnitude
        if distMoved < 8 and (tick() - floatStartTime < 0.6) then
            if ToggleMenu then ToggleMenu() end
        end
    end
end)

-- ============================================================
--  ОСНОВНОЕ ОКНО GUI
-- ============================================================
local win_w = IsMobile and 390 or 440
local win_h = IsMobile and 540 or 580

local Main = Create("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(0, win_w, 0, win_h),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Theme.Background,
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 2,
    Visible = true,
})
Corner(Main, 14)
local MainStroke = Stroke(Main, Theme.Border, 1.5, 0.1)

local MainGradient = Create("UIGradient", {
    Parent = MainStroke,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Accent),
        ColorSequenceKeypoint.new(0.5, Theme.AccentSecondary),
        ColorSequenceKeypoint.new(1, Theme.Border),
    }),
    Rotation = 135,
})

-- ШАПКА ОКНА (HEADER)
local header_h = 52
local Header = Create("Frame", {
    Parent = Main,
    Size = UDim2.new(1, 0, 0, header_h),
    BackgroundColor3 = Theme.Panel,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    ZIndex = 3,
})
Corner(Header, 14)

local HeaderBottomCover = Create("Frame", {
    Parent = Header,
    Size = UDim2.new(1, 0, 0, 14),
    Position = UDim2.new(0, 0, 1, -14),
    BackgroundColor3 = Theme.Panel,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    ZIndex = 3,
})

Create("Frame", {
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
    Size = UDim2.new(0, 32, 0, 32),
    Position = UDim2.new(0, 14, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Theme.Card,
    Text = "⚡",
    TextColor3 = Theme.Accent,
    TextSize = 18,
    FontFace = FontBold,
    ZIndex = 5,
})
Corner(TitleIcon, 8)
Stroke(TitleIcon, Theme.Accent, 1, 0.4)

local TitleLabel = Create("TextLabel", {
    Parent = Header,
    Size = UDim2.new(0, 140, 1, 0),
    Position = UDim2.new(0, 54, 0, 0),
    BackgroundTransparency = 1,
    Text = "LoScript MM2",
    TextColor3 = Theme.Text,
    TextSize = 16,
    FontFace = FontBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 5,
})

local VersionPill = Create("Frame", {
    Parent = Header,
    Size = UDim2.new(0, 68, 0, 20),
    Position = UDim2.new(0, 175, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Theme.Card,
    ZIndex = 5,
})
Corner(VersionPill, 10)
Stroke(VersionPill, Theme.AccentSecondary, 1, 0.4)

Create("TextLabel", {
    Parent = VersionPill,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "v11 ULTRA",
    TextColor3 = Theme.AccentSecondary,
    TextSize = 10,
    FontFace = FontBold,
    ZIndex = 6,
})

local HeaderBtnContainer = Create("Frame", {
    Parent = Header,
    Size = UDim2.new(0, 72, 1, 0),
    Position = UDim2.new(1, -12, 0, 0),
    AnchorPoint = Vector2.new(1, 0),
    BackgroundTransparency = 1,
    ZIndex = 5,
})
Create("UIListLayout", {
    Parent = HeaderBtnContainer,
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 8),
})

local MinBtn = Create("TextButton", {
    Parent = HeaderBtnContainer,
    Size = UDim2.new(0, 28, 0, 28),
    BackgroundColor3 = Theme.Card,
    Text = "−",
    TextColor3 = Theme.TextMuted,
    TextSize = 18,
    FontFace = FontBold,
    AutoButtonColor = false,
    ZIndex = 6,
})
Corner(MinBtn, 8)
Stroke(MinBtn, Theme.Border, 1)

local CloseBtn = Create("TextButton", {
    Parent = HeaderBtnContainer,
    Size = UDim2.new(0, 28, 0, 28),
    BackgroundColor3 = Theme.Card,
    Text = "✕",
    TextColor3 = Theme.TextMuted,
    TextSize = 13,
    FontFace = FontBold,
    AutoButtonColor = false,
    ZIndex = 6,
})
Corner(CloseBtn, 8)
Stroke(CloseBtn, Theme.Border, 1)

-- ============================================================
--  ТАБЫ (ВКЛАДКИ)
-- ============================================================
local tab_h = 42
local TabBar = Create("Frame", {
    Parent = Main,
    Size = UDim2.new(1, -24, 0, tab_h),
    Position = UDim2.new(0, 12, 0, header_h + 8),
    BackgroundColor3 = Theme.Panel,
    BackgroundTransparency = 0.5,
    ZIndex = 3,
})
Corner(TabBar, 10)
Stroke(TabBar, Theme.Border, 1, 0.4)

Create("UIListLayout", {
    Parent = TabBar,
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 6),
})

-- ============================================================
--  ФУТЕР (СТАТУС БАР)
-- ============================================================
local footer_h = 36
local Footer = Create("Frame", {
    Parent = Main,
    Size = UDim2.new(1, 0, 0, footer_h),
    Position = UDim2.new(0, 0, 1, -footer_h),
    BackgroundColor3 = Theme.Panel,
    BackgroundTransparency = 0.4,
    ZIndex = 3,
})
Create("Frame", {
    Parent = Footer,
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = Theme.Border,
    BorderSizePixel = 0,
    ZIndex = 4,
})

local StatusIndicator = Create("Frame", {
    Parent = Footer,
    Size = UDim2.new(0, 8, 0, 8),
    Position = UDim2.new(0, 14, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Theme.Success,
    ZIndex = 5,
})
Corner(StatusIndicator, 4)

local StatusLabel = Create("TextLabel", {
    Parent = Footer,
    Size = UDim2.new(1, -150, 1, 0),
    Position = UDim2.new(0, 30, 0, 0),
    BackgroundTransparency = 1,
    Text = "Готов к игре | Роль: Загрузка...",
    TextColor3 = Theme.TextMuted,
    TextSize = 12,
    FontFace = FontMedium,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 5,
})

local RoleBadge = Create("TextLabel", {
    Parent = Footer,
    Size = UDim2.new(0, 100, 0, 22),
    Position = UDim2.new(1, -12, 0.5, 0),
    AnchorPoint = Vector2.new(1, 0.5),
    BackgroundColor3 = Theme.Card,
    Text = "Innocent",
    TextColor3 = Theme.Success,
    TextSize = 11,
    FontFace = FontBold,
    ZIndex = 5,
})
Corner(RoleBadge, 6)
Stroke(RoleBadge, Theme.Border, 1)

-- ============================================================
--  КОНТЕЙНЕР ДЛЯ СТРАНИЦ
-- ============================================================
local PagesContainer = Create("Frame", {
    Parent = Main,
    Size = UDim2.new(1, 0, 1, -(header_h + tab_h + footer_h + 16)),
    Position = UDim2.new(0, 0, 0, header_h + tab_h + 12),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
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
        Padding = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    })
    Create("UIPadding", {
        Parent = scroll,
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
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
        Tween(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = isActive and Theme.Accent or Theme.Card,
            TextColor3 = isActive and Theme.Text or Theme.TextMuted,
        })
    end
end

local function AddTabButton(tabName, icon, label)
    local btn = Create("TextButton", {
        Parent = TabBar,
        Size = UDim2.new(0.31, 0, 0, 30),
        BackgroundColor3 = (tabName == currentTab) and Theme.Accent or Theme.Card,
        Text = icon .. " " .. label,
        TextColor3 = (tabName == currentTab) and Theme.Text or Theme.TextMuted,
        TextSize = IsMobile and 13 or 12,
        FontFace = FontBold,
        AutoButtonColor = false,
        ZIndex = 4,
    })
    Corner(btn, 8)
    Stroke(btn, Theme.Border, 1, 0.3)
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
--  КОМПОНЕНТЫ ИНТЕРФЕЙСА (TOGGLE, STEPPER, SELECTOR, ACTION)
-- ============================================================
local function AddToggle(parent, title, desc, defaultState, callback)
    local card = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    Corner(card, 10)
    local cardStroke = Stroke(card, Theme.Border, 1, 0.4)

    Create("TextLabel", {
        Parent = card,
        Size = UDim2.new(1, -70, 0, 20),
        Position = UDim2.new(0, 14, 0, 8),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 14,
        FontFace = FontBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    Create("TextLabel", {
        Parent = card,
        Size = UDim2.new(1, -70, 0, 18),
        Position = UDim2.new(0, 14, 0, 28),
        BackgroundTransparency = 1,
        Text = desc or "",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        FontFace = FontMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    local switchTrack = Create("Frame", {
        Parent = card,
        Size = UDim2.new(0, 44, 0, 24),
        Position = UDim2.new(1, -14, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = defaultState and Theme.Accent or Color3.fromRGB(40, 44, 62),
        BorderSizePixel = 0,
        ZIndex = 6,
    })
    Corner(switchTrack, 12)

    local switchThumb = Create("Frame", {
        Parent = switchTrack,
        Size = UDim2.new(0, 18, 0, 18),
        Position = defaultState and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 7,
    })
    Corner(switchThumb, 9)

    local state = defaultState

    local function SetState(val)
        state = val
        Tween(switchTrack, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(40, 44, 62),
        })
        Tween(switchThumb, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        })
        Tween(cardStroke, TweenInfo.new(0.2), {
            Color = state and Theme.BorderActive or Theme.Border,
        })
        if callback then callback(state) end
    end

    local clickBtn = Create("TextButton", {
        Parent = card,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 8,
    })

    clickBtn.MouseButton1Click:Connect(function()
        SetState(not state)
    end)

    return {
        Get = function() return state end,
        Set = SetState,
    }
end

local function AddStepper(parent, title, desc, defaultValue, minVal, maxVal, step, unit, callback)
    local card = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    Corner(card, 10)
    Stroke(card, Theme.Border, 1, 0.4)

    Create("TextLabel", {
        Parent = card,
        Size = UDim2.new(1, -150, 0, 20),
        Position = UDim2.new(0, 14, 0, 8),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 14,
        FontFace = FontBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    Create("TextLabel", {
        Parent = card,
        Size = UDim2.new(1, -150, 0, 18),
        Position = UDim2.new(0, 14, 0, 28),
        BackgroundTransparency = 1,
        Text = desc or "",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        FontFace = FontMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    local ctrlFrame = Create("Frame", {
        Parent = card,
        Size = UDim2.new(0, 130, 0, 32),
        Position = UDim2.new(1, -12, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Theme.Panel,
        ZIndex = 6,
    })
    Corner(ctrlFrame, 8)
    Stroke(ctrlFrame, Theme.Border, 1, 0.3)

    local decBtn = Create("TextButton", {
        Parent = ctrlFrame,
        Size = UDim2.new(0, 32, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Theme.Card,
        Text = "−",
        TextColor3 = Theme.Text,
        TextSize = 18,
        FontFace = FontBold,
        AutoButtonColor = false,
        ZIndex = 7,
    })
    Corner(decBtn, 6)

    local valueLbl = Create("TextLabel", {
        Parent = ctrlFrame,
        Size = UDim2.new(1, -64, 1, 0),
        Position = UDim2.new(0, 32, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(defaultValue) .. (unit or ""),
        TextColor3 = Theme.AccentGlow,
        TextSize = 13,
        FontFace = FontBold,
        ZIndex = 7,
    })

    local incBtn = Create("TextButton", {
        Parent = ctrlFrame,
        Size = UDim2.new(0, 32, 1, 0),
        Position = UDim2.new(1, -32, 0, 0),
        BackgroundColor3 = Theme.Card,
        Text = "+",
        TextColor3 = Theme.Text,
        TextSize = 18,
        FontFace = FontBold,
        AutoButtonColor = false,
        ZIndex = 7,
    })
    Corner(incBtn, 6)

    local currentValue = defaultValue

    local function UpdateVal(newVal)
        currentValue = math.clamp(newVal, minVal, maxVal)
        valueLbl.Text = tostring(currentValue) .. (unit or "")
        if callback then callback(currentValue) end
    end

    decBtn.MouseButton1Click:Connect(function()
        UpdateVal(currentValue - step)
    end)
    incBtn.MouseButton1Click:Connect(function()
        UpdateVal(currentValue + step)
    end)

    return {
        Get = function() return currentValue end,
        Set = UpdateVal,
    }
end

local function AddSelector(parent, title, desc, options, defaultOption, callback)
    local card = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    Corner(card, 10)
    Stroke(card, Theme.Border, 1, 0.4)

    Create("TextLabel", {
        Parent = card,
        Size = UDim2.new(1, -140, 0, 20),
        Position = UDim2.new(0, 14, 0, 8),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 14,
        FontFace = FontBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    Create("TextLabel", {
        Parent = card,
        Size = UDim2.new(1, -140, 0, 18),
        Position = UDim2.new(0, 14, 0, 28),
        BackgroundTransparency = 1,
        Text = desc or "",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        FontFace = FontMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    local selectBtn = Create("TextButton", {
        Parent = card,
        Size = UDim2.new(0, 115, 0, 32),
        Position = UDim2.new(1, -12, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Theme.Panel,
        Text = defaultOption,
        TextColor3 = Theme.AccentSecondary,
        TextSize = 13,
        FontFace = FontBold,
        AutoButtonColor = false,
        ZIndex = 6,
    })
    Corner(selectBtn, 8)
    Stroke(selectBtn, Theme.AccentSecondary, 1, 0.4)

    local currentIdx = 1
    for i, v in ipairs(options) do
        if v == defaultOption then currentIdx = i break end
    end

    local function NextOption()
        currentIdx = (currentIdx % #options) + 1
        local newOpt = options[currentIdx]
        selectBtn.Text = newOpt
        Tween(selectBtn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.CardHover })
        task.wait(0.1)
        Tween(selectBtn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.Panel })
        if callback then callback(newOpt) end
    end

    selectBtn.MouseButton1Click:Connect(NextOption)

    return {
        Get = function() return options[currentIdx] end,
        Set = function(val)
            for i, v in ipairs(options) do
                if v == val then
                    currentIdx = i
                    selectBtn.Text = val
                    if callback then callback(val) end
                    break
                end
            end
        end,
    }
end

local function AddActionButton(parent, title, desc, btnText, btnColor, callback)
    local card = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    Corner(card, 10)
    Stroke(card, Theme.Border, 1, 0.4)

    Create("TextLabel", {
        Parent = card,
        Size = UDim2.new(1, -140, 0, 20),
        Position = UDim2.new(0, 14, 0, 8),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 14,
        FontFace = FontBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    Create("TextLabel", {
        Parent = card,
        Size = UDim2.new(1, -140, 0, 18),
        Position = UDim2.new(0, 14, 0, 28),
        BackgroundTransparency = 1,
        Text = desc or "",
        TextColor3 = Theme.TextMuted,
        TextSize = 11,
        FontFace = FontMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    local actBtn = Create("TextButton", {
        Parent = card,
        Size = UDim2.new(0, 115, 0, 32),
        Position = UDim2.new(1, -12, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = btnColor or Theme.Accent,
        Text = btnText or "Запустить",
        TextColor3 = Theme.Text,
        TextSize = 12,
        FontFace = FontBold,
        AutoButtonColor = false,
        ZIndex = 6,
    })
    Corner(actBtn, 8)
    Stroke(actBtn, Theme.Border, 1, 0.2)

    actBtn.MouseButton1Click:Connect(function()
        Tween(actBtn, TweenInfo.new(0.1), { Size = UDim2.new(0, 110, 0, 30) })
        task.wait(0.1)
        Tween(actBtn, TweenInfo.new(0.15), { Size = UDim2.new(0, 115, 0, 32) })
        if callback then callback() end
    end)
end

-- ============================================================
--  ЛОГИКА ФУНКЦИЙ (ИСПРАВЛЕНЫ ВСЕ БАГИ)
-- ============================================================

-- Forward declarations
local startFlingLoop, stopFlingLoop
local startHighlightLoop, stopHighlightLoop
local startAimLoop, stopAimLoop
local startAutoPickupLoop, stopAutoPickupLoop
local startKillLoop, stopKillLoop
local performKillAll
local startTeleportLoop, stopTeleportLoop
local startNoclip, stopNoclip
local startHide, stopHide

-- ------------------------------------------------------------
--  1. ФЛИНГ (Исправлено применение силы и коллизия)
-- ------------------------------------------------------------
local function flingTarget(targetChar)
    if not targetChar or flingActive then return false end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not targetRoot or not myRoot or not hum then return false end

    flingActive = true
    local oldCFrame = myRoot.CFrame
    local oldCollision = {}

    -- Отключаем сидение, чтобы персонаж не падал
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    hum.Sit = false

    -- Включаем коллизию на локальном игроке для передачи импульса
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            oldCollision[part] = part.CanCollide
            part.CanCollide = true
        end
    end

    -- Настоящая передача силы флинга
    local spinVelocity = Vector3.new(0, Settings.Power * 100, 0)
    local thrustVelocity = Vector3.new(90000, 90000, 90000)

    local bav = Instance.new("BodyAngularVelocity")
    bav.AngularVelocity = spinVelocity
    bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bav.P = math.huge
    bav.Parent = myRoot

    local startTime = tick()
    while tick() - startTime < 0.35 do
        if not targetRoot or not targetRoot.Parent then break end
        myRoot.CFrame = targetRoot.CFrame + (targetRoot.Velocity * 0.05)
        pcall(function()
            myRoot.AssemblyAngularVelocity = spinVelocity
            myRoot.AssemblyLinearVelocity = thrustVelocity
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

    for part, col in pairs(oldCollision) do
        if part and part.Parent then
            part.CanCollide = col
        end
    end
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)

    flingActive = false
    flingCount = flingCount + 1
    StatusLabel.Text = "● Флинг успешен! Всего: " .. flingCount
    return true
end

startFlingLoop = function()
    if flingLoopRunning then return end
    flingLoopRunning = true
    task.spawn(function()
        while flingLoopRunning and Settings.FlingEnabled do
            local myRoot = character and character:FindFirstChild("HumanoidRootPart")
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

stopFlingLoop = function()
    flingLoopRunning = false
end

-- ------------------------------------------------------------
--  2. ПОДСВЕТКА РОЛЕЙ ESP (Исправлено распознавание всех скинов)
-- ------------------------------------------------------------
local function roleColor(role)
    if role == "Murderer" then
        return Theme.Danger
    elseif role == "Sheriff" then
        return Theme.AccentSecondary
    else
        return Theme.Success
    end
end

startHighlightLoop = function()
    if highlightLoopRunning then return end
    highlightLoopRunning = true
    task.spawn(function()
        while highlightLoopRunning and Settings.HighlightEnabled do
            for plr, hl in pairs(highlightCache) do
                if not plr.Parent or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then
                    if hl and hl.Parent then hl:Destroy() end
                    highlightCache[plr] = nil
                    if espBillboardCache[plr] and espBillboardCache[plr].Parent then
                        espBillboardCache[plr]:Destroy()
                        espBillboardCache[plr] = nil
                    end
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
                        hl.FillTransparency = 0.45
                        hl.OutlineColor = color
                        hl.OutlineTransparency = 0.1
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent = char
                        highlightCache[plr] = hl
                    else
                        hl.FillColor = color
                        hl.OutlineColor = color
                    end

                    -- Табличка над головой с именем и дистанцией
                    if Settings.EspNamesEnabled and char:FindFirstChild("Head") then
                        local bb = espBillboardCache[plr]
                        if not bb or not bb.Parent then
                            bb = Instance.new("BillboardGui")
                            bb.Name = "LoESP"
                            bb.Size = UDim2.new(0, 120, 0, 40)
                            bb.StudsOffset = Vector3.new(0, 2.5, 0)
                            bb.AlwaysOnTop = true
                            bb.Adornee = char.Head
                            bb.Parent = char.Head

                            local nameLbl = Instance.new("TextLabel")
                            nameLbl.Name = "Info"
                            nameLbl.Size = UDim2.new(1, 0, 1, 0)
                            nameLbl.BackgroundTransparency = 1
                            nameLbl.TextColor3 = color
                            nameLbl.TextStrokeTransparency = 0.2
                            nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                            nameLbl.FontFace = FontBold
                            nameLbl.TextSize = 12
                            nameLbl.Parent = bb
                            espBillboardCache[plr] = bb
                        else
                            local infoLbl = bb:FindFirstChild("Info")
                            if infoLbl then
                                local dist = 0
                                if rootPart and char:FindFirstChild("HumanoidRootPart") then
                                    dist = math.floor((char.HumanoidRootPart.Position - rootPart.Position).Magnitude)
                                end
                                infoLbl.Text = plr.DisplayName .. "\n[" .. role .. " - " .. dist .. "m]"
                                infoLbl.TextColor3 = color
                            end
                        end
                    end
                end
            end
            task.wait(0.5)
        end

        for _, hl in pairs(highlightCache) do
            if hl and hl.Parent then hl:Destroy() end
        end
        highlightCache = {}

        for _, bb in pairs(espBillboardCache) do
            if bb and bb.Parent then bb:Destroy() end
        end
        espBillboardCache = {}

        highlightLoopRunning = false
    end)
end

stopHighlightLoop = function()
    highlightLoopRunning = false
    for _, hl in pairs(highlightCache) do
        if hl and hl.Parent then hl:Destroy() end
    end
    highlightCache = {}

    for _, bb in pairs(espBillboardCache) do
        if bb and bb.Parent then bb:Destroy() end
    end
    espBillboardCache = {}
end

-- ------------------------------------------------------------
--  3. AIMBOT С ПРЕДСКАЗАНИЕМ И FOV-КРУГОМ
-- ------------------------------------------------------------
local FOVCircle = Create("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(0, Settings.AimFOV * 8, 0, Settings.AimFOV * 8),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 1,
})
Corner(FOVCircle, 1000)
local FOVStroke = Stroke(FOVCircle, Theme.AccentGlow, 1.5, 0.3)

local function updateFOVCircle()
    local fovSize = Settings.AimFOV * 8
    FOVCircle.Size = UDim2.new(0, fovSize, 0, fovSize)
    FOVCircle.Visible = Settings.AimEnabled
end

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
    local bestScore = math.huge

    for _, plr in ipairs(targets) do
        local tRoot = plr.Character.HumanoidRootPart
        local angle = getAngleToTarget(tRoot.Position)
        if angle <= Settings.AimFOV then
            local dist = (tRoot.Position - camera.CFrame.Position).Magnitude
            local score = (Settings.AimTarget == "Nearest") and dist or angle
            if score < bestScore then
                bestScore = score
                bestPlr = plr
            end
        end
    end
    return bestPlr
end

startAimLoop = function()
    if aimLoopRunning then return end
    aimLoopRunning = true
    updateFOVCircle()

    aimConnection = RunService.RenderStepped:Connect(function()
        if not Settings.AimEnabled then return end

        local gun = findGun(Player)
        if not gun then
            StatusLabel.Text = "⚡ Нужен пистолет для Аима"
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

            local targetCFrame = CFrame.lookAt(camera.CFrame.Position, aimPos)
            if Settings.AimSmoothness >= 1 then
                camera.CFrame = targetCFrame
            else
                camera.CFrame = camera.CFrame:Lerp(targetCFrame, Settings.AimSmoothness)
            end
            StatusLabel.Text = "◎ Захват цели: " .. target.DisplayName
        end
    end)
end

stopAimLoop = function()
    aimLoopRunning = false
    FOVCircle.Visible = false
    if aimConnection then
        aimConnection:Disconnect()
        aimConnection = nil
    end
end

-- ------------------------------------------------------------
--  4. АВТОПОДБОР ПИСТОЛЕТА (Безопасный CFrame + возврат)
-- ------------------------------------------------------------
local function triggerGunPickup()
    if autoPickupCooldown then return end
    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local gunDrop, gunPart = getGunDrop()
    if not gunPart then return end

    autoPickupCooldown = true
    local oldPos = myRoot.CFrame
    StatusLabel.Text = "⚡ Подбираю пистолет..."

    myRoot.CFrame = gunPart.CFrame * CFrame.new(0, 1, 0)
    pcall(function()
        firetouchinterest(myRoot, gunPart, 0)
        task.wait(0.05)
        firetouchinterest(myRoot, gunPart, 1)
    end)

    task.wait(0.18)

    if myRoot and myRoot.Parent then
        myRoot.CFrame = oldPos
    end
    StatusLabel.Text = "⚡ Пистолет подобран!"
    task.wait(0.5)
    autoPickupCooldown = false
end

startAutoPickupLoop = function()
    if autoPickupLoopRunning then return end
    autoPickupLoopRunning = true
    task.spawn(function()
        while autoPickupLoopRunning and Settings.AutoPickupEnabled do
            local gunDrop, gunPart = getGunDrop()
            if gunPart and not findGun(Player) then
                triggerGunPickup()
            end
            task.wait(0.6)
        end
        autoPickupLoopRunning = false
    end)
end

stopAutoPickupLoop = function()
    autoPickupLoopRunning = false
end

-- ------------------------------------------------------------
--  5. KILL AURA И KILL ALL (Активация ножа + удар по хитбоксам)
-- ------------------------------------------------------------
local function slashTarget(knife, targetChar)
    if not knife or not targetChar then return end
    local blade = knife:FindFirstChild("Handle") or knife:FindFirstChildWhichIsA("BasePart")
    if not blade then return end

    pcall(function()
        knife:Activate()
    end)

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
        StatusLabel.Text = "❌ Нет ножа в инвентаре!"
        return
    end

    equipTool(knife)

    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    local tRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not tRoot then return end

    local oldPos = myRoot.CFrame
    myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, 1.2)
    task.wait(0.04)

    slashTarget(knife, targetChar)

    task.wait(0.06)
    myRoot.CFrame = oldPos
    StatusLabel.Text = "⚔ Атакован: " .. targetChar.Name
end

startKillLoop = function()
    if killLoopRunning then return end
    killLoopRunning = true
    task.spawn(function()
        while killLoopRunning and Settings.KillEnabled do
            local knife = findKnife(Player)
            if not knife then
                StatusLabel.Text = "❌ Вы не Murderer (нет ножа)"
                task.wait(1)
            else
                local myRoot = character and character:FindFirstChild("HumanoidRootPart")
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

stopKillLoop = function()
    killLoopRunning = false
end

-- KILL ALL: Уничтожение всех невинных и шерифа за один проход с возвратом
performKillAll = function()
    if killAllActive then return end
    killAllActive = true

    local knife = findKnife(Player)
    if not knife then
        StatusLabel.Text = "❌ Нет ножа для Kill All!"
        killAllActive = false
        return
    end

    equipTool(knife)

    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
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

-- ------------------------------------------------------------
--  6. ТЕЛЕПОРТ (К целям или к пистолету)
-- ------------------------------------------------------------
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

    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return targets[1] end

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

startTeleportLoop = function()
    if teleportLoopRunning then return end
    teleportLoopRunning = true
    task.spawn(function()
        while teleportLoopRunning and Settings.TeleportEnabled do
            local myRoot = character and character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local targetRoot = findTeleportTarget()
                if targetRoot and targetRoot.Parent then
                    myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
                    StatusLabel.Text = "✦ ТП к цели (" .. Settings.TeleportTarget .. ")"
                else
                    StatusLabel.Text = "◎ Цель для ТП не найдена"
                end
            end
            task.wait(1)
        end
        teleportLoopRunning = false
    end)
end

stopTeleportLoop = function()
    teleportLoopRunning = false
end

-- ------------------------------------------------------------
--  7. NOCLIP (Корректное отключение коллизии)
-- ------------------------------------------------------------
startNoclip = function()
    if noclipRunning then return end
    noclipRunning = true
    noclipConnection = RunService.Stepped:Connect(function()
        if not Settings.NoclipEnabled then return end
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

stopNoclip = function()
    noclipRunning = false
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CanCollide = true
    end
end

-- ------------------------------------------------------------
--  8. НЕВИДИМОСТЬ (HIDE) (Скрытие скина, лица и аксессуаров)
-- ------------------------------------------------------------
startHide = function()
    if hideRunning then return end
    hideRunning = true
    if character then
        for _, inst in ipairs(character:GetDescendants()) do
            if inst:IsA("BasePart") or inst:IsA("Decal") then
                hiddenParts[inst] = inst.Transparency
                inst.Transparency = 1
            end
        end
    end
end

stopHide = function()
    hideRunning = false
    for inst, oldTrans in pairs(hiddenParts) do
        if inst and inst.Parent then
            inst.Transparency = oldTrans
        end
    end
    hiddenParts = {}
end

-- ============================================================
--  НАПОЛНЕНИЕ СТРАНИЦ ЭЛЕМЕНТАМИ УПРАВЛЕНИЯ
-- ============================================================

-- Вкладка 1: Бой (Combat)
AddToggle(CombatPage, "Флинг врагов", "Отбрасывает ближайших игроков с огромной силой", Settings.FlingEnabled, function(val)
    Settings.FlingEnabled = val
    SaveSettings()
    if val then startFlingLoop() else stopFlingLoop() end
end)

AddStepper(CombatPage, "Сила флинга", "Мощность удара и скорость вращения", Settings.Power, 100, 5000, 100, "", function(val)
    Settings.Power = val
    SaveSettings()
end)

AddStepper(CombatPage, "Радиус флинга", "Дальность поиска жертв в студах", Settings.Radius, 5, 50, 5, " ст", function(val)
    Settings.Radius = val
    SaveSettings()
end)

AddToggle(CombatPage, "Kill Aura (Автоубийство)", "Атакует врагов ножом на дистанции", Settings.KillEnabled, function(val)
    Settings.KillEnabled = val
    SaveSettings()
    if val then startKillLoop() else stopKillLoop() end
end)

AddStepper(CombatPage, "Дистанция килла", "Радиус срабатывания Kill Aura", Settings.KillDistance, 5, 50, 2, " ст", function(val)
    Settings.KillDistance = val
    SaveSettings()
end)

AddActionButton(CombatPage, "Kill All (Убить всех)", "Однократно убивает всех игроков на карте", "Казнить всех", Theme.Danger, function()
    performKillAll()
end)

-- Вкладка 2: Аим & Визуал (Visual)
AddToggle(VisualPage, "AimBot (Автонаведение)", "Автоматически наводит револьвер на цель", Settings.AimEnabled, function(val)
    Settings.AimEnabled = val
    SaveSettings()
    if val then startAimLoop() else stopAimLoop() end
end)

AddSelector(VisualPage, "Цель аимбота", "Кого захватывать в прицел в первую очередь", {"Murderer", "Sheriff", "Nearest", "All"}, Settings.AimTarget, function(val)
    Settings.AimTarget = val
    SaveSettings()
end)

AddStepper(VisualPage, "Радиус FOV", "Угол обзора для захвата цели аимом", Settings.AimFOV, 10, 90, 5, "°", function(val)
    Settings.AimFOV = val
    updateFOVCircle()
    SaveSettings()
end)

AddToggle(VisualPage, "Упреждение движения", "Расчет траектории движения пули", Settings.AimPrediction, function(val)
    Settings.AimPrediction = val
    SaveSettings()
end)

AddToggle(VisualPage, "Подсветка игроков (ESP)", "Подсвечивает роли (Красный - М, Синий - Ш)", Settings.HighlightEnabled, function(val)
    Settings.HighlightEnabled = val
    SaveSettings()
    if val then startHighlightLoop() else stopHighlightLoop() end
end)

AddToggle(VisualPage, "Таблички ESP (Имя / Дист)", "Показывает дистанцию и имя над головой", Settings.EspNamesEnabled, function(val)
    Settings.EspNamesEnabled = val
    SaveSettings()
end)

-- Вкладка 3: Движение и Разное (Misc)
AddToggle(MiscPage, "Автоподбор пистолета", "Моментально подбирает выпавший револьвер", Settings.AutoPickupEnabled, function(val)
    Settings.AutoPickupEnabled = val
    SaveSettings()
    if val then startAutoPickupLoop() else stopAutoPickupLoop() end
end)

AddActionButton(MiscPage, "Взять пистолет сейчас", "Разовый моментальный подбор выпавшего оружия", "Подобрать", Theme.AccentSecondary, function()
    triggerGunPickup()
end)

AddToggle(MiscPage, "Noclip (Сквозь стены)", "Позволяет ходить сквозь любые препятствия", Settings.NoclipEnabled, function(val)
    Settings.NoclipEnabled = val
    SaveSettings()
    if val then startNoclip() else stopNoclip() end
end)

AddToggle(MiscPage, "Невидимость (Hide)", "Делает скин, аксессуары и лицо прозрачными", Settings.HideEnabled, function(val)
    Settings.HideEnabled = val
    SaveSettings()
    if val then startHide() else stopHide() end
end)

AddToggle(MiscPage, "Авто-телепорт (Цикл)", "Постоянно следует за выбранной целью", Settings.TeleportEnabled, function(val)
    Settings.TeleportEnabled = val
    SaveSettings()
    if val then startTeleportLoop() else stopTeleportLoop() end
end)

AddSelector(MiscPage, "Цель телепорта", "Куда перемещаться при включении ТП", {"Murderer", "Sheriff", "GunDrop", "Nearest"}, Settings.TeleportTarget, function(val)
    Settings.TeleportTarget = val
    SaveSettings()
end)

-- ============================================================
--  ЛОГИКА СВОРАЧИВАНИЯ И ОТКРЫТИЯ ОКНА (TOGGLE GUI)
-- ============================================================
local menuOpen = true

ToggleMenu = function()
    menuOpen = not menuOpen
    if menuOpen then
        Main.Visible = true
        Main.Position = UDim2.new(0.5, 0, 0.5, 0)
        Main.Size = UDim2.new(0, 0, 0, 0)
        Tween(Main, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, win_w, 0, win_h),
        })
        Tween(FloatIcon, TweenInfo.new(0.2), { BackgroundColor3 = Theme.Panel })
    else
        local tw = Tween(Main, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
        })
        tw.Completed:Connect(function()
            if not menuOpen then
                Main.Visible = false
            end
        end)
        Tween(FloatIcon, TweenInfo.new(0.2), { BackgroundColor3 = Theme.Card })
    end
end

MinBtn.MouseButton1Click:Connect(ToggleMenu)
CloseBtn.MouseButton1Click:Connect(ToggleMenu)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.V then
        ToggleMenu()
    end
end)

-- ============================================================
--  ПЕРЕМЕЩЕНИЕ ОКНА (DRAG)
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
    if not dragging then return end
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
--  ОБНОВЛЕНИЕ РОЛЕЙ И СТАТУСА (ФОНОВЫЙ ТАКТ)
-- ============================================================
task.spawn(function()
    while ScreenGui.Parent do
        local myRole = getPlayerRole(Player)
        RoleBadge.Text = myRole
        if myRole == "Murderer" then
            RoleBadge.TextColor3 = Theme.Danger
            RoleBadge.BackgroundColor3 = Color3.fromRGB(45, 18, 22)
        elseif myRole == "Sheriff" then
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

        IconBadge.BackgroundColor3 = (activeCount > 0) and Theme.Success or Theme.TextDark

        task.wait(0.8)
    end
end)

-- ============================================================
--  АВТО-СТАРТ СОХРАНЕННЫХ СИСТЕМ
-- ============================================================
if Settings.FlingEnabled then startFlingLoop() end
if Settings.HighlightEnabled then startHighlightLoop() end
if Settings.AimEnabled then startAimLoop() end
if Settings.AutoPickupEnabled then startAutoPickupLoop() end
if Settings.KillEnabled then startKillLoop() end
if Settings.TeleportEnabled then startTeleportLoop() end
if Settings.NoclipEnabled then startNoclip() end
if Settings.HideEnabled then startHide() end

print("⚡ LoScript MM2 (v11 ULTRA FIXED) успешно загружен!")