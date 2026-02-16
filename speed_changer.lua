-- 极简稳定版（速度+飞行）- 兼容所有注入器
-- 无复杂UI/动画，仅基础功能+日志反馈
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local CurrentWalkSpeed = 16   -- 地面速度
local IsFlying = false        -- 飞行状态
local FlySpeed = 50           -- 飞行速度
local Character, Humanoid, RootPart = nil, nil, nil

-- 核心：安全获取角色部件（带错误捕获）
local function getCharacterParts()
    local success, result = pcall(function()
        Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        Humanoid = Character:WaitForChild("Humanoid", 10)
        RootPart = Character:WaitForChild("HumanoidRootPart", 10)
        return true
    end)
    if not success then
        warn("获取角色失败：" .. result)
        return false
    end
    return true
end

-- 设置地面速度
local function setWalkSpeed(speed)
    local numSpeed = tonumber(speed) or 16
    CurrentWalkSpeed = math.clamp(numSpeed, 0, 500)
    
    if getCharacterParts() and not IsFlying then
        Humanoid.WalkSpeed = CurrentWalkSpeed
        print("[⚡] 地面速度已设置为：" .. CurrentWalkSpeed)
    end
end

-- 切换飞行状态
local function toggleFlying()
    if not getCharacterParts() then return end
    
    IsFlying = not IsFlying
    if IsFlying then
        -- 开启飞行
        Humanoid.PlatformStand = true
        Humanoid.WalkSpeed = 0
        print("[✈️] 飞行已开启 | WASD移动 | 空格上升 | Shift下降 | F键关闭")
    else
        -- 关闭飞行
        Humanoid.PlatformStand = false
        Humanoid.WalkSpeed = CurrentWalkSpeed
        print("[✈️] 飞行已关闭 | 恢复地面速度：" .. CurrentWalkSpeed)
    end
end

-- 飞行控制逻辑（纯基础实现）
local function handleFlying()
    if not IsFlying or not RootPart then return end
    
    local moveDir = Vector3.new()
    -- 基础方向检测
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Vector3.new(0, 0, -1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir += Vector3.new(0, 0, 1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir += Vector3.new(-1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += Vector3.new(1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir += Vector3.new(0, -1, 0) end
    
    -- 相机方向转换（极简版）
    local camera = workspace.CurrentCamera
    local lookDir = camera.CFrame.LookVector
    lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
    local rightDir = lookDir:Cross(Vector3.new(0, 1, 0))
    
    local finalDir = (lookDir * -moveDir.Z) + (rightDir * moveDir.X) + Vector3.new(0, moveDir.Y, 0)
    RootPart.Velocity = finalDir.Unit * FlySpeed
end

-- 初始化快捷键
local function initKeybinds()
    -- F键切换飞行，+/-键调速
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.F then
            toggleFlying()
        elseif input.KeyCode == Enum.KeyCode.Plus or input.KeyCode == Enum.KeyCode.Equals then
            setWalkSpeed(CurrentWalkSpeed + 10)
        elseif input.KeyCode == Enum.KeyCode.Minus then
            setWalkSpeed(CurrentWalkSpeed - 10)
        end
    end)
    
    -- 每帧处理飞行
    RunService.RenderStepped:Connect(handleFlying)
    
    -- 角色重生监听
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        IsFlying = false
        setWalkSpeed(CurrentWalkSpeed)
        print("[🔄] 角色重生，已重置速度和飞行状态")
    end)
end

-- 主初始化函数
local function main()
    -- 初始化基础速度
    if getCharacterParts() then
        Humanoid.WalkSpeed = CurrentWalkSpeed
    end
    
    -- 初始化快捷键
    initKeybinds()
    
    -- 打印启动日志
    print("====================================")
    print("✅ 脚本远程加载成功！")
    print("🔧 操作说明：")
    print("   • F键：切换飞行模式")
    print("   • +/-键：调节地面速度（每次±10）")
    print("   • 飞行控制：WASD移动 | 空格上升 | Shift下降")
    print("====================================")
end

-- 启动脚本（全局错误捕获）
local success, err = pcall(main)
if not success then
    warn("脚本启动失败：" .. err)
end
