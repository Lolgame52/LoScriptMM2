-- ============================================================
--  LoScript For MM2 (v10 FINAL)
--  ЧАСТЬ 1: Настройки, GUI (скролл), переменные
-- ============================================================

repeat wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local LocalPlayer = Player
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled

-- === НАСТРОЙКИ (сохраняются) ===
local Settings = {
    FlingEnabled = true,
    Power = 500,                  -- сила вращения и удара
    HighlightEnabled = true,
    Radius = 10,                  -- радиус поиска целей для флинга
    AimEnabled = false,
    AimFOV = 30,
    AimTarget = "Murderer",
    AutoPickupEnabled = false,
    KillEnabled = false,          -- Kill Aura (одиночная цель)
    KillAllEnabled = false,       -- Kill All (все цели подряд)
    KillDistance = 10,            -- дальность для Kill Aura
    TeleportEnabled = false,
    TeleportTarget = "Nearest",   -- Nearest, Murderer, Sheriff
    NoclipEnabled = false,        -- Хождение сквозь стены
    HideEnabled = false,          -- Невидимость (спрятать модель)
}

local CONFIG_FILE = "loscript_mm2_config.txt"

local function LoadSettings()
    if isfile and isfile(CONFIG_FILE) then
        local ok, data = pcall(readfile, CONFIG_FILE)
        if ok and data then
            local decoded = game:GetService("HttpService"):JSONDecode(data)
            if decoded then
                for k, v in pairs(decoded) do
                    Settings[k] = v
                end
            end
        end
    end
end
LoadSettings()

local function SaveSettings()
    if writefile then
        pcall(function()
            writefile(CONFIG_FILE, game:GetService("HttpService"):JSONEncode(Settings))
        end)
    end
end

-- === ПЕРЕМЕННЫЕ ===
local character, rootPart, head
local camera = workspace.CurrentCamera
local flingCount = 0
local flingLoopRunning = false
local highlightLoopRunning = false
local aimLoopRunning = false
local autoPickupLoopRunning = false
local killLoopRunning = false
local killAllLoopRunning = false
local teleportLoopRunning = false
local noclipRunning = false
local hideRunning = false
local highlightCache = {}

-- Для флинга-снаряда
local flingActive = false
local flingOriginalCFrame = nil

local function UpdateCharacter(newChar)
    character = newChar
    if character then
        rootPart = character:FindFirstChild("HumanoidRootPart")
        head = character:FindFirstChild("Head")
    else
        rootPart = nil
        head = nil
    end
end

UpdateCharacter(Player.Character)
Player.CharacterAdded:Connect(UpdateCharacter)

-- === СТИЛИ ===
local Theme = {
    Background = Color3.fromRGB(10, 10, 14),
    Inline = Color3.fromRGB(18, 18, 24),
    Border = Color3.fromRGB(48, 48, 60),
    Outline = Color3.fromRGB(32, 32, 40),
    Shadow = Color3.fromRGB(0, 0, 0),
    Text = Color3.fromRGB(240, 240, 250),
    Inactive = Color3.fromRGB(150, 150, 160),
    Accent = Color3.fromRGB(160, 80, 255),
    Element = Color3.fromRGB(28, 28, 36),
    Gradient = Color3.fromRGB(220, 150, 255),
}

local FontFace = Font.fromEnum(Enum.Font.GothamBold)

-- === УТИЛИТЫ ===
local function Create(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then
            pcall(function() inst[k] = v end)
        end
    end
    if props.Parent then inst.Parent = props.Parent end
    return inst
end

local function Corner(parent, radius)
    return Create("UICorner", { Parent = parent, CornerRadius = UDim.new(0, radius or 5) })
end

local function Stroke(parent, color, transparency)
    return Create("UIStroke", {
        Parent = parent,
        Color = color or Theme.Border,
        Thickness = 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function Tween(inst, info, goal)
    local tw = TweenService:Create(inst, info or TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
    tw:Play()
    return tw
end

-- === GUI ===
local ScreenGui = Create("ScreenGui", {
    Parent = game:GetService("CoreGui"),
    Name = "LoScriptMM2",
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 999,
    ResetOnSpawn = false,
})

local UIScale = Create("UIScale", { Parent = ScreenGui, Scale = IsMobile and 0.9 or 1 })

local panel_w = IsMobile and 380 or 420
local pad = IsMobile and 14 or 12
local btn_h = IsMobile and 44 or 36
local field_h = IsMobile and 40 or 34
local content_w = panel_w - pad * 2

local Main = Create("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(0, 0, 0, 0),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Theme.Background,
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 2,
})
Corner(Main, 8)
local MainStroke = Stroke(Main, Theme.Border, 1)

-- Заголовок
local header_h = 46
local DragArea = Create("Frame", {
    Parent = Main,
    Size = UDim2.new(1, -40, 0, header_h),
    BackgroundTransparency = 1,
    ZIndex = 3,
})

local CloseBtn = Create("ImageButton", {
    Parent = Main,
    Size = UDim2.new(0, 22, 0, 22),
    Position = UDim2.new(1, -pad, 0, pad),
    AnchorPoint = Vector2.new(1, 0),
    BackgroundTransparency = 1,
    Image = "rbxassetid://76001605964586",
    ImageTransparency = 0,
    ImageColor3 = Theme.Inactive,
    ScaleType = Enum.ScaleType.Fit,
    AutoButtonColor = false,
    ZIndex = 6,
})

local TitleLabel = Create("TextLabel", {
    Parent = Main,
    Size = UDim2.new(1, -pad*2, 0, header_h),
    Position = UDim2.new(0, pad, 0, 0),
    BackgroundTransparency = 1,
    Text = "⚡ LoScript For MM2",
    TextColor3 = Theme.Text,
    TextSize = IsMobile and 18 or 17,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

local AccentLine = Create("Frame", {
    Parent = Main,
    Size = UDim2.new(1, 4, 0, 1),
    Position = UDim2.new(0, -2, 0, header_h),
    BackgroundColor3 = Theme.Accent,
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    ZIndex = 3,
})

-- === СКРОЛЛ ОБЛАСТЬ ===
local ScrollArea = Create("ScrollingFrame", {
    Parent = Main,
    Size = UDim2.new(1, 0, 1, -header_h),
    Position = UDim2.new(0, 0, 0, header_h),
    BackgroundTransparency = 1,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.Accent,
    CanvasSize = UDim2.new(0, 0, 0, 1000), -- будет авто-расширение
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ZIndex = 3,
})

local Layout = Create("UIListLayout", {
    Parent = ScrollArea,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 6),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
})

-- === ФУНКЦИИ ДЛЯ ТОГГЛОВ ===
local function MakeToggle(label, default)
    local btn = Create("TextButton", {
        Parent = ScrollArea,
        Size = UDim2.new(1, -pad*2, 0, btn_h),
        BackgroundColor3 = Theme.Element,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = label .. (default and " ● ВКЛ" or " ○ ВЫКЛ"),
        TextColor3 = default and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,80,80),
        TextSize = IsMobile and 15 or 14,
        FontFace = FontFace,
        AutoButtonColor = false,
        ZIndex = 4,
    })
    Corner(btn, 6)
    Stroke(btn, Theme.Border, 0.35)
    local state = default
    local function UpdateVisual()
        btn.Text = label .. (state and " ● ВКЛ" or " ○ ВЫКЛ")
        btn.TextColor3 = state and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,80,80)
    end
    return btn, {
        Get = function() return state end,
        Set = function(value)
            state = value
            UpdateVisual()
        end
    }
end

-- Создаём все тумблеры (кнопки сами добавятся в скролл)
local toggleFling, flingState = MakeToggle("Флинг", Settings.FlingEnabled)
local toggleHighlight, highlightState = MakeToggle("Подсветка", Settings.HighlightEnabled)
local toggleAim, aimState = MakeToggle("AimBot", Settings.AimEnabled)
local toggleAutoPickup, autoPickupState = MakeToggle("Автоподбор", Settings.AutoPickupEnabled)
local toggleKill, killState = MakeToggle("Автоубийство (Aura)", Settings.KillEnabled)
local toggleKillAll, killAllState = MakeToggle("Kill All", Settings.KillAllEnabled)
local toggleTeleport, teleportState = MakeToggle("Телепорт", Settings.TeleportEnabled)
local toggleNoclip, noclipState = MakeToggle("Noclip", Settings.NoclipEnabled)
local toggleHide, hideState = MakeToggle("Невидимость", Settings.HideEnabled)

-- === ДОБАВЛЯЕМ ПОЛЕ СИЛЫ ===
local PowerLabel = Create("TextLabel", {
    Parent = ScrollArea,
    Size = UDim2.new(1, -pad*2, 0, field_h),
    BackgroundTransparency = 1,
    Text = "Сила: " .. Settings.Power,
    TextColor3 = Theme.Text,
    TextSize = IsMobile and 15 or 14,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

local decBtn = Create("TextButton", {
    Parent = ScrollArea,
    Size = UDim2.new(0.1, 0, 0, field_h),
    BackgroundColor3 = Theme.Element,
    Text = "−",
    TextColor3 = Theme.Text,
    TextSize = 22,
    FontFace = FontFace,
    AutoButtonColor = false,
    ZIndex = 4,
})
Corner(decBtn, 5)

local valueDisp = Create("TextLabel", {
    Parent = ScrollArea,
    Size = UDim2.new(0.12, 0, 0, field_h),
    BackgroundTransparency = 1,
    Text = tostring(Settings.Power),
    TextColor3 = Theme.Accent,
    TextSize = 18,
    FontFace = FontFace,
    ZIndex = 4,
})

local incBtn = Create("TextButton", {
    Parent = ScrollArea,
    Size = UDim2.new(0.1, 0, 0, field_h),
    BackgroundColor3 = Theme.Element,
    Text = "+",
    TextColor3 = Theme.Text,
    TextSize = 22,
    FontFace = FontFace,
    AutoButtonColor = false,
    ZIndex = 4,
})
Corner(incBtn, 5)

-- === ПАРАМЕТРЫ AIMBOT ===
local AimLabel = Create("TextLabel", {
    Parent = ScrollArea,
    Size = UDim2.new(1, -pad*2, 0, field_h),
    BackgroundTransparency = 1,
    Text = "Цель: " .. Settings.AimTarget,
    TextColor3 = Theme.Inactive,
    TextSize = IsMobile and 14 or 13,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

local aimTargetBtn = Create("TextButton", {
    Parent = ScrollArea,
    Size = UDim2.new(0.35, 0, 0, field_h),
    BackgroundColor3 = Theme.Element,
    Text = "Сменить цель",
    TextColor3 = Theme.Text,
    TextSize = IsMobile and 14 or 13,
    FontFace = FontFace,
    AutoButtonColor = false,
    ZIndex = 4,
})
Corner(aimTargetBtn, 5)

local FovLabel = Create("TextLabel", {
    Parent = ScrollArea,
    Size = UDim2.new(1, -pad*2, 0, field_h),
    BackgroundTransparency = 1,
    Text = "FOV: " .. Settings.AimFOV .. "°",
    TextColor3 = Theme.Text,
    TextSize = IsMobile and 15 or 14,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

local fovDec = Create("TextButton", {
    Parent = ScrollArea,
    Size = UDim2.new(0.1, 0, 0, field_h),
    BackgroundColor3 = Theme.Element,
    Text = "−",
    TextColor3 = Theme.Text,
    TextSize = 22,
    FontFace = FontFace,
    AutoButtonColor = false,
    ZIndex = 4,
})
Corner(fovDec, 5)

local fovDisp = Create("TextLabel", {
    Parent = ScrollArea,
    Size = UDim2.new(0.12, 0, 0, field_h),
    BackgroundTransparency = 1,
    Text = tostring(Settings.AimFOV),
    TextColor3 = Theme.Accent,
    TextSize = 18,
    FontFace = FontFace,
    ZIndex = 4,
})

local fovInc = Create("TextButton", {
    Parent = ScrollArea,
    Size = UDim2.new(0.1, 0, 0, field_h),
    BackgroundColor3 = Theme.Element,
    Text = "+",
    TextColor3 = Theme.Text,
    TextSize = 22,
    FontFace = FontFace,
    AutoButtonColor = false,
    ZIndex = 4,
})
Corner(fovInc, 5)

-- === ДИСТАНЦИЯ УБИЙСТВА ===
local KillDistLabel = Create("TextLabel", {
    Parent = ScrollArea,
    Size = UDim2.new(1, -pad*2, 0, field_h),
    BackgroundTransparency = 1,
    Text = "Дист. убийства: " .. Settings.KillDistance,
    TextColor3 = Theme.Text,
    TextSize = IsMobile and 15 or 14,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

local killDistDec = Create("TextButton", {
    Parent = ScrollArea,
    Size = UDim2.new(0.1, 0, 0, field_h),
    BackgroundColor3 = Theme.Element,
    Text = "−",
    TextColor3 = Theme.Text,
    TextSize = 22,
    FontFace = FontFace,
    AutoButtonColor = false,
    ZIndex = 4,
})
Corner(killDistDec, 5)

local killDistDisp = Create("TextLabel", {
    Parent = ScrollArea,
    Size = UDim2.new(0.12, 0, 0, field_h),
    BackgroundTransparency = 1,
    Text = tostring(Settings.KillDistance),
    TextColor3 = Theme.Accent,
    TextSize = 18,
    FontFace = FontFace,
    ZIndex = 4,
})

local killDistInc = Create("TextButton", {
    Parent = ScrollArea,
    Size = UDim2.new(0.1, 0, 0, field_h),
    BackgroundColor3 = Theme.Element,
    Text = "+",
    TextColor3 = Theme.Text,
    TextSize = 22,
    FontFace = FontFace,
    AutoButtonColor = false,
    ZIndex = 4,
})
Corner(killDistInc, 5)

-- === ТЕЛЕПОРТ ЦЕЛЬ ===
local TPTargetLabel = Create("TextLabel", {
    Parent = ScrollArea,
    Size = UDim2.new(1, -pad*2, 0, field_h),
    BackgroundTransparency = 1,
    Text = "ТП цель: " .. Settings.TeleportTarget,
    TextColor3 = Theme.Inactive,
    TextSize = IsMobile and 14 or 13,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

local tpTargetBtn = Create("TextButton", {
    Parent = ScrollArea,
    Size = UDim2.new(0.35, 0, 0, field_h),
    BackgroundColor3 = Theme.Element,
    Text = "Сменить",
    TextColor3 = Theme.Text,
    TextSize = IsMobile and 14 or 13,
    FontFace = FontFace,
    AutoButtonColor = false,
    ZIndex = 4,
})
Corner(tpTargetBtn, 5)

-- === СТАТУС ===
local StatusLabel = Create("TextLabel", {
    Parent = ScrollArea,
    Size = UDim2.new(1, -pad*2, 0, 20),
    BackgroundTransparency = 1,
    Text = "🟢 Активен | Флингов: 0",
    TextColor3 = Theme.Inactive,
    TextSize = IsMobile and 13 or 12,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

local panel_h = 600 -- высота окна (с учётом скролла)

-- Применяем размер окна
Main.Size = UDim2.new(0, panel_w, 0, panel_h)

-- ============================================================
--  ЛОГИКА ФЛИНГА (снаряд с коллизией и вращением)
-- ============================================================
local function flingTarget(targetChar)
    if not targetChar or flingActive then return false end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    local myRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not myRoot then return false end

    flingActive = true
    flingOriginalCFrame = myRoot.CFrame

    -- Обязательно ВКЛЮЧАЕМ коллизию, чтобы врезаться
    for _, part in ipairs(Player.Character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end

    -- Создаем бешеное вращение
    local spin = Instance.new("BodyAngularVelocity")
    spin.AngularVelocity = Vector3.new(0, 50000, 0)
    spin.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    spin.Parent = myRoot

    -- Телепортируемся прямо во врага на 0.3 секунды
    local startTime = tick()
    while tick() - startTime < 0.3 do
        if not targetRoot or not targetRoot.Parent then break end
        myRoot.CFrame = targetRoot.CFrame
        RunService.Heartbeat:Wait()
    end

    -- Убираем вращение и возвращаемся
    spin:Destroy()
    myRoot.Velocity = Vector3.zero
    myRoot.RotVelocity = Vector3.zero
    myRoot.CFrame = flingOriginalCFrame

    flingActive = false
    flingCount = flingCount + 1
    StatusLabel.Text = "🟢 Активен | Флингов: " .. flingCount
    return true
end

local function startFlingLoop()
    if flingLoopRunning then return end
    flingLoopRunning = true
    spawn(function()
        while flingLoopRunning do
            if not flingState.Get() then break end
            local myRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if myRoot and not flingActive then
                local closest = nil
                local minDist = Settings.Radius
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= Player then
                        local char = other.Character
                        if char then
                            local r = char:FindFirstChild("HumanoidRootPart")
                            if r then
                                local d = (r.Position - myRoot.Position).magnitude
                                if d <= minDist then
                                    minDist = d
                                    closest = char
                                end
                            end
                        end
                    end
                end
                if closest then
                    flingTarget(closest)
                    wait(1.0) -- задержка между флингами
                end
            end
            wait(0.2)
        end
        flingLoopRunning = false
    end)
end

local function stopFlingLoop()
    flingLoopRunning = false
end

-- ============================================================
--  NOCLIP (постоянное отключение коллизии)
-- ============================================================
local noclipConnection = nil

local function startNoclip()
    if noclipRunning then return end
    noclipRunning = true
    noclipConnection = RunService.Stepped:Connect(function()
        if Player.Character then
            for _, part in ipairs(Player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
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
    -- Восстанавливаем коллизию
    if Player.Character then
        for _, part in ipairs(Player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- ============================================================
--  НЕВИДИМОСТЬ (Hide) — прозрачность + отключение коллизии
-- ============================================================
local hiddenParts = {}

local function startHide()
    if hideRunning then return end
    hideRunning = true
    if Player.Character then
        for _, part in ipairs(Player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                hiddenParts[part] = part.Transparency
                part.Transparency = 1
                part.CanCollide = false
            end
        end
    end
end

local function stopHide()
    hideRunning = false
    for part, oldTransparency in pairs(hiddenParts) do
        if part and part.Parent then
            part.Transparency = oldTransparency
            part.CanCollide = true
        end
    end
    hiddenParts = {}
end

-- ============================================================
--  АВТОПОДБОР ПИСТОЛЕТА (GunDrop)
-- ============================================================
local function startAutoPickupLoop()
    if autoPickupLoopRunning then return end
    autoPickupLoopRunning = true
    spawn(function()
        while autoPickupLoopRunning do
            if not autoPickupState.Get() then break end
            local myRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local gunDrop = workspace:FindFirstChild("GunDrop", true)
                if gunDrop then
                    myRoot.CFrame = gunDrop.CFrame
                    StatusLabel.Text = "🔫 Подбираю пистолет..."
                    wait(0.3)
                end
            end
            wait(0.5)
        end
        autoPickupLoopRunning = false
    end)
end

local function stopAutoPickupLoop()
    autoPickupLoopRunning = false
end

-- ============================================================
--  ПОДСВЕТКА РОЛЕЙ (оптимизировано)
-- ============================================================
local function getPlayerRole(plr)
    local function checkTools(parent)
        if not parent then return nil end
        for _, tool in ipairs(parent:GetChildren()) do
            if tool:IsA("Tool") then
                local name = tool.Name:lower()
                if name:find("knife") or name:find("dagger") then
                    return "Murderer"
                elseif name:find("gun") or name:find("revolver") or name:find("sheriff") or name:find("pistol") then
                    return "Sheriff"
                end
            end
        end
        return nil
    end

    local role = checkTools(plr:FindFirstChild("Backpack"))
    if role then return role end
    role = checkTools(plr.Character)
    if role then return role end
    return "Innocent"
end

local function roleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255,0,0)
    elseif role == "Sheriff" then return Color3.fromRGB(0,100,255)
    else return Color3.fromRGB(0,255,0) end
end

local function startHighlightLoop()
    if highlightLoopRunning then return end
    highlightLoopRunning = true
    spawn(function()
        while highlightLoopRunning do
            if not highlightState.Get() then break end

            -- Очистка подсветки ушедших игроков
            for plr, hl in pairs(highlightCache) do
                if not plr.Parent or (plr.Character and not plr.Character:FindFirstChild("HumanoidRootPart")) then
                    if hl and hl.Parent then hl:Destroy() end
                    highlightCache[plr] = nil
                end
            end

            -- Обновление подсветки
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
                        hl.OutlineTransparency = 0.2
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent = char
                        highlightCache[plr] = hl
                    else
                        hl.FillColor = color
                        hl.OutlineColor = color
                    end
                end
            end

            wait(0.5)
        end

        for plr, hl in pairs(highlightCache) do
            if hl and hl.Parent then hl:Destroy() end
        end
        highlightCache = {}
        highlightLoopRunning = false
    end)
end

local function stopHighlightLoop()
    highlightLoopRunning = false
end

-- ============================================================
--  AIMBOT (мгновенный, без предсказания)
-- ============================================================
local function hasGun()
    local char = Player.Character
    if not char then return false end
    local tool = char:FindFirstChildWhichIsA("Tool")
    if tool then
        local name = tool.Name:lower()
        if name:find("gun") or name:find("revolver") or name:find("sheriff") or name:find("pistol") then
            return true
        end
    end
    return false
end

local function getAimTargets()
    local targets = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player and plr.Character and plr.Character:FindFirstChild("Head") then
            local role = getPlayerRole(plr)
            if Settings.AimTarget == "Murderer" and role == "Murderer" then table.insert(targets, plr)
            elseif Settings.AimTarget == "Sheriff" and role == "Sheriff" then table.insert(targets, plr)
            elseif Settings.AimTarget == "All" or Settings.AimTarget == "Nearest" then table.insert(targets, plr) end
        end
    end
    return targets
end

local function getAngleToTarget(targetPos)
    local cameraPos = camera.CFrame.Position
    local lookVec = camera.CFrame.LookVector
    local toTarget = (targetPos - cameraPos).unit
    return math.deg(math.acos(math.clamp(lookVec:Dot(toTarget), -1, 1)))
end

local function getClosestTargetInFOV()
    local targets = getAimTargets()
    if #targets == 0 then return nil end

    local best = nil
    local bestAngle = Settings.AimFOV
    local bestDist = math.huge

    for _, plr in ipairs(targets) do
        local head = plr.Character.Head
        local pos = head.Position
        local angle = getAngleToTarget(pos)
        if angle <= Settings.AimFOV then
            local dist = (pos - camera.CFrame.Position).magnitude
            if Settings.AimTarget == "Nearest" then
                if dist < bestDist then bestDist = dist; best = plr end
            else
                if angle < bestAngle then bestAngle = angle; best = plr end
            end
        end
    end
    return best
end

local function aimAtTarget(plr)
    if not plr or not plr.Character or not plr.Character:FindFirstChild("Head") then return end
    local targetPos = plr.Character.Head.Position
    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPos)
end

local aimRenderConnection = nil
local function startAimLoop()
    if aimLoopRunning then return end
    aimLoopRunning = true
    aimRenderConnection = RunService.RenderStepped:Connect(function()
        if not aimState.Get() then return end
        if not hasGun() then
            StatusLabel.Text = "🔫 Возьми пистолет для AimBot"
            return
        end
        local target = getClosestTargetInFOV()
        if target then
            aimAtTarget(target)
            StatusLabel.Text = "🎯 Наведение на " .. target.Name
        else
            StatusLabel.Text = "🔍 Нет цели в FOV"
        end
    end)
end

local function stopAimLoop()
    aimLoopRunning = false
    if aimRenderConnection then
        aimRenderConnection:Disconnect()
        aimRenderConnection = nil
    end
end

-- ============================================================
--  ТЕЛЕПОРТ (за спину)
-- ============================================================
local function findTeleportTarget()
    local targets = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local role = getPlayerRole(plr)
            if Settings.TeleportTarget == "Nearest" then
                table.insert(targets, plr)
            elseif Settings.TeleportTarget == "Murderer" and role == "Murderer" then
                table.insert(targets, plr)
            elseif Settings.TeleportTarget == "Sheriff" and role == "Sheriff" then
                table.insert(targets, plr)
            end
        end
    end
    if #targets == 0 then return nil end

    local myRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local closest = nil
    local minDist = math.huge
    for _, plr in ipairs(targets) do
        local r = plr.Character:FindFirstChild("HumanoidRootPart")
        if r then
            local d = (r.Position - myRoot.Position).magnitude
            if d < minDist then minDist = d; closest = plr end
        end
    end
    return closest
end

local function startTeleportLoop()
    if teleportLoopRunning then return end
    teleportLoopRunning = true
    spawn(function()
        while teleportLoopRunning do
            if not teleportState.Get() then break end
            local myRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local target = findTeleportTarget()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local targetRoot = target.Character.HumanoidRootPart
                    myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
                    StatusLabel.Text = "🌀 Телепорт к " .. target.Name
                else
                    StatusLabel.Text = "🎯 Нет цели для телепорта"
                end
            end
            wait(1.0)
        end
        teleportLoopRunning = false
    end)
end

local function stopTeleportLoop()
    teleportLoopRunning = false
end

-- ============================================================
--  KILL AURA (одиночная цель с твином)
-- ============================================================
local function findKnife()
    local backpack = Player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find("knife") then
                return tool
            end
        end
    end
    if Player.Character then
        for _, tool in ipairs(Player.Character:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find("knife") then
                return tool
            end
        end
    end
    return nil
end

local function killTarget(targetChar)
    if not targetChar then return end
    local knife = findKnife()
    if not knife then
        StatusLabel.Text = "❌ Нет ножа в инвентаре!"
        return
    end

    -- Экипируем нож, если он в рюкзаке
    if knife.Parent == Player:FindFirstChild("Backpack") then
        local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:EquipTool(knife)
            wait(0.1)
        end
    end

    -- Получаем лезвие ножа
    local blade = knife:FindFirstChild("Handle") or knife:FindFirstChildWhichIsA("BasePart")
    if not blade then return end

    -- Плавно перемещаемся за спину жертвы
    local myRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetRoot then return end

    local originalCFrame = myRoot.CFrame
    local targetCFrame = targetRoot.CFrame * CFrame.new(0, 0, 1.5)

    -- Временно отключаем Noclip, чтобы коллизия работала для удара
    if noclipRunning then stopNoclip() end

    local tw = TweenService:Create(myRoot, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    tw:Play()
    tw.Completed:Wait()

    -- Спамим касаниями
    for i = 1, 3 do
        firetouchinterest(blade, targetRoot, 0)
        firetouchinterest(blade, targetRoot, 1)
        wait(0.05)
    end

    -- Возвращаемся на исходную позицию
    myRoot.CFrame = originalCFrame

    -- Восстанавливаем Noclip, если был включен
    if noclipState.Get() then startNoclip() end

    StatusLabel.Text = "🔪 Удар по " .. targetChar.Name
end

local function startKillLoop()
    if killLoopRunning then return end
    killLoopRunning = true
    spawn(function()
        while killLoopRunning do
            if not killState.Get() then break end
            if getPlayerRole(Player) ~= "Murderer" then
                StatusLabel.Text = "❌ Вы не murderer"
                wait(0.5)
            else
                local myRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    local closest = nil
                    local minDist = Settings.KillDistance
                    for _, other in ipairs(Players:GetPlayers()) do
                        if other ~= Player then
                            local char = other.Character
                            if char and getPlayerRole(other) ~= "Murderer" then
                                local r = char:FindFirstChild("HumanoidRootPart")
                                if r then
                                    local d = (r.Position - myRoot.Position).magnitude
                                    if d <= minDist then
                                        minDist = d
                                        closest = char
                                    end
                                end
                            end
                        end
                    end
                    if closest then
                        killTarget(closest)
                    end
                end
            end
            wait(0.2)
        end
        killLoopRunning = false
    end)
end

local function stopKillLoop()
    killLoopRunning = false
end

-- ============================================================
--  KILL ALL (однократное убийство всех целей)
-- ============================================================
local killAllActive = false

local function performKillAll()
    if killAllActive then return end
    killAllActive = true

    local knife = findKnife()
    if not knife then
        StatusLabel.Text = "❌ Нет ножа!"
        killAllActive = false
        return
    end

    -- Экипируем нож
    if knife.Parent == Player:FindFirstChild("Backpack") then
        local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid:EquipTool(knife) wait(0.1) end
    end

    local blade = knife:FindFirstChild("Handle") or knife:FindFirstChildWhichIsA("BasePart")
    if not blade then killAllActive = false return end

    local myRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then killAllActive = false return end

    -- Временно отключаем Noclip
    if noclipRunning then stopNoclip() end

    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= Player and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            if getPlayerRole(target) ~= "Murderer" then
                local targetRoot = target.Character.HumanoidRootPart
                -- Телепорт за спину
                myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 2)
                wait(0.2) -- Даем серверу обновить позицию
                -- Спамим удары
                for i = 1, 3 do
                    firetouchinterest(blade, targetRoot, 0)
                    firetouchinterest(blade, targetRoot, 1)
                end
                wait(0.3) -- Задержка перед следующей целью
            end
        end
    end

    -- Восстанавливаем Noclip, если был включен
    if noclipState.Get() then startNoclip() end

    killAllActive = false
    StatusLabel.Text = "☠️ Kill All завершён"
end

-- ============================================================
--  ОБРАБОТЧИКИ КНОПОК (Сила, цель аимбота, FOV, дистанция килла, ТП цель)
-- ============================================================

decBtn.MouseButton1Click:Connect(function()
    Settings.Power = math.max(100, Settings.Power - 50)
    PowerLabel.Text = "Сила: " .. Settings.Power
    valueDisp.Text = tostring(Settings.Power)
    SaveSettings()
end)

incBtn.MouseButton1Click:Connect(function()
    Settings.Power = math.min(5000, Settings.Power + 50)
    PowerLabel.Text = "Сила: " .. Settings.Power
    valueDisp.Text = tostring(Settings.Power)
    SaveSettings()
end)

local targetList = {"Murderer", "Sheriff", "All", "Nearest"}
aimTargetBtn.MouseButton1Click:Connect(function()
    local idx = 1
    for i, v in ipairs(targetList) do
        if v == Settings.AimTarget then
            idx = i
            break
        end
    end
    idx = idx % #targetList + 1
    Settings.AimTarget = targetList[idx]
    AimLabel.Text = "Цель: " .. Settings.AimTarget
    SaveSettings()
end)

fovDec.MouseButton1Click:Connect(function()
    Settings.AimFOV = math.max(5, Settings.AimFOV - 5)
    FovLabel.Text = "FOV: " .. Settings.AimFOV .. "°"
    fovDisp.Text = tostring(Settings.AimFOV)
    SaveSettings()
end)

fovInc.MouseButton1Click:Connect(function()
    Settings.AimFOV = math.min(90, Settings.AimFOV + 5)
    FovLabel.Text = "FOV: " .. Settings.AimFOV .. "°"
    fovDisp.Text = tostring(Settings.AimFOV)
    SaveSettings()
end)

killDistDec.MouseButton1Click:Connect(function()
    Settings.KillDistance = math.max(1, Settings.KillDistance - 1)
    KillDistLabel.Text = "Дист. убийства: " .. Settings.KillDistance
    killDistDisp.Text = tostring(Settings.KillDistance)
    SaveSettings()
end)

killDistInc.MouseButton1Click:Connect(function()
    Settings.KillDistance = math.min(100, Settings.KillDistance + 1)
    KillDistLabel.Text = "Дист. убийства: " .. Settings.KillDistance
    killDistDisp.Text = tostring(Settings.KillDistance)
    SaveSettings()
end)

local tpTargets = {"Nearest", "Murderer", "Sheriff"}
tpTargetBtn.MouseButton1Click:Connect(function()
    local idx = 1
    for i, v in ipairs(tpTargets) do
        if v == Settings.TeleportTarget then
            idx = i
            break
        end
    end
    idx = idx % #tpTargets + 1
    Settings.TeleportTarget = tpTargets[idx]
    TPTargetLabel.Text = "ТП цель: " .. Settings.TeleportTarget
    SaveSettings()
end)

-- ============================================================
--  ТОГГЛЫ (включение/выключение функций)
-- ============================================================

-- Флинг
toggleFling.MouseButton1Click:Connect(function()
    flingState.Set(not flingState.Get())
    Settings.FlingEnabled = flingState.Get()
    SaveSettings()
    if Settings.FlingEnabled then
        startFlingLoop()
    else
        stopFlingLoop()
    end
end)

-- Подсветка
toggleHighlight.MouseButton1Click:Connect(function()
    highlightState.Set(not highlightState.Get())
    Settings.HighlightEnabled = highlightState.Get()
    SaveSettings()
    if Settings.HighlightEnabled then
        startHighlightLoop()
    else
        stopHighlightLoop()
    end
end)

-- AimBot
toggleAim.MouseButton1Click:Connect(function()
    aimState.Set(not aimState.Get())
    Settings.AimEnabled = aimState.Get()
    SaveSettings()
    if Settings.AimEnabled then
        startAimLoop()
    else
        stopAimLoop()
    end
end)

-- Автоподбор
toggleAutoPickup.MouseButton1Click:Connect(function()
    autoPickupState.Set(not autoPickupState.Get())
    Settings.AutoPickupEnabled = autoPickupState.Get()
    SaveSettings()
    if Settings.AutoPickupEnabled then
        startAutoPickupLoop()
    else
        stopAutoPickupLoop()
    end
end)

-- Автоубийство (Aura)
toggleKill.MouseButton1Click:Connect(function()
    killState.Set(not killState.Get())
    Settings.KillEnabled = killState.Get()
    SaveSettings()
    if Settings.KillEnabled then
        startKillLoop()
    else
        stopKillLoop()
    end
end)

-- Kill All (однократное убийство всех)
toggleKillAll.MouseButton1Click:Connect(function()
    -- Переключаем визуал (но состояние не используется для цикла)
    killAllState.Set(not killAllState.Get())
    Settings.KillAllEnabled = killAllState.Get()
    SaveSettings()
    if Settings.KillAllEnabled then
        -- Запускаем однократное убийство всех
        performKillAll()
        -- После выполнения возвращаем тумблер в выкл.
        killAllState.Set(false)
        Settings.KillAllEnabled = false
        SaveSettings()
    end
end)

-- Телепорт
toggleTeleport.MouseButton1Click:Connect(function()
    teleportState.Set(not teleportState.Get())
    Settings.TeleportEnabled = teleportState.Get()
    SaveSettings()
    if Settings.TeleportEnabled then
        startTeleportLoop()
    else
        stopTeleportLoop()
    end
end)

-- Noclip
toggleNoclip.MouseButton1Click:Connect(function()
    noclipState.Set(not noclipState.Get())
    Settings.NoclipEnabled = noclipState.Get()
    SaveSettings()
    if Settings.NoclipEnabled then
        startNoclip()
    else
        stopNoclip()
    end
end)

-- Невидимость (Hide)
toggleHide.MouseButton1Click:Connect(function()
    hideState.Set(not hideState.Get())
    Settings.HideEnabled = hideState.Get()
    SaveSettings()
    if Settings.HideEnabled then
        startHide()
    else
        stopHide()
    end
end)

-- ============================================================
--  ЗАКРЫТИЕ
-- ============================================================
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    stopFlingLoop()
    stopHighlightLoop()
    stopAimLoop()
    stopAutoPickupLoop()
    stopKillLoop()
    stopTeleportLoop()
    stopNoclip()
    stopHide()
end)

-- ============================================================
--  ПЕРЕТАСКИВАНИЕ ОКНА
-- ============================================================
local dragging = false
local dragStart = nil
local startPos = nil

DragArea.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    dragging = true
    dragStart = input.Position
    startPos = Main.Position
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    local delta = (input.Position - dragStart) / UIScale.Scale
    Main.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ============================================================
--  АНИМАЦИЯ ПОЯВЛЕНИЯ
-- ============================================================
Tween(Main, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, panel_w, 0, panel_h)
})
MainStroke.Transparency = 1
wait(0.05)
Tween(MainStroke, TweenInfo.new(0.25), { Transparency = 0.2 })

-- ============================================================
--  ЗАПУСК ВСЕХ СИСТЕМ ПРИ СТАРТЕ
-- ============================================================
if Settings.FlingEnabled then
    flingState.Set(true)
    startFlingLoop()
end
if Settings.HighlightEnabled then
    highlightState.Set(true)
    startHighlightLoop()
end
if Settings.AimEnabled then
    aimState.Set(true)
    startAimLoop()
end
if Settings.AutoPickupEnabled then
    autoPickupState.Set(true)
    startAutoPickupLoop()
end
if Settings.KillEnabled then
    killState.Set(true)
    startKillLoop()
end
if Settings.TeleportEnabled then
    teleportState.Set(true)
    startTeleportLoop()
end
if Settings.NoclipEnabled then
    noclipState.Set(true)
    startNoclip()
end
if Settings.HideEnabled then
    hideState.Set(true)
    startHide()
end

print("✅ LoScript For MM2 v10 FINAL загружен. Все системы активны!")