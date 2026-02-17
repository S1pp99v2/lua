-- ===================== 【Roblox 独立飞行模块】 =====================
-- 文件名：roblox_fly_module.lua
-- 功能：纯飞行逻辑，F键开关，无UI，暴露全局函数供UI调用
-- 快捷键：F键 - 切换飞行状态
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- 全局变量（暴露给UI模块）
getgenv().FlyModule = {
    IsFlying = false,
    FlySpeed = 50,
    Character = nil,
    Humanoid = nil,
    RootPart = nil
}
local FM = getgenv().FlyModule

-- 安全获取角色部件
local function getCharacterParts()
    local success, result = pcall(function()
        FM.Character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
        FM.Humanoid = FM.Character:WaitForChild("Humanoid", 10)
        FM.RootPart = FM.Character:WaitForChild("HumanoidRootPart", 10)
        return true
    end)
    if not success then
        warn("[飞行模块] 获取角色失败：" .. result)
        return false
    end
    return true
end

-- 切换飞行状态（暴露函数）
function FM:toggleFlying()
    if not getCharacterParts() then return end
    
    self.IsFlying = not self.IsFlying
    if self.IsFlying then
        self.Humanoid.PlatformStand = true
        self.Humanoid.WalkSpeed = 0
        print("[✈️ 飞行模块] 飞行已开启 | WASD+空格+Shift控制")
    else
        self.Humanoid.PlatformStand = false
        -- 恢复地面速度（读取速度模块的当前值）
        local speedModule = getgenv().SpeedModule
        self.Humanoid.WalkSpeed = speedModule and speedModule.CurrentWalkSpeed or 16
        print("[✈️ 飞行模块] 飞行已关闭")
    end
end

-- 设置飞行速度（暴露函数）
function FM:setFlySpeed(speed)
    local numSpeed = tonumber(speed) or 50
    self.FlySpeed = math.clamp(numSpeed, 10, 200)
    print("[✈️ 飞行模块] 飞行速度已设置为：" .. self.FlySpeed)
end

-- 飞行控制逻辑
local function handleFlying()
    if not FM.IsFlying or not FM.RootPart then return end
    
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
    FM.RootPart.Velocity = finalDir.Unit * FM.FlySpeed
end

-- 初始化飞行模块
local function init()
    -- 绑定F键切换飞行
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.F then
            FM:toggleFlying()
        end
    end)
    
    -- 每帧处理飞行
    RunService.RenderStepped:Connect(handleFlying)
    
    -- 角色重生重置飞行状态
    Players.LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        FM.IsFlying = false
    end)
    
    print("[✅ 飞行模块] 加载成功 | F键切换飞行")
end

-- 启动模块
init()
