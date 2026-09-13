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
