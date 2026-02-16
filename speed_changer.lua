-- Roblox 速度调节+飞行整合脚本
-- 功能：速度调节（输入/按钮/快捷键） + 飞行控制（F键开关，WASD/空格/左Shift控制）
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local CurrentSpeed = 16 -- 默认移动速度
local IsFlying = false  -- 飞行状态
local FlySpeed = 50     -- 飞行速度
local UI = nil
local Character, Humanoid, RootPart = nil, nil, nil

-- 核心：获取角色/人形对象/根部件
local function getCharacterParts()
    Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    Humanoid = Character:WaitForChild("Humanoid", 5)
    RootPart = Character:WaitForChild("HumanoidRootPart", 5)
    return Character, Humanoid, RootPart
end

-- 更新移动速度
local function updateSpeed(newSpeed)
    local numSpeed = tonumber(newSpeed) or 16
    CurrentSpeed = math.clamp(numSpeed, 0, 500)
    
    getCharacterParts()
    if Humanoid then
        Humanoid.WalkSpeed = CurrentSpeed
        print("[速度调节] 已设置为：" .. CurrentSpeed)
    end
    
    -- 同步UI显示
    if UI and UI:FindFirstChild("MainFrame") then
        local SpeedDisplay = UI.MainFrame:FindFirstChild("SpeedDisplay")
        local SpeedInput = UI.MainFrame:FindFirstChild("SpeedInput")
        if SpeedDisplay then SpeedDisplay.Text = "当前速度: " .. CurrentSpeed end
        if SpeedInput then SpeedInput.Text = tostring(CurrentSpeed) end
    end
end

-- 切换飞行状态
local function toggleFlying()
    IsFlying = not IsFlying
    getCharacterParts()
    
    if IsFlying then
        -- 开启飞行
        if Humanoid then
            Humanoid.PlatformStand = true -- 禁用物理
            Humanoid.WalkSpeed = 0        -- 关闭地面移动
        end
        print("[飞行功能] 已开启（WASD移动，空格上升，左Shift下降，F键关闭）")
    else
        -- 关闭飞行
        if Humanoid then
            Humanoid.PlatformStand = false
            Humanoid.WalkSpeed = CurrentSpeed -- 恢复地面速度
        end
        print("[飞行功能] 已关闭")
    end
    
    -- 更新UI飞行状态显示
    if UI and UI:FindFirstChild("MainFrame") then
        local FlyStatus = UI.MainFrame:FindFirstChild("FlyStatus")
        if FlyStatus then
            FlyStatus.Text = IsFlying and "飞行状态：开启 ✈️" or "飞行状态：关闭 🚶"
            FlyStatus.TextColor3 = IsFlying and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
        end
    end
end

-- 飞行控制逻辑（每帧更新）
local function handleFlying()
    if not IsFlying or not RootPart then return end
    
    local moveDir = Vector3.new()
    -- 键盘输入检测
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Vector3.new(0, 0, -1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir + Vector3.new(0, 0, 1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir + Vector3.new(-1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Vector3.new(1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir + Vector3.new(0, -1, 0) end
    
    -- 转换为世界方向
    if LocalPlayer.Character then
        local camera = workspace.CurrentCamera
        local lookDir = camera.CFrame.LookVector
        lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
        
        local rightDir = lookDir:Cross(Vector3.new(0, 1, 0))
        local forwardDir = lookDir
        
        local finalDir = (forwardDir * -moveDir.Z) + (rightDir * moveDir.X) + Vector3.new(0, moveDir.Y, 0)
        finalDir = finalDir.Unit
        
        -- 移动根部件
        RootPart.Velocity = finalDir * FlySpeed
    end
end

-- 创建整合版UI
local function createUI()
    -- 主UI容器
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SpeedFlyUI"
    ScreenGui.Parent = LocalPlayer.PlayerGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- 可拖动主窗口
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.Size = UDim2.new(0, 300, 0, 180)
    MainFrame.Position = UDim2.new(0, 100, 0, 100)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    MainFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
    MainFrame.BorderSizePixel = 2
    MainFrame.Active = true
    MainFrame.Draggable = true

    -- 标题
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Parent = MainFrame
    Title.Size = UDim2.new(1, 0, 0, 25)
    Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Title.Text = "速度+飞行控制面板（F键开关飞行）"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.SourceSansBold
    Title.TextSize = 14

    -- 飞行状态显示
    local FlyStatus = Instance.new("TextLabel")
    FlyStatus.Name = "FlyStatus"
    FlyStatus.Parent = MainFrame
    FlyStatus.Size = UDim2.new(1, 0, 0, 20)
    FlyStatus.Position = UDim2.new(0, 0, 0, 30)
    FlyStatus.BackgroundTransparency = 1
    FlyStatus.Text = "飞行状态：关闭 🚶"
    FlyStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
    FlyStatus.Font = Enum.Font.SourceSans
    FlyStatus.TextSize = 14

    -- 速度显示
    local SpeedDisplay = Instance.new("TextLabel")
    SpeedDisplay.Name = "SpeedDisplay"
    SpeedDisplay.Parent = MainFrame
    SpeedDisplay.Size = UDim2.new(1, 0, 0, 20)
    SpeedDisplay.Position = UDim2.new(0, 0, 0, 55)
    SpeedDisplay.BackgroundTransparency = 1
    SpeedDisplay.Text = "当前速度: " .. CurrentSpeed
    SpeedDisplay.TextColor3 = Color3.fromRGB(255, 255, 0)
    SpeedDisplay.Font = Enum.Font.SourceSans
    SpeedDisplay.TextSize = 14

    -- 速度输入框
    local SpeedInput = Instance.new("TextBox")
    SpeedInput.Name = "SpeedInput"
    SpeedInput.Parent = MainFrame
    SpeedInput.Size = UDim2.new(0, 80, 0, 25)
    SpeedInput.Position = UDim2.new(0, 10, 0, 80)
    SpeedInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    SpeedInput.PlaceholderText = "输入速度（如50）"
    SpeedInput.Text = tostring(CurrentSpeed)
    SpeedInput.Font = Enum.Font.SourceSans
    SpeedInput.TextSize = 14
    SpeedInput.ClearTextOnFocus = false

    -- 确认按钮
    local ConfirmBtn = Instance.new("TextButton")
    ConfirmBtn.Name = "ConfirmBtn"
    ConfirmBtn.Parent = MainFrame
    ConfirmBtn.Size = UDim2.new(0, 70, 0, 25)
    ConfirmBtn.Position = UDim2.new(0, 95, 0, 80)
    ConfirmBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
    ConfirmBtn.Text = "确认设置"
    ConfirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ConfirmBtn.Font = Enum.Font.SourceSansBold
    ConfirmBtn.TextSize = 12
    ConfirmBtn.MouseButton1Click:Connect(function()
        updateSpeed(SpeedInput.Text)
    end)

    -- 速度+10按钮
    local AddBtn = Instance.new("TextButton")
    AddBtn.Name = "AddBtn"
    AddBtn.Parent = MainFrame
    AddBtn.Size = UDim2.new(0, 50, 0, 25)
    AddBtn.Position = UDim2.new(0, 170, 0, 80)
    AddBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    AddBtn.Text = "+10"
    AddBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    AddBtn.Font = Enum.Font.SourceSansBold
    AddBtn.TextSize = 14
    AddBtn.MouseButton1Click:Connect(function()
        updateSpeed(CurrentSpeed + 10)
    end)

    -- 速度-10按钮
    local MinusBtn = Instance.new("TextButton")
    MinusBtn.Name = "MinusBtn"
    MinusBtn.Parent = MainFrame
    MinusBtn.Size = UDim2.new(0, 50, 0, 25)
    MinusBtn.Position = UDim2.new(0, 225, 0, 80)
    MinusBtn.BackgroundColor3 = Color3.fromRGB(255, 120, 0)
    MinusBtn.Text = "-10"
    MinusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinusBtn.Font = Enum.Font.SourceSansBold
    MinusBtn.TextSize = 14
    MinusBtn.MouseButton1Click:Connect(function()
        updateSpeed(CurrentSpeed - 10)
    end)

    -- 飞行速度调节
    local FlySpeedLabel = Instance.new("TextLabel")
    FlySpeedLabel.Name = "FlySpeedLabel"
    FlySpeedLabel.Parent = MainFrame
    FlySpeedLabel.Size = UDim2.new(1, 0, 0, 20)
    FlySpeedLabel.Position = UDim2.new(0, 0, 0, 110)
    FlySpeedLabel.BackgroundTransparency = 1
    FlySpeedLabel.Text = "飞行速度: " .. FlySpeed
    FlySpeedLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
    FlySpeedLabel.Font = Enum.Font.SourceSans
    FlySpeedLabel.TextSize = 14

    -- 飞行速度+10按钮
    local FlyAddBtn = Instance.new("TextButton")
    FlyAddBtn.Name = "FlyAddBtn"
    FlyAddBtn.Parent = MainFrame
    FlyAddBtn.Size = UDim2.new(0, 60, 0, 25)
    FlyAddBtn.Position = UDim2.new(0, 10, 0, 135)
    FlyAddBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 255)
    FlyAddBtn.Text = "飞行+10"
    FlyAddBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    FlyAddBtn.Font = Enum.Font.SourceSansBold
    FlyAddBtn.TextSize = 12
    FlyAddBtn.MouseButton1Click:Connect(function()
        FlySpeed = math.clamp(FlySpeed + 10, 10, 200)
        FlySpeedLabel.Text = "飞行速度: " .. FlySpeed
        print("[飞行调节] 速度已设置为：" .. FlySpeed)
    end)

    -- 飞行速度-10按钮
    local FlyMinusBtn = Instance.new("TextButton")
    FlyMinusBtn.Name = "FlyMinusBtn"
    FlyMinusBtn.Parent = MainFrame
    FlyMinusBtn.Size = UDim2.new(0, 60, 0, 25)
    FlyMinusBtn.Position = UDim2.new(0, 80, 0, 135)
    FlyMinusBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 255)
    FlyMinusBtn.Text = "飞行-10"
    FlyMinusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    FlyMinusBtn.Font = Enum.Font.SourceSansBold
    FlyMinusBtn.TextSize = 12
    FlyMinusBtn.MouseButton1Click:Connect(function()
        FlySpeed = math.clamp(FlySpeed - 10, 10, 200)
        FlySpeedLabel.Text = "飞行速度: " .. FlySpeed
        print("[飞行调节] 速度已设置为：" .. FlySpeed)
    end)

    -- 重置按钮
    local ResetBtn = Instance.new("TextButton")
    ResetBtn.Name = "ResetBtn"
    ResetBtn.Parent = MainFrame
    ResetBtn.Size = UDim2.new(0, 120, 0, 25)
    ResetBtn.Position = UDim2.new(0, 150, 0, 135)
    ResetBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    ResetBtn.Text = "重置所有设置"
    ResetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ResetBtn.Font = Enum.Font.SourceSansBold
    ResetBtn.TextSize = 12
    ResetBtn.MouseButton1Click:Connect(function()
        CurrentSpeed = 16
        FlySpeed = 50
        updateSpeed(16)
        FlySpeedLabel.Text = "飞行速度: " .. FlySpeed
        if IsFlying then toggleFlying() end -- 关闭飞行
        print("[重置] 已恢复所有默认设置")
    end)

    UI = ScreenGui
    return ScreenGui
end

-- 监听按键事件
local function initInputListeners()
    -- F键切换飞行
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        -- 速度调节快捷键
        if input.KeyCode == Enum.KeyCode.Plus or input.KeyCode == Enum.KeyCode.Equals then
            updateSpeed(CurrentSpeed + 10)
        elseif input.KeyCode == Enum.KeyCode.Minus then
            updateSpeed(CurrentSpeed - 10)
        -- F键切换飞行
        elseif input.KeyCode == Enum.KeyCode.F then
            toggleFlying()
        end
    end)

    -- 每帧处理飞行逻辑
    RunService.RenderStepped:Connect(handleFlying)

    -- 角色重生监听
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.2)
        updateSpeed(CurrentSpeed)
        IsFlying = false -- 重生后关闭飞行
        if UI and UI:FindFirstChild("MainFrame") then
            local FlyStatus = UI.MainFrame:FindFirstChild("FlyStatus")
            if FlyStatus then
                FlyStatus.Text = "飞行状态：关闭 🚶"
                FlyStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
    end)
end

-- 初始化
local function init()
    getCharacterParts()
    updateSpeed(CurrentSpeed)
    createUI()
    initInputListeners()
    print("✅ 速度+飞行面板加载完成！")
    print("🔧 操作说明：")
    print("   1. 速度调节：输入框/±10按钮/键盘+/-键")
    print("   2. 飞行控制：F键开关，WASD移动，空格上升，左Shift下降")
    print("   3. 飞行速度：±10按钮调节（10-200范围）")
    print("   4. 重置按钮：恢复默认速度+关闭飞行")
end

-- 启动脚本
init()
