-- ============================================================
--  XENO ULTIMATE (Fling + Highlight + AimBot + AutoPickup + Kill) v5
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
    Power = 350,
    Mode = "Hybrid",
    MinDistance = 5,
    HighlightEnabled = true,
    Radius = 6,
    AimEnabled = false,
    AimFOV = 30,
    AimTarget = "Murderer",
    AutoPickupEnabled = false,
    KillEnabled = false,       -- Автоубийство для murderer
    KillDistance = 10,         -- Дистанция убийства
}

local CONFIG_FILE = "xeno_fling_aim_config.txt"

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
local highlightCache = {}

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
    Background = Color3.fromRGB(14, 13, 18),
    Inline = Color3.fromRGB(22, 21, 28),
    Border = Color3.fromRGB(42, 40, 52),
    Outline = Color3.fromRGB(36, 38, 45),
    Shadow = Color3.fromRGB(8, 6, 12),
    Text = Color3.fromRGB(242, 240, 248),
    Inactive = Color3.fromRGB(148, 144, 162),
    Accent = Color3.fromRGB(215, 40, 114),
    Element = Color3.fromRGB(32, 30, 40),
    Gradient = Color3.fromRGB(255, 140, 185),
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
    Name = "XenoUltimate",
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 999,
    ResetOnSpawn = false,
})

local UIScale = Create("UIScale", { Parent = ScreenGui, Scale = IsMobile and 0.9 or 1 })

local panel_w = IsMobile and 360 or 400
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
Corner(Main, 5)
local MainStroke = Stroke(Main, Theme.Border, 1)

-- Заголовок
local header_h = 44
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
    Text = "⚡ XENO ULTIMATE",
    TextColor3 = Theme.Text,
    TextSize = IsMobile and 18 or 16,
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

-- === ФУНКЦИИ ДЛЯ ТОГГЛОВ (исправлены) ===
local function MakeToggle(label, y, default)
    local btn = Create("TextButton", {
        Parent = Main,
        Size = UDim2.new(0, content_w, 0, btn_h),
        Position = UDim2.new(0, pad, 0, y),
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
    Corner(btn, 5)
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

local toggleFling, flingState = MakeToggle("Флинг", header_h + 8, Settings.FlingEnabled)
local toggleHighlight, highlightState = MakeToggle("Подсветка", header_h + 8 + btn_h + 6, Settings.HighlightEnabled)
local toggleAim, aimState = MakeToggle("AimBot", header_h + 8 + (btn_h + 6)*2 + 4, Settings.AimEnabled)
local toggleAutoPickup, autoPickupState = MakeToggle("Автоподбор", header_h + 8 + (btn_h + 6)*3 + 4, Settings.AutoPickupEnabled)
local toggleKill, killState = MakeToggle("Автоубийство", header_h + 8 + (btn_h + 6)*4 + 4, Settings.KillEnabled)

-- === УПРАВЛЕНИЕ СИЛОЙ ===
local powerY = header_h + 8 + (btn_h + 6) * 5 + 8
local PowerLabel = Create("TextLabel", {
    Parent = Main,
    Size = UDim2.new(0.5, 0, 0, field_h),
    Position = UDim2.new(0, pad, 0, powerY),
    BackgroundTransparency = 1,
    Text = "Сила: " .. Settings.Power,
    TextColor3 = Theme.Text,
    TextSize = IsMobile and 15 or 14,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

local decBtn = Create("TextButton", {
    Parent = Main,
    Size = UDim2.new(0.08, 0, 0, field_h),
    Position = UDim2.new(0.62, 0, 0, powerY),
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
    Parent = Main,
    Size = UDim2.new(0.12, 0, 0, field_h),
    Position = UDim2.new(0.72, 0, 0, powerY),
    BackgroundTransparency = 1,
    Text = tostring(Settings.Power),
    TextColor3 = Theme.Accent,
    TextSize = 18,
    FontFace = FontFace,
    ZIndex = 4,
})

local incBtn = Create("TextButton", {
    Parent = Main,
    Size = UDim2.new(0.08, 0, 0, field_h),
    Position = UDim2.new(0.86, 0, 0, powerY),
    BackgroundColor3 = Theme.Element,
    Text = "+",
    TextColor3 = Theme.Text,
    TextSize = 22,
    FontFace = FontFace,
    AutoButtonColor = false,
    ZIndex = 4,
})
Corner(incBtn, 5)

-- === РЕЖИМ ФЛИНГА ===
local modeY = powerY + field_h + 4
local ModeLabel = Create("TextLabel", {
    Parent = Main,
    Size = UDim2.new(0.5, 0, 0, field_h),
    Position = UDim2.new(0, pad, 0, modeY),
    BackgroundTransparency = 1,
    Text = "Режим: " .. Settings.Mode,
    TextColor3 = Theme.Inactive,
    TextSize = IsMobile and 14 or 13,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

local modeBtn = Create("TextButton", {
    Parent = Main,
    Size = UDim2.new(0.3, 0, 0, field_h),
    Position = UDim2.new(0.62, 0, 0, modeY),
    BackgroundColor3 = Theme.Element,
    Text = "Сменить",
    TextColor3 = Theme.Text,
    TextSize = IsMobile and 14 or 13,
    FontFace = FontFace,
    AutoButtonColor = false,
    ZIndex = 4,
})
Corner(modeBtn, 5)

-- === НАСТРОЙКИ AIMBOT ===
local aimY = modeY + field_h + 4
local AimLabel = Create("TextLabel", {
    Parent = Main,
    Size = UDim2.new(0.5, 0, 0, field_h),
    Position = UDim2.new(0, pad, 0, aimY),
    BackgroundTransparency = 1,
    Text = "Цель: " .. Settings.AimTarget,
    TextColor3 = Theme.Inactive,
    TextSize = IsMobile and 14 or 13,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

local aimTargetBtn = Create("TextButton", {
    Parent = Main,
    Size = UDim2.new(0.3, 0, 0, field_h),
    Position = UDim2.new(0.62, 0, 0, aimY),
    BackgroundColor3 = Theme.Element,
    Text = "Сменить цель",
    TextColor3 = Theme.Text,
    TextSize = IsMobile and 14 or 13,
    FontFace = FontFace,
    AutoButtonColor = false,
    ZIndex = 4,
})
Corner(aimTargetBtn, 5)

-- FOV
local fovY = aimY + field_h + 4
local FovLabel = Create("TextLabel", {
    Parent = Main,
    Size = UDim2.new(0.5, 0, 0, field_h),
    Position = UDim2.new(0, pad, 0, fovY),
    BackgroundTransparency = 1,
    Text = "FOV: " .. Settings.AimFOV .. "°",
    TextColor3 = Theme.Text,
    TextSize = IsMobile and 15 or 14,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

local fovDec = Create("TextButton", {
    Parent = Main,
    Size = UDim2.new(0.08, 0, 0, field_h),
    Position = UDim2.new(0.62, 0, 0, fovY),
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
    Parent = Main,
    Size = UDim2.new(0.12, 0, 0, field_h),
    Position = UDim2.new(0.72, 0, 0, fovY),
    BackgroundTransparency = 1,
    Text = tostring(Settings.AimFOV),
    TextColor3 = Theme.Accent,
    TextSize = 18,
    FontFace = FontFace,
    ZIndex = 4,
})

local fovInc = Create("TextButton", {
    Parent = Main,
    Size = UDim2.new(0.08, 0, 0, field_h),
    Position = UDim2.new(0.86, 0, 0, fovY),
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
local killDistY = fovY + field_h + 4
local KillDistLabel = Create("TextLabel", {
    Parent = Main,
    Size = UDim2.new(0.5, 0, 0, field_h),
    Position = UDim2.new(0, pad, 0, killDistY),
    BackgroundTransparency = 1,
    Text = "Дист. убийства: " .. Settings.KillDistance,
    TextColor3 = Theme.Text,
    TextSize = IsMobile and 15 or 14,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

local killDistDec = Create("TextButton", {
    Parent = Main,
    Size = UDim2.new(0.08, 0, 0, field_h),
    Position = UDim2.new(0.62, 0, 0, killDistY),
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
    Parent = Main,
    Size = UDim2.new(0.12, 0, 0, field_h),
    Position = UDim2.new(0.72, 0, 0, killDistY),
    BackgroundTransparency = 1,
    Text = tostring(Settings.KillDistance),
    TextColor3 = Theme.Accent,
    TextSize = 18,
    FontFace = FontFace,
    ZIndex = 4,
})

local killDistInc = Create("TextButton", {
    Parent = Main,
    Size = UDim2.new(0.08, 0, 0, field_h),
    Position = UDim2.new(0.86, 0, 0, killDistY),
    BackgroundColor3 = Theme.Element,
    Text = "+",
    TextColor3 = Theme.Text,
    TextSize = 22,
    FontFace = FontFace,
    AutoButtonColor = false,
    ZIndex = 4,
})
Corner(killDistInc, 5)

-- === СТАТУС ===
local statusY = killDistY + field_h + 8
local StatusLabel = Create("TextLabel", {
    Parent = Main,
    Size = UDim2.new(1, -pad*2, 0, 20),
    Position = UDim2.new(0, pad, 0, statusY),
    BackgroundTransparency = 1,
    Text = "🟢 Активен | Флингов: 0",
    TextColor3 = Theme.Inactive,
    TextSize = IsMobile and 13 or 12,
    FontFace = FontFace,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})

local panel_h = statusY + 20 + pad

-- === ЛОГИКА ФЛИНГА (исправлена, с MinDistance) ===
local function flingTarget(targetChar)
    if not targetChar or targetChar == Player.Character then return false end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return false end
    local myRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false end

    -- Проверяем дистанцию: если цель слишком близко, не трогаем
    local dist = (targetRoot.Position - myRoot.Position).magnitude
    if dist < Settings.MinDistance then
        return false
    end

    local dir = (targetRoot.Position - myRoot.Position).unit
    local upForce = Vector3.new(0, Settings.Power * 0.6, 0)
    local force = dir * Settings.Power + upForce

    if Settings.Mode == "Velocity" or Settings.Mode == "Hybrid" then
        local bv = Instance.new("BodyVelocity")
        bv.Velocity = force
        bv.MaxForce = Vector3.new(1,1,1) * 9e9
        bv.Parent = targetRoot
        Debris:AddItem(bv, 0.4)
        targetRoot.Velocity = force
    end
    if Settings.Mode == "Teleport" or Settings.Mode == "Hybrid" then
        local newPos = targetRoot.Position + dir * Settings.Power * 0.4 + Vector3.new(0, Settings.Power * 0.25, 0)
        targetRoot.CFrame = CFrame.new(newPos)
    end
    flingCount = flingCount + 1
    StatusLabel.Text = "🟢 Активен | Флингов: " .. flingCount
    return true
end

local function startFlingLoop()
    if flingLoopRunning then return end
    flingLoopRunning = true
    task.spawn(function()
        while flingLoopRunning do
            if not flingState.Get() then break end
            local myRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local closest = nil
                local minDist = Settings.Radius
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= Player then
                        local char = other.Character
                        if char then
                            local r = char:FindFirstChild("HumanoidRootPart")
                            if r then
                                local d = (r.Position - myRoot.Position).magnitude
                                if d < minDist and d >= Settings.MinDistance then
                                    minDist = d
                                    closest = char
                                end
                            end
                        end
                    end
                end
                if closest then
                    flingTarget(closest)
                end
            end
            task.wait(0.1)
        end
        flingLoopRunning = false
    end)
end

local function stopFlingLoop()
    flingLoopRunning = false
end

-- === АВТОПОДБОР ПИСТОЛЕТА ===
local function findGunOnGround()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") then
            local name = obj.Name:lower()
            if name:find("gun") or name:find("pistol") or name:find("sheriff") then
                return obj
            end
        end
    end
    return nil
end

local function pickupGun(gunTool)
    if not gunTool or not Player.Character then return end
    local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    if gunTool.Parent ~= Player.Character and gunTool.Parent ~= Player:FindFirstChild("Backpack") then
        local remote = gunTool:FindFirstChild("Remote") or gunTool:FindFirstChild("Pickup")
        if remote then
            pcall(function()
                remote:FireServer()
            end)
        else
            pcall(function()
                gunTool.Parent = Player:FindFirstChild("Backpack") or Player.Character
            end)
        end
    end
end

local function startAutoPickupLoop()
    if autoPickupLoopRunning then return end
    autoPickupLoopRunning = true
    task.spawn(function()
        while autoPickupLoopRunning do
            if not autoPickupState.Get() then break end
            if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
                local gun = findGunOnGround()
                if gun then
                    pickupGun(gun)
                end
            end
            task.wait(0.2)
        end
        autoPickupLoopRunning = false
    end)
end

local function stopAutoPickupLoop()
    autoPickupLoopRunning = false
end

-- === ПОДСВЕТКА РОЛЕЙ (исправлена) ===
local function getPlayerRole(plr)
    -- 1. Проверяем Data
    if plr:FindFirstChild("Data") and plr.Data:FindFirstChild("Role") then
        local role = plr.Data.Role.Value
        if role == "Murderer" or role == "M" then return "Murderer"
        elseif role == "Sheriff" or role == "S" then return "Sheriff"
        else return "Innocent" end
    end
    -- 2. Через leaderstats
    local leaderstats = plr:FindFirstChild("leaderstats")
    if leaderstats then
        local roleVal = leaderstats:FindFirstChild("Role") or leaderstats:FindFirstChild("RoleName")
        if roleVal then
            local role = roleVal.Value
            if role == "Murderer" or role == "M" then return "Murderer"
            elseif role == "Sheriff" or role == "S" then return "Sheriff"
            else return "Innocent" end
        end
    end
    -- 3. Через прямые объекты
    if plr:FindFirstChild("Murderer") then return "Murderer" end
    if plr:FindFirstChild("Sheriff") then return "Sheriff" end
    -- 4. Через атрибуты
    local attr = plr:GetAttribute("Role") or plr:GetAttribute("Murderer")
    if attr then
        if attr == "Murderer" or attr == true then return "Murderer"
        elseif attr == "Sheriff" then return "Sheriff" end
    end
    -- 5. Через инструменты в рюкзаке
    local backpack = plr:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local name = tool.Name:lower()
                if name:find("knife") or name:find("dagger") then
                    return "Murderer"
                elseif name:find("gun") or name:find("pistol") or name:find("sheriff") then
                    return "Sheriff"
                end
            end
        end
    end
    -- 6. Через инструменты в персонаже
    local char = plr.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                local name = tool.Name:lower()
                if name:find("knife") or name:find("dagger") then
                    return "Murderer"
                elseif name:find("gun") or name:find("pistol") or name:find("sheriff") then
                    return "Sheriff"
                end
            end
        end
        -- Проверка по имени персонажа (редко)
        local charName = char.Name:lower()
        if charName:find("murder") or charName:find("killer") then return "Murderer"
        elseif charName:find("sheriff") or charName:find("police") then return "Sheriff" end
    end
    -- 7. Через GUI (запасной вариант)
    local gui = plr:FindFirstChild("PlayerGui")
    if gui then
        for _, child in ipairs(gui:GetDescendants()) do
            if child:IsA("TextLabel") and child.Text then
                local t = child.Text:lower()
                if t:find("убийца") or t:find("murderer") then return "Murderer"
                elseif t:find("шериф") or t:find("sheriff") then return "Sheriff" end
            end
        end
    end
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
    task.spawn(function()
        while highlightLoopRunning do
            if not highlightState.Get() then break end

            -- Удаляем подсветку для игроков, которых больше нет
            for plr, hl in pairs(highlightCache) do
                if not plr.Parent or (plr.Character and not plr.Character:FindFirstChild("HumanoidRootPart")) then
                    if hl and hl.Parent then hl:Destroy() end
                    highlightCache[plr] = nil
                end
            end

            -- Обновляем подсветку для всех игроков
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

            task.wait(0.5)
        end

        -- Очистка при выключении
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

-- === AIMBOT (плавное сглаживание) ===
local aimSmoothing = 0.15 -- Чем меньше, тем плавнее (0.1–0.3)

local function hasGun()
    local char = Player.Character
    if not char then return false end
    local tool = char:FindFirstChildWhichIsA("Tool")
    if tool then
        local name = tool.Name:lower()
        if name:find("gun") or name:find("pistol") or name:find("sheriff") then
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
            if Settings.AimTarget == "Murderer" and role == "Murderer" then
                table.insert(targets, plr)
            elseif Settings.AimTarget == "Sheriff" and role == "Sheriff" then
                table.insert(targets, plr)
            elseif Settings.AimTarget == "All" or Settings.AimTarget == "Nearest" then
                table.insert(targets, plr)
            end
        end
    end
    return targets
end

local function getAngleToTarget(targetPos)
    local cameraPos = camera.CFrame.Position
    local lookVec = camera.CFrame.LookVector
    local toTarget = (targetPos - cameraPos).unit
    local angle = math.deg(math.acos(math.clamp(lookVec:Dot(toTarget), -1, 1)))
    return angle
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
                if dist < bestDist then
                    bestDist = dist
                    best = plr
                end
            else
                if angle < bestAngle then
                    bestAngle = angle
                    best = plr
                end
            end
        end
    end
    return best
end

local function smoothAimAt(target)
    if not target or not target.Character or not target.Character:FindFirstChild("Head") then return end
    local headPos = target.Character.Head.Position
    local targetCF = CFrame.new(camera.CFrame.Position, headPos)
    camera.CFrame = camera.CFrame:Lerp(targetCF, aimSmoothing)
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
            smoothAimAt(target)
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

-- === АВТОУБИЙСТВО (murderer) ===
local function canKill()
    -- Проверяем, является ли игрок murderer
    return getPlayerRole(Player) == "Murderer"
end

local function killTarget(targetChar)
    if not targetChar then return end
    local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.Health = 0
        StatusLabel.Text = "🔪 Убит " .. targetChar.Name
    end
end

local function startKillLoop()
    if killLoopRunning then return end
    killLoopRunning = true
    task.spawn(function()
        while killLoopRunning do
            if not killState.Get() then break end
            if not canKill() then
                StatusLabel.Text = "❌ Вы не murderer"
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
            task.wait(0.1)
        end
        killLoopRunning = false
    end)
end

local function stopKillLoop()
    killLoopRunning = false
end

-- === ОБРАБОТЧИКИ КНОПОК ===
decBtn.MouseButton1Click:Connect(function()
    Settings.Power = math.max(50, Settings.Power - 10)
    PowerLabel.Text = "Сила: " .. Settings.Power
    valueDisp.Text = tostring(Settings.Power)
    SaveSettings()
end)

incBtn.MouseButton1Click:Connect(function()
    Settings.Power = math.min(1000, Settings.Power + 10)
    PowerLabel.Text = "Сила: " .. Settings.Power
    valueDisp.Text = tostring(Settings.Power)
    SaveSettings()
end)

local modes = {"Velocity", "Teleport", "Hybrid"}
modeBtn.MouseButton1Click:Connect(function()
    local idx = table.find(modes, Settings.Mode) or 1
    idx = idx % #modes + 1
    Settings.Mode = modes[idx]
    ModeLabel.Text = "Режим: " .. Settings.Mode
    SaveSettings()
end)

local targetList = {"Murderer", "Sheriff", "All", "Nearest"}
aimTargetBtn.MouseButton1Click:Connect(function()
    local idx = table.find(targetList, Settings.AimTarget) or 1
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

-- Тогглы
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

-- Закрытие
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    stopFlingLoop()
    stopHighlightLoop()
    stopAimLoop()
    stopAutoPickupLoop()
    stopKillLoop()
end)

-- Перетаскивание
local dragging, dragStart, startPos
DragArea.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    dragging = true
    dragStart = input.Position
    startPos = Main.Position
end)
UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = (input.Position - dragStart) / UIScale.Scale
    Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                              startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- === АНИМАЦИЯ ПОЯВЛЕНИЯ ===
Tween(Main, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, panel_w, 0, panel_h)
})
MainStroke.Trans parency = 1
wait(0.05)
Tween(MainStroke, TweenInfo.new(0.25), { Transparency = 0.2 })

-- === ЗАПУСК ===
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

print("✅ XENO ULTIMATE v5 загружен. Все функции активны!")