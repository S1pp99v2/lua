-- ===================== 【Roblox 独立速度模块】 =====================
-- 文件名：roblox_speed_module.lua
-- 功能：纯速度调节，+/-键调速，无UI，暴露全局函数供UI调用
-- 快捷键：+键 - 加速10 | -键 - 减速10
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- 全局变量（暴露给UI/飞行模块）
getgenv().SpeedModule = {
    CurrentWalkSpeed = 16,
    Character = nil,
    Humanoid = nil
}
local SM = getgenv().SpeedModule

-- 安全获取角色和人形对象（彻底修复版）
local function getCharacter()
    -- 先清空旧值
    SM.Character = nil
    SM.Humanoid = nil

    local success, result = pcall(function()
        -- 等待角色
        SM.Character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
        if not SM.Character then
            error("角色对象获取失败")
        end

        -- 等待Humanoid，最多等10秒
        SM.Humanoid = SM.Character:WaitForChild("Humanoid", 10)
        if not SM.Humanoid then
            error("Humanoid 未在10秒内加载完成")
        end

        return true
    end)

    if not success then
        warn("[速度模块] 获取角色失败：" .. tostring(result))
        -- 确保失败后对象为nil，避免后续误访问
        SM.Character = nil
        SM.Humanoid = nil
        return false
    end

    return true
end

-- 设置地面速度（暴露函数）
function SM:setWalkSpeed(speed)
    local numSpeed = tonumber(speed) or 16
    self.CurrentWalkSpeed = math.clamp(numSpeed, 0, 500)

    -- 先确保角色和Humanoid存在
    if not self.Humanoid then
        if not getCharacter() then
            warn("[速度模块] 无法设置速度：角色或Humanoid不存在")
            return
        end
    end

    -- 只有不在飞行时才设置速度
    local flyModule = getgenv().FlyModule
    if not (flyModule and flyModule.IsFlying) then
        self.Humanoid.WalkSpeed = self.CurrentWalkSpeed
        print("[⚡ 速度模块] 地面速度已设置为：" .. self.CurrentWalkSpeed)
    end
end

-- 初始化速度模块
local function init()
    -- 先尝试获取角色，失败则延迟重试
    if not getCharacter() then
        warn("[速度模块] 首次获取角色失败，将在1秒后重试...")
        task.wait(1)
        getCharacter() -- 第二次尝试
    end

    -- 只有成功获取到Humanoid才设置初始速度
    if SM.Humanoid then
        SM.Humanoid.WalkSpeed = SM.CurrentWalkSpeed
        print("[速度模块] 初始速度已设置为：" .. SM.CurrentWalkSpeed)
    else
        warn("[速度模块] 无法设置初始速度：Humanoid仍不存在，将在角色重生时自动设置")
    end

    -- 绑定+/-键调速
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Plus or input.KeyCode == Enum.KeyCode.Equals then
            SM:setWalkSpeed(SM.CurrentWalkSpeed + 10)
        elseif input.KeyCode == Enum.KeyCode.Minus then
            SM:setWalkSpeed(SM.CurrentWalkSpeed - 10)
        end
    end)

    -- 角色重生重置速度
    Players.LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        -- 重生后重新获取角色并设置速度
        getCharacter()
        SM:setWalkSpeed(SM.CurrentWalkSpeed)
    end)

    print("[✅ 速度模块] 加载成功 | +/-键调节速度（每次±10）")
end

-- 启动模块
init()
