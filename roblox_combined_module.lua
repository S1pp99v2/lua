-- ===================== 【Roblox 飞行+速度+UI 整合版】 =====================
-- 文件名：roblox_combined_module.lua
-- 功能：整合飞行、速度调节、UI菜单（小图标触发+滑块控制）
-- 快捷键：G键 - 打开/关闭UI菜单 | F键 - 切换飞行 | +/-键 - 调节地面速度
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local UI = nil
local MenuOpen = false

-- 全局滑块更新函数（修复：不用SetAttribute存函数）
local WalkSpeedSliderSetValue = nil
local FlySpeedSliderSetValue = nil

-- ===================== 核心配置 =====================
local Config = {
    -- 速度配置
    WalkSpeed = 16,
    FlySpeed = 50,
    -- 滑块范围
    WalkSpeedMin = 0,
    WalkSpeedMax = 500,
    FlySpeedMin = 10,
    FlySpeedMax = 200,
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
    Config.WalkSpeed = math.clamp(numSpeed, Config.WalkSpeedMin, Config.WalkSpeedMax)
    
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

-- 设置飞行速度
local function setFlySpeed(speed)
    local numSpeed = tonumber(speed) or 50
    Config.FlySpeed = math.clamp(numSpeed, Config.FlySpeedMin, Config.FlySpeedMax)
    print("[✈️ 飞行模块] 飞行速度已设置为：" .. Config.FlySpeed)
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
        TextLight = Color3.fromRGB(180, 180, 190),
        SliderTrack = Color3.fromRGB(50, 50, 60),
        SliderHandle = Color3.fromRGB(0, 200, 255)
    },
    Corners = {
        Large = UDim.new(0, 12),
        Medium = UDim.new(0, 8),
        Small = UDim.new(0, 4),
        Round = UDim.new(0, 100) -- 圆形
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

-- 创建滑块控件
local function createSlider(parent, position, minVal, maxVal, defaultValue, onChange)
    local sliderContainer = Instance.new("Frame")
    sliderContainer.Name = "SliderContainer"
    sliderContainer.Parent = parent
    sliderContainer.Size = UDim2.new(1, -20, 0, 60)
    sliderContainer.Position = position
    sliderContainer.BackgroundTransparency = 1

    -- 滑块标题
    local sliderTitle = Instance.new("TextLabel")
    sliderTitle.Name = "SliderTitle"
    sliderTitle.Parent = sliderContainer
    sliderTitle.Size = UDim2.new(1, 0, 0, 20)
    sliderTitle.Position = UDim2.new(0, 0, 0, 0)
    sliderTitle.BackgroundTransparency = 1
    sliderTitle.TextColor3 = STYLES.Colors.TextLight
    sliderTitle.Font = Enum.Font.Gotham
    sliderTitle.TextSize = 14

    -- 滑块数值显示
    local valueDisplay = Instance.new("TextLabel")
    valueDisplay.Name = "ValueDisplay"
    valueDisplay.Parent = sliderContainer
    valueDisplay.Size = UDim2.new(0, 60, 0, 20)
    valueDisplay.Position = UDim2.new(1, 0, 0, 0)
    valueDisplay.AnchorPoint = Vector2.new(1, 0)
    valueDisplay.BackgroundTransparency = 1
    valueDisplay.TextColor3 = STYLES.Colors.Accent
    valueDisplay.Font = Enum.Font.GothamBold
    valueDisplay.TextSize = 14
    valueDisplay.Text = tostring(defaultValue)

    -- 滑块轨道
    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Parent = sliderContainer
    track.Size = UDim2.new(1, -70, 0, 6)
    track.Position = UDim2.new(0, 0, 1, -10)
    track.AnchorPoint = Vector2.new(0, 1)
    track.BackgroundColor3 = STYLES.Colors.SliderTrack
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 3)
    trackCorner.Parent = track

    -- 滑块填充
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Parent = track
    fill.Size = UDim2.new((defaultValue - minVal)/(maxVal - minVal), 0, 1, 0)
    fill.Position = UDim2.new(0, 0, 0, 0)
    fill.BackgroundColor3 = STYLES.Colors.SliderHandle
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 3)
    fillCorner.Parent = fill
    addGradient(fill, false)

    -- 滑块手柄
    local handle = Instance.new("Frame")
    handle.Name = "Handle"
    handle.Parent = track
    handle.Size = UDim2.new(0, 18, 0, 18)
    handle.Position = UDim2.new((defaultValue - minVal)/(maxVal - minVal), -9, 0.5, -9)
    handle.AnchorPoint = Vector2.new(0.5, 0.5)
    handle.BackgroundColor3 = STYLES.Colors.SliderHandle
    local handleCorner = Instance.new("UICorner")
    handleCorner.CornerRadius = STYLES.Corners.Round
    handleCorner.Parent = handle
    addShadow(handle)

    -- 滑块拖动逻辑
    local isDragging = false
    
    local function updateSlider(value)
        local normalized = (value - minVal)/(maxVal - minVal)
        normalized = math.clamp(normalized, 0, 1)
        
        local actualValue = minVal + normalized * (maxVal - minVal)
        actualValue = math.floor(actualValue) -- 取整
        
        -- 更新UI
        tweenUI(fill, {Size = UDim2.new(normalized, 0, 1, 0)}, 0.1)
        tweenUI(handle, {Position = UDim2.new(normalized, -9, 0.5, -9)}, 0.1)
        valueDisplay.Text = tostring(actualValue)
        
        -- 回调更新数值
        if onChange then
            onChange(actualValue)
        end
    end

    -- 初始更新
    updateSlider(defaultValue)

    -- 绑定拖动事件
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = input.Position
            local trackPos = track.AbsolutePosition
            local trackSize = track.AbsoluteSize
            
            local x = math.clamp((mousePos.X - trackPos.X)/trackSize.X, 0, 1)
            local value = minVal + x * (maxVal - minVal)
            updateSlider(value)
        end
    end)

    -- 点击轨道跳转
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mousePos = input.Position
            local trackPos = track.AbsolutePosition
            local trackSize = track.AbsoluteSize
            
            local x = math.clamp((mousePos.X - trackPos.X)/trackSize.X, 0, 1)
            local value = minVal + x * (maxVal - minVal)
            updateSlider(value)
        end
    end)

    -- 返回滑块控件和更新函数
    return {
        Container = sliderContainer,
        SetValue = updateSlider,
        SetTitle = function(title)
            sliderTitle.Text = title
        end
    }
end

-- 更新飞行UI状态
local function updateFlyUIStatus()
    if not UI then return end
    
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
    if not UI then return end
    
    if WalkSpeedSliderSetValue then
        WalkSpeedSliderSetValue(Config.WalkSpeed)
    end
    if FlySpeedSliderSetValue then
        FlySpeedSliderSetValue(Config.FlySpeed)
    end
end

-- 创建UI界面
local function createUI()
    -- 主容器
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SpeedFlyCombinedMenu"
    ScreenGui.Parent = LocalPlayer.PlayerGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- ========== 侧边小图标触发按钮 ==========
    local TriggerIcon = Instance.new("ImageButton")
    TriggerIcon.Name = "TriggerIcon"
    TriggerIcon.Parent = ScreenGui
    TriggerIcon.Size = UDim2.new(0, 40, 0, 40) -- 小图标尺寸
    TriggerIcon.Position = UDim2.new(0, 5, 0.5, -20) -- 侧边显示
    TriggerIcon.BackgroundColor3 = STYLES.Colors.Primary
    local TriggerIconCorner = Instance.new("UICorner")
    TriggerIconCorner.CornerRadius = STYLES.Corners.Round -- 圆形图标
    TriggerIconCorner.Parent = TriggerIcon
    TriggerIcon.Image = "rbxassetid://10704143577" -- 控制面板图标
    TriggerIcon.ImageColor3 = STYLES.Colors.Text
    TriggerIcon.ImageTransparency = 0
    TriggerIcon.ZIndex = 100
    addGradient(TriggerIcon, false)
    addShadow(TriggerIcon)

    -- 图标悬停动画
    TriggerIcon.MouseEnter:Connect(function()
        tweenUI(TriggerIcon, {Size = UDim2.new(0, 48, 0, 48), Position = UDim2.new(0, 1, 0.5, -24)}, 0.2)
    end)
    TriggerIcon.MouseLeave:Connect(function()
        if not MenuOpen then
            tweenUI(TriggerIcon, {Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(0, 5, 0.5, -20)}, 0.2)
        end
    end)

    -- ========== 主菜单面板 ==========
    local MainMenu = Instance.new("Frame")
    MainMenu.Name = "MainMenu"
    MainMenu.Parent = ScreenGui
    MainMenu.Size = UDim2.new(0, 380, 0, 480)
    MainMenu.Position = UDim2.new(0, -400, 0.5, -240) -- 初始隐藏
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
    MenuHeader.Size = UDim2.new(1, 0, 0, 60)
    MenuHeader.BackgroundColor3 = STYLES.Colors.Primary
    addGradient(MenuHeader, false)

    local HeaderTitle = Instance.new("TextLabel")
    HeaderTitle.Parent = MenuHeader
    HeaderTitle.Size = UDim2.new(1, -60, 1, 0)
    HeaderTitle.Position = UDim2.new(0, 20, 0, 0)
    HeaderTitle.BackgroundTransparency = 1
    HeaderTitle.Text = "⚡ 控制中心"
    HeaderTitle.TextColor3 = STYLES.Colors.Text
    HeaderTitle.Font = Enum.Font.GothamBold
    HeaderTitle.TextSize = 20

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Parent = MenuHeader
    CloseBtn.Size = UDim2.new(0, 36, 0, 36)
    CloseBtn.Position = UDim2.new(1, -22, 0.5, -18)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255, 0.2)
    CloseBtn.BackgroundTransparency = 0.2
    local CloseBtnCorner = Instance.new("UICorner")
    CloseBtnCorner.CornerRadius = STYLES.Corners.Round
    CloseBtnCorner.Parent = CloseBtn
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = STYLES.Colors.Text
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 18

    -- 内容容器
    local ContentContainer = Instance.new("ScrollingFrame")
    ContentContainer.Name = "ContentContainer"
    ContentContainer.Parent = MainMenu
    ContentContainer.Size = UDim2.new(1, -20, 1, -70)
    ContentContainer.Position = UDim2.new(0, 10, 0, 60)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.ScrollBarThickness = 4
    ContentContainer.ScrollBarImageColor3 = STYLES.Colors.Primary
    ContentContainer.CanvasSize = UDim2.new(1, 0, 0, 400)

    -- ========== 速度调节卡片（滑块版） ==========
    local SpeedCard = Instance.new("Frame")
    SpeedCard.Name = "SpeedCard"
    SpeedCard.Parent = ContentContainer
    SpeedCard.Size = UDim2.new(1, 0, 0, 160)
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

    -- 地面速度滑块
    local walkSpeedSlider = createSlider(
        SpeedCard,
        UDim2.new(0, 0, 0, 45),
        Config.WalkSpeedMin,
        Config.WalkSpeedMax,
        Config.WalkSpeed,
        function(value)
            applyWalkSpeed(value)
        end
    )
    walkSpeedSlider.SetTitle("地面移动速度 (0-500)")
    -- 修复：把更新函数存到全局变量，不用SetAttribute
    WalkSpeedSliderSetValue = walkSpeedSlider.SetValue

    local SpeedResetBtn = Instance.new("TextButton")
    SpeedResetBtn.Parent = SpeedCard
    SpeedResetBtn.Size = UDim2.new(0, 80, 0, 30)
    SpeedResetBtn.Position = UDim2.new(0, 10, 0, 110)
    SpeedResetBtn.BackgroundColor3 = STYLES.Colors.Danger
    local SpeedResetBtnCorner = Instance.new("UICorner")
    SpeedResetBtnCorner.CornerRadius = STYLES.Corners.Small
    SpeedResetBtnCorner.Parent = SpeedResetBtn
    SpeedResetBtn.Text = "重置"
    SpeedResetBtn.TextColor3 = STYLES.Colors.Text
    SpeedResetBtn.Font = Enum.Font.GothamBold
    SpeedResetBtn.TextSize = 14

    SpeedResetBtn.MouseButton1Click:Connect(function()
        applyWalkSpeed(16)
        if WalkSpeedSliderSetValue then
            WalkSpeedSliderSetValue(16)
        end
        tweenUI(SpeedResetBtn, {BackgroundColor3 = STYLES.Colors.Accent}, 0.1)
        task.wait(0.2)
        tweenUI(SpeedResetBtn, {BackgroundColor3 = STYLES.Colors.Danger}, 0.1)
    end)

    -- ========== 飞行控制卡片（滑块版） ==========
    local FlyCard = Instance.new("Frame")
    FlyCard.Name = "FlyCard"
    FlyCard.Parent = ContentContainer
    FlyCard.Size = UDim2.new(1, 0, 0, 200)
    FlyCard.Position = UDim2.new(0, 0, 0, 180)
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
    FlyStatusWrapper.Size = UDim2.new(1, -20, 0, 30)
    FlyStatusWrapper.Position = UDim2.new(0, 10, 0, 45)
    FlyStatusWrapper.BackgroundColor3 = STYLES.Colors.Background
    local FlyStatusWrapperCorner = Instance.new("UICorner")
    FlyStatusWrapperCorner.CornerRadius = STYLES.Corners.Small
    FlyStatusWrapperCorner.Parent = FlyStatusWrapper

    local FlyStatusLabel = Instance.new("TextLabel")
    FlyStatusLabel.Parent = FlyStatusWrapper
    FlyStatusLabel.Size = UDim2.new(0, 60, 1, 0)
    FlyStatusLabel.Position = UDim2.new(0, 10, 0, 0)
    FlyStatusLabel.BackgroundTransparency = 1
    FlyStatusLabel.Text = "状态："
    FlyStatusLabel.TextColor3 = STYLES.Colors.TextLight
    FlyStatusLabel.Font = Enum.Font.Gotham
    FlyStatusLabel.TextSize = 14

    local FlyStatusText = Instance.new("TextLabel")
    FlyStatusText.Name = "FlyStatusText"
    FlyStatusText.Parent = FlyStatusWrapper
    FlyStatusText.Size = UDim2.new(1, -70, 1, 0)
    FlyStatusText.Position = UDim2.new(0, 70, 0, 0)
    FlyStatusText.BackgroundTransparency = 1
    FlyStatusText.Text = Config.IsFlying and "开启" or "关闭"
    FlyStatusText.TextColor3 = Config.IsFlying and STYLES.Colors.Success or STYLES.Colors.Danger
    FlyStatusText.Font = Enum.Font.GothamBold
    FlyStatusText.TextSize = 14

    local FlyToggleBtn = Instance.new("TextButton")
    FlyToggleBtn.Name = "FlyToggleBtn"
    FlyToggleBtn.Parent = FlyCard
    FlyToggleBtn.Size = UDim2.new(1, -20, 0, 35)
    FlyToggleBtn.Position = UDim2.new(0, 10, 0, 85)
    FlyToggleBtn.BackgroundColor3 = Config.IsFlying and STYLES.Colors.Success or STYLES.Colors.Primary
    local FlyToggleBtnCorner = Instance.new("UICorner")
    FlyToggleBtnCorner.CornerRadius = STYLES.Corners.Small
    FlyToggleBtnCorner.Parent = FlyToggleBtn
    FlyToggleBtn.Text = Config.IsFlying and "✅ 飞行已开启" or "❌ 飞行已关闭"
    FlyToggleBtn.TextColor3 = STYLES.Colors.Text
    FlyToggleBtn.Font = Enum.Font.GothamBold
    FlyToggleBtn.TextSize = 14
    addGradient(FlyToggleBtn, false)

    FlyToggleBtn.MouseButton1Click:Connect(function()
        toggleFlying()
    end)

    -- 飞行速度滑块
    local flySpeedSlider = createSlider(
        FlyCard,
        UDim2.new(0, 0, 0, 130),
        Config.FlySpeedMin,
        Config.FlySpeedMax,
        Config.FlySpeed,
        function(value)
            setFlySpeed(value)
        end
    )
    flySpeedSlider.SetTitle("飞行速度 (10-200)")
    -- 修复：把更新函数存到全局变量，不用SetAttribute
    FlySpeedSliderSetValue = flySpeedSlider.SetValue

    -- ========== 菜单开关逻辑 ==========
    local function toggleMenu()
        MenuOpen = not MenuOpen
        if MenuOpen then
            -- 展开菜单
            tweenUI(TriggerIcon, {Size = UDim2.new(0, 48, 0, 48), Position = UDim2.new(0, 390, 0.5, -24)}, 0.2)
            tweenUI(MainMenu, {Position = UDim2.new(0, 50, 0.5, -240)}, 0.3)
        else
            -- 收起菜单
            tweenUI(TriggerIcon, {Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(0, 5, 0.5, -20)}, 0.2)
            tweenUI(MainMenu, {Position = UDim2.new(0, -400, 0.5, -240)}, 0.2)
        end
    end

    -- 绑定菜单开关
    TriggerIcon.MouseButton1Click:Connect(toggleMenu)
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
    print("   • G键/点击侧边图标：打开/关闭UI菜单")
    print("   • F键：切换飞行状态")
    print("   • +/-键：调节地面速度（每次±10）")
    print("   • WASD+空格+Shift：飞行控制")
    print("====================================")
end

-- 启动整合模块
init()
