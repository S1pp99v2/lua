-- ===================== 【Roblox 飞行+速度+UI 整合版】 =====================
-- 文件名：roblox_combined_module.lua
-- 功能：整合飞行、速度调节、UI菜单，一键加载，无模块依赖
-- 快捷键：G键 - 打开/关闭UI菜单 | F键 - 切换飞行 | +/-键 - 调节地面速度
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local UI = nil
local MenuOpen = false

-- ===================== 核心配置 =====================
local Config = {
    -- 速度配置
    WalkSpeed = 16,
    FlySpeed = 50,
    -- 飞行状态
    IsFlying = false,
    -- 角色对象（动态获取，不预存）
    Character = nil,
    Humanoid = nil,
    RootPart = nil
}

-- ===================== 工具函数 =====================
-- 安全获取角色部件（动态获取，避免空值）
local function getCharacterParts()
    local success, result = pcall(function()
        Config.Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        Config.Humanoid = Config.Character:WaitForChild("Humanoid", 10)
        Config.RootPart = Config.Character:WaitForChild("HumanoidRootPart", 10)
        return true
    end)
    if not success then
        warn("[整合模块] 获取角色失败：" .. tostring(result))
        Config.Character = nil
        Config.Humanoid = nil
        Config.RootPart = nil
        return false
    end
    return true
end

-- 应用地面速度（容错版）
local function applyWalkSpeed(speed)
    local numSpeed = tonumber(speed) or 16
    Config.WalkSpeed = math.clamp(numSpeed, 0, 500)
    
    if not Config.Humanoid then
        if not getCharacterParts() then
            print("[⚡ 速度模块] 速度值已更新为：" .. Config.WalkSpeed .. "，角色加载后自动生效")
            return
        end
    end
    
    -- 飞行状态不修改地面速度
    if not Config.IsFlying then
        Config.Humanoid.WalkSpeed = Config.WalkSpeed
        print("[⚡ 速度模块] 地面速度已设置为：" .. Config.WalkSpeed)
    end
end

-- ===================== 飞行模块 =====================
-- 切换飞行状态
local function toggleFlying()
    if not getCharacterParts() then return end
    
    Config.IsFlying = not Config.IsFlying
    if Config.IsFlying then
        Config.Humanoid.PlatformStand = true
        Config.Humanoid.WalkSpeed = 0
        print("[✈️ 飞行模块] 飞行已开启 | WASD+空格+Shift控制")
    else
        Config.Humanoid.PlatformStand = false
        applyWalkSpeed(Config.WalkSpeed) -- 恢复地面速度
        print("[✈️ 飞行模块] 飞行已关闭")
    end
    
    -- 更新UI状态（如果UI已创建）
    if UI then
        updateFlyUIStatus()
    end
end

-- 飞行控制逻辑
local function handleFlying()
    if not Config.IsFlying or not Config.RootPart then return end
    
    local moveDir = Vector3.new()
    -- 方向键检测
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Vector3.new(0, 0, -1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir += Vector3.new(0, 0, 1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir += Vector3.new(-1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += Vector3.new(1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir += Vector3.new(0, -1, 0) end
    
    -- 相机方向适配
    local camera = workspace.CurrentCamera
    local lookDir = camera.CFrame.LookVector
    lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
    local rightDir = lookDir:Cross(Vector3.new(0, 1, 0))
    
    -- 计算最终移动方向
    local finalDir = (lookDir * -moveDir.Z) + (rightDir * moveDir.X) + Vector3.new(0, moveDir.Y, 0)
    Config.RootPart.Velocity = finalDir.Unit * Config.FlySpeed
end

-- ===================== 速度模块 =====================
-- 调节地面速度
local function adjustWalkSpeed(step)
    local newSpeed = Config.WalkSpeed + step
    applyWalkSpeed(newSpeed)
end

-- ===================== UI模块 =====================
-- UI样式常量
local STYLES = {
    Colors = {
        Primary = Color3.fromRGB(45, 90, 210),
        Secondary = Color3.fromRGB(60, 120, 255),
        Success = Color3.fromRGB(70, 200, 70),
        Danger = Color3.fromRGB(230, 70, 70),
        Accent = Color3.fromRGB(0, 200, 255),
        Background = Color3.fromRGB(18, 18, 22),
        Card = Color3.fromRGB(28, 28, 35),
        Text = Color3.fromRGB(240, 240, 245),
        TextLight = Color3.fromRGB(180, 180, 190)
    },
    Corners = {
        Large = UDim.new(0, 12),
        Medium = UDim.new(0, 8),
        Small = UDim.new(0, 4)
    },
    Shadows = {
        Size = 10,
        Transparency = 0.7
    }
}

-- UI工具函数
local function addGradient(frame, isVertical)
    local gradient = Instance.new("UIGradient")
    gradient.Parent = frame
    gradient.Rotation = isVertical and 90 or 0
    gradient.Color = ColorSequence.new(STYLES.Colors.Primary, STYLES.Colors.Secondary)
    return gradient
end

local function addShadow(frame)
    local shadow = Instance.new("ImageLabel")
    shadow.Parent = frame
    shadow.Name = "Shadow"
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://13160452170"
    shadow.ImageColor3 = Color3.new(0, 0, 0)
    shadow.ImageTransparency = STYLES.Shadows.Transparency
    shadow.Size = UDim2.new(1, STYLES.Shadows.Size, 1, STYLES.Shadows.Size)
    shadow.Position = UDim2.new(0, -STYLES.Shadows.Size/2, 0, -STYLES.Shadows.Size/2)
    shadow.ZIndex = frame.ZIndex - 1
    return shadow
end

local function tweenUI(obj, props, duration)
    local tweenInfo = TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(obj, tweenInfo, props)
    tween:Play()
    return tween
end

-- 更新飞行UI状态
local function updateFlyUIStatus()
    local flyToggleBtn = UI:FindFirstChild("MainMenu"):FindFirstChild("ContentContainer"):FindFirstChild("FlyCard"):FindFirstChild("FlyToggleBtn")
    local flyStatusText = UI:FindFirstChild("MainMenu"):FindFirstChild("ContentContainer"):FindFirstChild("FlyCard"):FindFirstChild("FlyStatusWrapper"):FindFirstChild("FlyStatusText")
    
    if flyToggleBtn and flyStatusText then
        tweenUI(flyToggleBtn, {BackgroundColor3 = Config.IsFlying and STYLES.Colors.Success or STYLES.Colors.Primary}, 0.2)
        flyToggleBtn.Text = Config.IsFlying and "✅ 飞行已开启" or "❌ 飞行已关闭"
        flyStatusText.Text = Config.IsFlying and "开启" or "关闭"
        flyStatusText.TextColor3 = Config.IsFlying and STYLES.Colors.Success or STYLES.Colors.Danger
    end
end

-- 更新速度UI状态
local function updateSpeedUIStatus()
    local speedDisplay = UI:FindFirstChild("MainMenu"):FindFirstChild("ContentContainer"):FindFirstChild("SpeedCard"):FindFirstChild("SpeedDisplayWrapper"):FindFirstChild("WalkSpeedDisplay")
    local speedInput = UI:FindFirstChild("MainMenu"):FindFirstChild("ContentContainer"):FindFirstChild("SpeedCard"):FindFirstChild("WalkSpeedInput")
    
    if speedDisplay and speedInput then
        speedDisplay.Text = tostring(Config.WalkSpeed)
        speedInput.Text = tostring(Config.WalkSpeed)
    end
end

-- 创建UI界面
local function createUI()
    -- 主容器
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SpeedFlyCombinedMenu"
    ScreenGui.Parent = LocalPlayer.PlayerGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- 侧边触发按钮
    local TriggerBtn = Instance.new("TextButton")
    TriggerBtn.Name = "TriggerBtn"
    TriggerBtn.Parent = ScreenGui
    TriggerBtn.Size = UDim2.new(0, 50, 0, 120)
    TriggerBtn.Position = UDim2.new(0, -40, 0.5, -60)
    TriggerBtn.BackgroundColor3 = STYLES.Colors.Primary
    local TriggerBtnCorner = Instance.new("UICorner")
    TriggerBtnCorner.CornerRadius = STYLES.Corners.Medium
    TriggerBtnCorner.Parent = TriggerBtn
    TriggerBtn.Text = "菜单"
    TriggerBtn.TextColor3 = STYLES.Colors.Text
    TriggerBtn.Font = Enum.Font.GothamBold
    TriggerBtn.TextSize = 16
    TriggerBtn.ZIndex = 100
    addGradient(TriggerBtn, true)
    addShadow(TriggerBtn)

    -- 触发按钮动画
    TriggerBtn.MouseEnter:Connect(function()
        tweenUI(TriggerBtn, {Position = UDim2.new(0, -10, 0.5, -60)}, 0.2)
    end)
    TriggerBtn.MouseLeave:Connect(function()
        if not MenuOpen then
            tweenUI(TriggerBtn, {Position = UDim2.new(0, -40, 0.5, -60)}, 0.2)
        end
    end)

    -- 主菜单面板
    local MainMenu = Instance.new("Frame")
    MainMenu.Name = "MainMenu"
    MainMenu.Parent = ScreenGui
    MainMenu.Size = UDim2.new(0, 400, 0, 500)
    MainMenu.Position = UDim2.new(0, -420, 0.5, -250)
    MainMenu.BackgroundColor3 = STYLES.Colors.Background
    local MainMenuCorner = Instance.new("UICorner")
    MainMenuCorner.CornerRadius = STYLES.Corners.Large
    MainMenuCorner.Parent = MainMenu
    MainMenu.ClipsDescendants = true
    MainMenu.ZIndex = 99
    addShadow(MainMenu)

    -- 菜单头部
    local MenuHeader = Instance.new("Frame")
    MenuHeader.Name = "MenuHeader"
    MenuHeader.Parent = MainMenu
    MenuHeader.Size = UDim2.new(1, 0, 0, 70)
    MenuHeader.BackgroundColor3 = STYLES.Colors.Primary
    addGradient(MenuHeader, false)

    local HeaderTitle = Instance.new("TextLabel")
    HeaderTitle.Parent = MenuHeader
    HeaderTitle.Size = UDim2.new(1, 0, 1, 0)
    HeaderTitle.BackgroundTransparency = 1
    HeaderTitle.Text = "⚡ 高级控制中心"
    HeaderTitle.TextColor3 = STYLES.Colors.Text
    HeaderTitle.Font = Enum.Font.GothamBold
    HeaderTitle.TextSize = 22

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Parent = MenuHeader
    CloseBtn.Size = UDim2.new(0, 40, 0, 40)
    CloseBtn.Position = UDim2.new(1, -50, 0.5, -20)
    CloseBtn.BackgroundColor3 = STYLES.Colors.Danger
    local CloseBtnCorner = Instance.new("UICorner")
    CloseBtnCorner.CornerRadius = STYLES.Corners.Medium
    CloseBtnCorner.Parent = CloseBtn
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = STYLES.Colors.Text
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 20

    -- 内容容器
    local ContentContainer = Instance.new("ScrollingFrame")
    ContentContainer.Name = "ContentContainer"
    ContentContainer.Parent = MainMenu
    ContentContainer.Size = UDim2.new(1, -20, 1, -80)
    ContentContainer.Position = UDim2.new(0, 10, 0, 70)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.ScrollBarThickness = 6
    ContentContainer.ScrollBarImageColor3 = STYLES.Colors.Primary
    ContentContainer.CanvasSize = UDim2.new(1, 0, 0, 420)

    -- ========== 速度调节卡片 ==========
    local SpeedCard = Instance.new("Frame")
    SpeedCard.Name = "SpeedCard"
    SpeedCard.Parent = ContentContainer
    SpeedCard.Size = UDim2.new(1, 0, 0, 140)
    SpeedCard.Position = UDim2.new(0, 0, 0, 10)
    SpeedCard.BackgroundColor3 = STYLES.Colors.Card
    local SpeedCardCorner = Instance.new("UICorner")
    SpeedCardCorner.CornerRadius = STYLES.Corners.Medium
    SpeedCardCorner.Parent = SpeedCard

    local SpeedCardTitle = Instance.new("TextLabel")
    SpeedCardTitle.Parent = SpeedCard
    SpeedCardTitle.Size = UDim2.new(1, -20, 0, 30)
    SpeedCardTitle.Position = UDim2.new(0, 10, 0, 10)
    SpeedCardTitle.BackgroundTransparency = 1
    SpeedCardTitle.Text = "地面速度调节"
    SpeedCardTitle.TextColor3 = STYLES.Colors.Text
    SpeedCardTitle.Font = Enum.Font.GothamBold
    SpeedCardTitle.TextSize = 18

    local SpeedDisplayWrapper = Instance.new("Frame")
    SpeedDisplayWrapper.Parent = SpeedCard
    SpeedDisplayWrapper.Size = UDim2.new(1, -20, 0, 40)
    SpeedDisplayWrapper.Position = UDim2.new(0, 10, 0, 45)
    SpeedDisplayWrapper.BackgroundColor3 = STYLES.Colors.Background
    local SpeedDisplayWrapperCorner = Instance.new("UICorner")
    SpeedDisplayWrapperCorner.CornerRadius = STYLES.Corners.Small
    SpeedDisplayWrapperCorner.Parent = SpeedDisplayWrapper

    local SpeedDisplayLabel = Instance.new("TextLabel")
    SpeedDisplayLabel.Parent = SpeedDisplayWrapper
    SpeedDisplayLabel.Size = UDim2.new(0, 80, 1, 0)
    SpeedDisplayLabel.Position = UDim2.new(0, 10, 0, 0)
    SpeedDisplayLabel.BackgroundTransparency = 1
    SpeedDisplayLabel.Text = "当前值："
    SpeedDisplayLabel.TextColor3 = STYLES.Colors.TextLight
    SpeedDisplayLabel.Font = Enum.Font.Gotham
    SpeedDisplayLabel.TextSize = 16

    local WalkSpeedDisplay = Instance.new("TextLabel")
    WalkSpeedDisplay.Name = "WalkSpeedDisplay"
    WalkSpeedDisplay.Parent = SpeedDisplayWrapper
    WalkSpeedDisplay.Size = UDim2.new(1, -90, 1, 0)
    WalkSpeedDisplay.Position = UDim2.new(0, 90, 0, 0)
    WalkSpeedDisplay.BackgroundTransparency = 1
    WalkSpeedDisplay.Text = tostring(Config.WalkSpeed)
    WalkSpeedDisplay.TextColor3 = STYLES.Colors.Accent
    WalkSpeedDisplay.Font = Enum.Font.GothamBold
    WalkSpeedDisplay.TextSize = 18

    local WalkSpeedInput = Instance.new("TextBox")
    WalkSpeedInput.Name = "WalkSpeedInput"
    WalkSpeedInput.Parent = SpeedCard
    WalkSpeedInput.Size = UDim2.new(0, 100, 0, 35)
    WalkSpeedInput.Position = UDim2.new(0, 10, 0, 90)
    WalkSpeedInput.BackgroundColor3 = STYLES.Colors.Background
    local WalkSpeedInputCorner = Instance.new("UICorner")
    WalkSpeedInputCorner.CornerRadius = STYLES.Corners.Small
    WalkSpeedInputCorner.Parent = WalkSpeedInput
    WalkSpeedInput.TextColor3 = STYLES.Colors.Text
    WalkSpeedInput.PlaceholderText = "输入速度值"
    WalkSpeedInput.Text = tostring(Config.WalkSpeed)
    WalkSpeedInput.Font = Enum.Font.Gotham
    WalkSpeedInput.TextSize = 16
    WalkSpeedInput.ClearTextOnFocus = false

    local SpeedConfirmBtn = Instance.new("TextButton")
    SpeedConfirmBtn.Parent = SpeedCard
    SpeedConfirmBtn.Size = UDim2.new(0, 100, 0, 35)
    SpeedConfirmBtn.Position = UDim2.new(0, 120, 0, 90)
    SpeedConfirmBtn.BackgroundColor3 = STYLES.Colors.Primary
    local SpeedConfirmBtnCorner = Instance.new("UICorner")
    SpeedConfirmBtnCorner.CornerRadius = STYLES.Corners.Small
    SpeedConfirmBtnCorner.Parent = SpeedConfirmBtn
    SpeedConfirmBtn.Text = "应用"
    SpeedConfirmBtn.TextColor3 = STYLES.Colors.Text
    SpeedConfirmBtn.Font = Enum.Font.GothamBold
    SpeedConfirmBtn.TextSize = 16
    addGradient(SpeedConfirmBtn, false)

    SpeedConfirmBtn.MouseButton1Click:Connect(function()
        applyWalkSpeed(WalkSpeedInput.Text)
        updateSpeedUIStatus()
        tweenUI(SpeedConfirmBtn, {BackgroundColor3 = STYLES.Colors.Success}, 0.1)
        task.wait(0.2)
        tweenUI(SpeedConfirmBtn, {BackgroundColor3 = STYLES.Colors.Primary}, 0.1)
    end)

    local SpeedResetBtn = Instance.new("TextButton")
    SpeedResetBtn.Parent = SpeedCard
    SpeedResetBtn.Size = UDim2.new(0, 100, 0, 35)
    SpeedResetBtn.Position = UDim2.new(0, 230, 0, 90)
    SpeedResetBtn.BackgroundColor3 = STYLES.Colors.Danger
    local SpeedResetBtnCorner = Instance.new("UICorner")
    SpeedResetBtnCorner.CornerRadius = STYLES.Corners.Small
    SpeedResetBtnCorner.Parent = SpeedResetBtn
    SpeedResetBtn.Text = "重置"
    SpeedResetBtn.TextColor3 = STYLES.Colors.Text
    SpeedResetBtn.Font = Enum.Font.GothamBold
    SpeedResetBtn.TextSize = 16

    SpeedResetBtn.MouseButton1Click:Connect(function()
        applyWalkSpeed(16)
        updateSpeedUIStatus()
        tweenUI(SpeedResetBtn, {BackgroundColor3 = STYLES.Colors.Accent}, 0.1)
        task.wait(0.2)
        tweenUI(SpeedResetBtn, {BackgroundColor3 = STYLES.Colors.Danger}, 0.1)
    end)

    -- ========== 飞行控制卡片 ==========
    local FlyCard = Instance.new("Frame")
    FlyCard.Name = "FlyCard"
    FlyCard.Parent = ContentContainer
    FlyCard.Size = UDim2.new(1, 0, 0, 200)
    FlyCard.Position = UDim2.new(0, 0, 0, 160)
    FlyCard.BackgroundColor3 = STYLES.Colors.Card
    local FlyCardCorner = Instance.new("UICorner")
    FlyCardCorner.CornerRadius = STYLES.Corners.Medium
    FlyCardCorner.Parent = FlyCard

    local FlyCardTitle = Instance.new("TextLabel")
    FlyCardTitle.Parent = FlyCard
    FlyCardTitle.Size = UDim2.new(1, -20, 0, 30)
    FlyCardTitle.Position = UDim2.new(0, 10, 0, 10)
    FlyCardTitle.BackgroundTransparency = 1
    FlyCardTitle.Text = "飞行控制"
    FlyCardTitle.TextColor3 = STYLES.Colors.Text
    FlyCardTitle.Font = Enum.Font.GothamBold
    FlyCardTitle.TextSize = 18

    local FlyStatusWrapper = Instance.new("Frame")
    FlyStatusWrapper.Parent = FlyCard
    FlyStatusWrapper.Size = UDim2.new(1, -20, 0, 40)
    FlyStatusWrapper.Position = UDim2.new(0, 10, 0, 45)
    FlyStatusWrapper.BackgroundColor3 = STYLES.Colors.Background
    local FlyStatusWrapperCorner = Instance.new("UICorner")
    FlyStatusWrapperCorner.CornerRadius = STYLES.Corners.Small
    FlyStatusWrapperCorner.Parent = FlyStatusWrapper

    local FlyStatusLabel = Instance.new("TextLabel")
    FlyStatusLabel.Parent = FlyStatusWrapper
    FlyStatusLabel.Size = UDim2.new(0, 80, 1, 0)
    FlyStatusLabel.Position = UDim2.new(0, 10, 0, 0)
    FlyStatusLabel.BackgroundTransparency = 1
    FlyStatusLabel.Text = "状态："
    FlyStatusLabel.TextColor3 = STYLES.Colors.TextLight
    FlyStatusLabel.Font = Enum.Font.Gotham
    FlyStatusLabel.TextSize = 16

    local FlyStatusText = Instance.new("TextLabel")
    FlyStatusText.Name = "FlyStatusText"
    FlyStatusText.Parent = FlyStatusWrapper
    FlyStatusText.Size = UDim2.new(1, -90, 1, 0)
    FlyStatusText.Position = UDim2.new(0, 90, 0, 0)
    FlyStatusText.BackgroundTransparency = 1
    FlyStatusText.Text = Config.IsFlying and "开启" or "关闭"
    FlyStatusText.TextColor3 = Config.IsFlying and STYLES.Colors.Success or STYLES.Colors.Danger
    FlyStatusText.Font = Enum.Font.GothamBold
    FlyStatusText.TextSize = 18

    local FlyToggleBtn = Instance.new("TextButton")
    FlyToggleBtn.Name = "FlyToggleBtn"
    FlyToggleBtn.Parent = FlyCard
    FlyToggleBtn.Size = UDim2.new(1, -20, 0, 40)
    FlyToggleBtn.Position = UDim2.new(0, 10, 0, 90)
    FlyToggleBtn.BackgroundColor3 = Config.IsFlying and STYLES.Colors.Success or STYLES.Colors.Primary
    local FlyToggleBtnCorner = Instance.new("UICorner")
    FlyToggleBtnCorner.CornerRadius = STYLES.Corners.Small
    FlyToggleBtnCorner.Parent = FlyToggleBtn
    FlyToggleBtn.Text = Config.IsFlying and "✅ 飞行已开启" or "❌ 飞行已关闭"
    FlyToggleBtn.TextColor3 = STYLES.Colors.Text
    FlyToggleBtn.Font = Enum.Font.GothamBold
    FlyToggleBtn.TextSize = 16
    addGradient(FlyToggleBtn, false)

    FlyToggleBtn.MouseButton1Click:Connect(function()
        toggleFlying()
    end)

    -- 飞行速度显示
    local FlySpeedDisplayWrapper = Instance.new("Frame")
    FlySpeedDisplayWrapper.Parent = FlyCard
    FlySpeedDisplayWrapper.Size = UDim2.new(1, -20, 0, 40)
    FlySpeedDisplayWrapper.Position = UDim2.new(0, 10, 0, 135)
    FlySpeedDisplayWrapper.BackgroundColor3 = STYLES.Colors.Background
    local FlySpeedDisplayWrapperCorner = Instance.new("UICorner")
    FlySpeedDisplayWrapperCorner.CornerRadius = STYLES.Corners.Small
    FlySpeedDisplayWrapperCorner.Parent = FlySpeedDisplayWrapper

    local FlySpeedDisplayLabel = Instance.new("TextLabel")
    FlySpeedDisplayLabel.Parent = FlySpeedDisplayWrapper
    FlySpeedDisplayLabel.Size = UDim2.new(0, 80, 1, 0)
    FlySpeedDisplayLabel.Position = UDim2.new(0, 10, 0, 0)
    FlySpeedDisplayLabel.BackgroundTransparency = 1
    FlySpeedDisplayLabel.Text = "飞行速度："
    FlySpeedDisplayLabel.TextColor3 = STYLES.Colors.TextLight
    FlySpeedDisplayLabel.Font = Enum.Font.Gotham
    FlySpeedDisplayLabel.TextSize = 16

    local FlySpeedDisplay = Instance.new("TextLabel")
    FlySpeedDisplay.Name = "FlySpeedDisplay"
    FlySpeedDisplay.Parent = FlySpeedDisplayWrapper
    FlySpeedDisplay.Size = UDim2.new(0, 60, 1, 0)
    FlySpeedDisplay.Position = UDim2.new(0, 90, 0, 0)
    FlySpeedDisplay.BackgroundTransparency = 1
    FlySpeedDisplay.Text = tostring(Config.FlySpeed)
    FlySpeedDisplay.TextColor3 = STYLES.Colors.Accent
    FlySpeedDisplay.Font = Enum.Font.GothamBold
    FlySpeedDisplay.TextSize = 18

    local FlySpeedInput = Instance.new("TextBox")
    FlySpeedInput.Name = "FlySpeedInput"
    FlySpeedInput.Parent = FlyCard
    FlySpeedInput.Size = UDim2.new(0, 80, 0, 30)
    FlySpeedInput.Position = UDim2.new(0, 160, 0, 140)
    FlySpeedInput.BackgroundColor3 = STYLES.Colors.Background
    local FlySpeedInputCorner = Instance.new("UICorner")
    FlySpeedInputCorner.CornerRadius = STYLES.Corners.Small
    FlySpeedInputCorner.Parent = FlySpeedInput
    FlySpeedInput.TextColor3 = STYLES.Colors.Text
    FlySpeedInput.PlaceholderText = "速度值"
    FlySpeedInput.Text = tostring(Config.FlySpeed)
    FlySpeedInput.Font = Enum.Font.Gotham
    FlySpeedInput.TextSize = 14
    FlySpeedInput.ClearTextOnFocus = false

    local FlySpeedConfirmBtn = Instance.new("TextButton")
    FlySpeedConfirmBtn.Parent = FlyCard
    FlySpeedConfirmBtn.Size = UDim2.new(0, 80, 0, 30)
    FlySpeedConfirmBtn.Position = UDim2.new(0, 250, 0, 140)
    FlySpeedConfirmBtn.BackgroundColor3 = STYLES.Colors.Primary
    local FlySpeedConfirmBtnCorner = Instance.new("UICorner")
    FlySpeedConfirmBtnCorner.CornerRadius = STYLES.Corners.Small
    FlySpeedConfirmBtnCorner.Parent = FlySpeedConfirmBtn
    FlySpeedConfirmBtn.Text = "应用"
    FlySpeedConfirmBtn.TextColor3 = STYLES.Colors.Text
    FlySpeedConfirmBtn.Font = Enum.Font.GothamBold
    FlySpeedConfirmBtn.TextSize = 14
    addGradient(FlySpeedConfirmBtn, false)

    FlySpeedConfirmBtn.MouseButton1Click:Connect(function()
        local newFlySpeed = tonumber(FlySpeedInput.Text) or 50
        Config.FlySpeed = math.clamp(newFlySpeed, 10, 200)
        FlySpeedDisplay.Text = tostring(Config.FlySpeed)
        tweenUI(FlySpeedConfirmBtn, {BackgroundColor3 = STYLES.Colors.Success}, 0.1)
        task.wait(0.2)
        tweenUI(FlySpeedConfirmBtn, {BackgroundColor3 = STYLES.Colors.Primary}, 0.1)
        print("[✈️ 飞行模块] 飞行速度已设置为：" .. Config.FlySpeed)
    end)

    -- ========== 菜单开关逻辑 ==========
    local function toggleMenu()
        MenuOpen = not MenuOpen
        if MenuOpen then
            tweenUI(TriggerBtn, {Position = UDim2.new(0, -10, 0.5, -60)}, 0.2)
            tweenUI(MainMenu, {Position = UDim2.new(0, 10, 0.5, -250)}, 0.3)
        else
            tweenUI(TriggerBtn, {Position = UDim2.new(0, -40, 0.5, -60)}, 0.2)
            tweenUI(MainMenu, {Position = UDim2.new(0, -420, 0.5, -250)}, 0.2)
        end
    end

    -- 绑定菜单开关
    TriggerBtn.MouseButton1Click:Connect(toggleMenu)
    CloseBtn.MouseButton1Click:Connect(toggleMenu)

    -- G键开关菜单
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.G then
            toggleMenu()
        end
    end)

    UI = ScreenGui
    return ScreenGui
end

-- ===================== 初始化 =====================
local function init()
    -- 1. 初始化飞行控制
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.F then
            toggleFlying()
        end
    end)
    RunService.RenderStepped:Connect(handleFlying)

    -- 2. 初始化速度控制
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Plus or input.KeyCode == Enum.KeyCode.Equals then
            adjustWalkSpeed(10)
            updateSpeedUIStatus()
        elseif input.KeyCode == Enum.KeyCode.Minus then
            adjustWalkSpeed(-10)
            updateSpeedUIStatus()
        end
    end)

    -- 3. 角色重生重置
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        Config.IsFlying = false
        applyWalkSpeed(Config.WalkSpeed)
        if UI then
            updateFlyUIStatus()
            updateSpeedUIStatus()
        end
    end)

    -- 4. 创建UI
    createUI()

    -- 5. 初始化完成提示
    print("====================================")
    print("🎉 飞行+速度+UI 整合模块加载完成！")
    print("🔧 快捷键说明：")
    print("   • G键：打开/关闭UI菜单")
    print("   • F键：切换飞行状态")
    print("   • +/-键：调节地面速度（每次±10）")
    print("   • WASD+空格+Shift：飞行控制")
    print("====================================")
end

-- 启动整合模块
init()
