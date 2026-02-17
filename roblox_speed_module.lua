-- ===================== 【Roblox 独立速度模块】 =====================
-- 文件名：roblox_speed_module.lua
-- 功能：纯速度调节，+/-键调速，无UI，暴露全局函数供UI调用
-- 快捷键：+键 - 加速10 | -键 - 减速10
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- 全局变量（暴露给UI/飞行模块）
getgenv().SpeedModule = {
    CurrentWalkSpeed = 16,
    -- 不再在这里预存Character和Humanoid，避免空值
}
local SM = getgenv().SpeedModule

-- 安全获取当前有效的Humanoid
local function getHumanoid()
    local player = Players.LocalPlayer
    if not player then return nil end

    local char = player.Character
    if not char then return nil end

    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid and humanoid:IsDescendantOf(game) then
        return humanoid
    end
    return nil
end

-- 应用速度到Humanoid（内部函数）
local function applySpeedToHumanoid(humanoid, speed)
    if not humanoid then return false end
    local success, err = pcall(function()
        -- 只有不在飞行时才应用速度
        local flyModule = getgenv().FlyModule
        if not (flyModule and flyModule.IsFlying) then
            humanoid.WalkSpeed = speed
        end
    end)
    return success
end

-- 设置地面速度（暴露函数）
function SM:setWalkSpeed(speed)
    local numSpeed = tonumber(speed) or 16
    self.CurrentWalkSpeed = math.clamp(numSpeed, 0, 500)

    -- 尝试应用到当前Humanoid（如果存在）
    local humanoid = getHumanoid()
    if humanoid then
        if applySpeedToHumanoid(humanoid, self.CurrentWalkSpeed) then
            print("[⚡ 速度模块] 地面速度已设置为：" .. self.CurrentWalkSpeed)
        else
            print("[⚡ 速度模块] 速度值已更新为：" .. self.CurrentWalkSpeed .. "，将在角色重生时自动应用")
        end
    else
        print("[⚡ 速度模块] 速度值已更新为：" .. self.CurrentWalkSpeed .. "，将在角色加载后自动应用")
    end
end

-- 初始化速度模块
local function init()
    -- 绑定+/-键调速
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Plus or input.KeyCode == Enum.KeyCode.Equals then
            SM:setWalkSpeed(SM.CurrentWalkSpeed + 10)
        elseif input.KeyCode == Enum.KeyCode.Minus then
            SM:setWalkSpeed(SM.CurrentWalkSpeed - 10)
        end
    end)

    -- 角色重生时自动应用速度
    Players.LocalPlayer.CharacterAdded:Connect(function(char)
        -- 等待Humanoid加载
        local humanoid = char:WaitForChild("Humanoid", 10)
        if humanoid then
            applySpeedToHumanoid(humanoid, SM.CurrentWalkSpeed)
            print("[⚡ 速度模块] 角色重生，已自动应用速度：" .. SM.CurrentWalkSpeed)
        end
    end)

    -- 首次尝试应用速度（如果角色已存在）
    local initialHumanoid = getHumanoid()
    if initialHumanoid then
        applySpeedToHumanoid(initialHumanoid, SM.CurrentWalkSpeed)
    end

    print("[✅ 速度模块] 加载成功 | +/-键调节速度（每次±10）")
end

-- 启动模块
init()
