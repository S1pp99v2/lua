-- Roblox 速度调节UI（稳定版）
-- 功能：输入框+按钮调速 + 快捷键调速 + 重生保留 + 实时反馈
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local CurrentSpeed = 16 -- 默认速度
local UI = nil

-- 核心：获取角色和人形对象
local function getCharacterAndHumanoid()
    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid", 5)
    return Character, Humanoid
end

-- 核心：更新速度（所有调节都会调用）
local function updateSpeed(newSpeed)
    -- 强制转为数字，限制0-500
    local numSpeed = tonumber(newSpeed) or 16
    CurrentSpeed = math.clamp(numSpeed, 0, 500)
    
    -- 应用到角色
    local _, Humanoid = getCharacterAndHumanoid()
    if Humanoid then
        Humanoid.WalkSpeed = CurrentSpeed
        print("[速度调节] 已设置为：" .. CurrentSpeed) -- 控制台反馈
    end
    
    -- 同步UI显示
    if UI and UI:FindFirstChild("MainFrame") then
        local SpeedDisplay = UI.MainFrame:FindFirstChild("SpeedDisplay")
        local SpeedInput = UI.MainFrame:FindFirstChild("SpeedInput")
        if SpeedDisplay then SpeedDisplay.Text = "当前速度: " .. CurrentSpeed end
        if SpeedInput then SpeedInput.Text = tostring(CurrentSpeed) end
    end
end

-- 监听角色重生，保持速度
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.2) -- 确保角色完全加载
    updateSpeed(CurrentSpeed)
end)

-- 创建极简稳定的UI
local function createSpeedUI()
    -- 主UI容器
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SpeedChangerUI"
    ScreenGui.Parent = LocalPlayer.PlayerGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- 可拖动主窗口
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.Size = UDim2.new(0, 280, 0, 120)
    MainFrame.Position = UDim2.new(0, 100, 0, 100)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    MainFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
    MainFrame.BorderSizePixel = 2
    MainFrame.Active = true
    MainFrame.Draggable = true -- 可拖动

    -- 标题
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Parent = MainFrame
    Title.Size = UDim2.new(1, 0, 0, 25)
    Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Title.Text = "速度调节面板（快捷键：+/-）"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.SourceSansBold
    Title.TextSize = 14

    -- 当前速度显示
    local SpeedDisplay = Instance.new("TextLabel")
    SpeedDisplay.Name = "SpeedDisplay"
    SpeedDisplay.Parent = MainFrame
    SpeedDisplay.Size = UDim2.new(1, 0, 0, 20)
    SpeedDisplay.Position = UDim2.new(0, 0, 0, 30)
    SpeedDisplay.BackgroundTransparency = 1
    SpeedDisplay.Text = "当前速度: " .. CurrentSpeed
    SpeedDisplay.TextColor3 = Color3.fromRGB(255, 255, 0) -- 黄色更醒目
    SpeedDisplay.Font = Enum.Font.SourceSans
    SpeedDisplay.TextSize = 14

    -- 输入框
    local SpeedInput = Instance.new("TextBox")
    SpeedInput.Name = "SpeedInput"
    SpeedInput.Parent = MainFrame
    SpeedInput.Size = UDim2.new(0, 80, 0, 25)
    SpeedInput.Position = UDim2.new(0, 10, 0, 55)
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
    ConfirmBtn.Position = UDim2.new(0, 95, 0, 55)
    ConfirmBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
    ConfirmBtn.Text = "确认设置"
    ConfirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ConfirmBtn.Font = Enum.Font.SourceSansBold
    ConfirmBtn.TextSize = 12
    -- 点击确认
    ConfirmBtn.MouseButton1Click:Connect(function()
        updateSpeed(SpeedInput.Text)
    end)

    -- 增加速度按钮（+10）
    local AddBtn = Instance.new("TextButton")
    AddBtn.Name = "AddBtn"
    AddBtn.Parent = MainFrame
    AddBtn.Size = UDim2.new(0, 50, 0, 25)
    AddBtn.Position = UDim2.new(0, 170, 0, 55)
    AddBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    AddBtn.Text = "+10"
    AddBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    AddBtn.Font = Enum.Font.SourceSansBold
    AddBtn.TextSize = 14
    AddBtn.MouseButton1Click:Connect(function()
        updateSpeed(CurrentSpeed + 10)
    end)

    -- 减少速度按钮（-10）
    local MinusBtn = Instance.new("TextButton")
    MinusBtn.Name = "MinusBtn"
    MinusBtn.Parent = MainFrame
    MinusBtn.Size = UDim2.new(0, 50, 0, 25)
    MinusBtn.Position = UDim2.new(0, 225, 0, 55)
    MinusBtn.BackgroundColor3 = Color3.fromRGB(255, 120, 0)
    MinusBtn.Text = "-10"
    MinusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinusBtn.Font = Enum.Font.SourceSansBold
    MinusBtn.TextSize = 14
    MinusBtn.MouseButton1Click:Connect(function()
        updateSpeed(CurrentSpeed - 10)
    end)

    -- 重置按钮
    local ResetBtn = Instance.new("TextButton")
    ResetBtn.Name = "ResetBtn"
    ResetBtn.Parent = MainFrame
    ResetBtn.Size = UDim2.new(0, 260, 0, 25)
    ResetBtn.Position = UDim2.new(0, 10, 0, 85)
    ResetBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    ResetBtn.Text = "重置为默认速度（16）"
    ResetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ResetBtn.Font = Enum.Font.SourceSansBold
    ResetBtn.TextSize = 12
    ResetBtn.MouseButton1Click:Connect(function()
        updateSpeed(16)
    end)

    UI = ScreenGui
    return ScreenGui
end

-- 快捷键支持（按 + 加10，按 - 减10）
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end -- 不干扰游戏内输入
    if input.KeyCode == Enum.KeyCode.Plus or input.KeyCode == Enum.KeyCode.Equals then
        updateSpeed(CurrentSpeed + 10)
    elseif input.KeyCode == Enum.KeyCode.Minus then
        updateSpeed(CurrentSpeed - 10)
    end
end)

-- 初始化
local function init()
    updateSpeed(CurrentSpeed) -- 初始速度
    createSpeedUI() -- 创建UI
    print("✅ 速度调节面板加载完成！")
    print("🔧 操作方式：")
    print("   1. 输入框填数字 → 点【确认设置】")
    print("   2. 点【+10/-10】快速调节")
    print("   3. 按键盘 +/- 快捷键调节")
    print("   4. 点【重置】恢复默认速度")
end

-- 启动
init()
